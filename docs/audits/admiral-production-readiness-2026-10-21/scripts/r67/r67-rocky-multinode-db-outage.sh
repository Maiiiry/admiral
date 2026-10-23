#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Exercise Release 67 Fleet recovery during a disposable central PostgreSQL outage.
set -euo pipefail

[[ $# -eq 7 ]] || {
  echo "usage: $0 SSH_KEY HUB_KNOWN_HOSTS WORKER_KNOWN_HOSTS HUB_IP WORKER_IP NODE_ID OUTPUT_DIR" >&2
  exit 2
}
ssh_key=$1 hub_known_hosts=$2 worker_known_hosts=$3
hub_ip=$4 worker_ip=$5 node_id=$6 output_dir=$7
[[ $node_id =~ ^adm-r67-rocky-mn-w[12]$ ]] || { echo 'invalid node id' >&2; exit 2; }
[[ $output_dir == /* ]] || { echo 'output directory must be absolute' >&2; exit 2; }
for path in "$ssh_key" "$hub_known_hosts" "$worker_known_hosts"; do
  [[ -r $path ]] || { echo "unreadable SSH input: $path" >&2; exit 1; }
done

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../../../../.." && pwd)
fixture="$repo_root/examples/apps/e2e-whoami.yaml"
[[ -r $fixture ]] || { echo "fixture not found: $fixture" >&2; exit 1; }
install -d -m 0700 "$output_dir"
umask 077
ssh_args=(-i "$ssh_key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes)
hub_args=("${ssh_args[@]}" -o "UserKnownHostsFile=$hub_known_hosts")
worker_args=("${ssh_args[@]}" -o "UserKnownHostsFile=$worker_known_hosts")
hub="validator@$hub_ip"
worker="validator@$worker_ip"
suffix=$(date -u +%Y%m%d%H%M%S)
customer="r67-rocky-db-outage-$suffix"
idempotency_key="r67-rocky-db-outage-$suffix"
instance_id=
restore_armed=false

cleanup() {
  local rc=$?
  trap - EXIT
  if [[ $restore_armed == true ]]; then
    ssh "${hub_args[@]}" "$hub" 'sudo systemctl start postgresql' >/dev/null 2>&1 || true
  fi
  if [[ -n $instance_id ]]; then
    ssh "${hub_args[@]}" "$hub" \
      "sudo -u validator env HOME=/home/validator admiralctl instances deprovision '$instance_id' --force --wait --wait-timeout 10m --output json" \
      >"$output_dir/final-deprovision-on-exit.json" 2>&1 || true
  fi
  exit "$rc"
}
trap cleanup EXIT

scp "${hub_args[@]}" "$fixture" "$hub:/tmp/r67-e2e-whoami-db-outage.yaml"
ssh "${hub_args[@]}" "$hub" \
  'sudo -u validator env HOME=/home/validator admiralctl apps apply --file /tmp/r67-e2e-whoami-db-outage.yaml' \
  >"$output_dir/app-apply.log" 2>&1
ssh "${hub_args[@]}" "$hub" \
  "sudo -u validator env HOME=/home/validator admiralctl instances provision --app e2e-whoami --tier small --customer '$customer' --idempotency-key '$idempotency_key' --node '$node_id' --wait --wait-timeout 10m --quiet --output json" \
  >"$output_dir/provision.json"
instance_id=$(python3 - "$output_dir/provision.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
if x.get('status')!='succeeded' or not x.get('instance_id'):
    raise SystemExit('provision did not succeed')
print(x['instance_id'])
PY
)

expected_wg_ip=10.99.0.2
[[ $node_id == adm-r67-rocky-mn-w2 ]] && expected_wg_ip=10.99.0.3
ssh "${worker_args[@]}" "$worker" sudo bash -s -- "$instance_id" "$expected_wg_ip" >"$output_dir/workload-before-outage.txt" <<'REMOTE'
set -euo pipefail
cd /tmp
instance_id=$1 expected_ip=$2
uid=$(id -u admiral-apps)
run_as_apps() { runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" podman "$@"; }
db="admiral-${instance_id}-db"
app="admiral-${instance_id}-app"
ready=0
for attempt in $(seq 1 60); do
  if run_as_apps exec "$db" sh -c 'export PGPASSWORD="$POSTGRES_PASSWORD"; pg_isready -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' >/dev/null 2>&1; then
    ready=1; break
  fi
  sleep 5
done
[[ $ready -eq 1 ]] || { echo 'workload DB did not become ready'; exit 1; }
endpoint=$(run_as_apps port "$app" 80/tcp | head -n1)
[[ $endpoint =~ ^([0-9.]+):([0-9]+)$ && ${BASH_REMATCH[1]} == "$expected_ip" ]] || { echo "unexpected app endpoint: $endpoint"; exit 1; }
printf 'app_endpoint=%s\n' "$endpoint"
marker="r67-rocky-central-db-${instance_id}"
sql="CREATE TABLE IF NOT EXISTS admiral_audit_marker (value TEXT PRIMARY KEY); INSERT INTO admiral_audit_marker(value) VALUES ('$marker') ON CONFLICT DO NOTHING; SELECT value FROM admiral_audit_marker WHERE value = '$marker';"
run_as_apps exec "$db" sh -c 'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "$1"' sh "$sql"
printf 'sql_marker=%s\n' "$marker"
REMOTE
endpoint=$(sed -n 's/^app_endpoint=//p' "$output_dir/workload-before-outage.txt" | tail -n1)
[[ $endpoint =~ ^10\.99\.0\.[23]:[0-9]+$ ]] || { echo 'invalid WireGuard endpoint'; exit 1; }
ssh "${hub_args[@]}" "$hub" "curl --connect-timeout 3 --max-time 10 -fsS -o /dev/null -w '%{http_code}' 'http://$endpoint/'" >"$output_dir/http-before.txt"
[[ $(cat "$output_dir/http-before.txt") == 200 ]]

start_utc=$(date -u +%FT%TZ)
restore_armed=true
ssh "${hub_args[@]}" "$hub" sudo bash -s -- <<'REMOTE' >"$output_dir/postgres-outage-setup.log" 2>&1
set -euo pipefail
systemctl is-active --quiet postgresql
systemd-run --unit=admiral-r67-rocky-pg-restore --on-active=60s /usr/bin/systemctl start postgresql
systemctl stop postgresql
systemctl is-active postgresql || true
REMOTE
printf 'candidate=0.0.1rc5-67.el10\nnode_id=%s\ninstance_id=%s\nstart_utc=%s\n' "$node_id" "$instance_id" "$start_utc" >"$output_dir/metadata.txt"

for attempt in $(seq 1 18); do
  state=$(ssh "${hub_args[@]}" "$hub" 'sudo systemctl is-active postgresql || true')
  http=$(ssh "${hub_args[@]}" "$hub" \
    "curl --connect-timeout 3 --max-time 10 -sS -o /dev/null -w '%{http_code}' 'http://$endpoint/' || true")
  printf 'poll=%s utc=%s postgresql=%s app_http=%s\n' "$attempt" "$(date -u +%FT%TZ)" "$state" "$http" >>"$output_dir/outage-polls.txt"
  if [[ $state == active ]]; then
    restore_armed=false
    break
  fi
  sleep 5
done
[[ ${state:-inactive} == active ]] || { echo 'PostgreSQL recovery timer did not restore the service'; exit 1; }
if grep -v 'app_http=200$' "$output_dir/outage-polls.txt" >/dev/null; then
  echo 'workload HTTP was not continuously available during the sampled outage' >&2
  exit 1
fi

ssh "${hub_args[@]}" "$hub" \
  "sudo journalctl -u admirald --since '$start_utc' --no-pager" >"$output_dir/admirald-outage-journal.log"
http_503=$(grep -Ec '"status":503' "$output_dir/admirald-outage-journal.log" || true)
http_401_429=$(grep -Ec '"status":(401|429)' "$output_dir/admirald-outage-journal.log" || true)
printf 'fleet_http_503_log_records=%s\nfleet_http_401_or_429_log_records=%s\n' "$http_503" "$http_401_429" >>"$output_dir/metadata.txt"
[[ $http_503 -gt 0 && $http_401_429 -eq 0 ]] || { echo 'expected 503 retryable auth failures and no 401/429'; exit 1; }

ssh "${hub_args[@]}" "$hub" \
  'sudo -u validator env HOME=/home/validator admiralctl nodes list --output json' >"$output_dir/nodes-after-recovery.json"
python3 - "$output_dir/nodes-after-recovery.json" "$node_id" <<'PY' >"$output_dir/nodes-after-recovery-summary.txt"
import json,sys
nodes=json.load(open(sys.argv[1],encoding='utf-8'))
if isinstance(nodes,dict): nodes=nodes.get('nodes',[])
for node in nodes:
    print(f"node={node.get('id')} status={node.get('status')} health={node.get('health_status')} available={node.get('available_for_provisioning')}")
worker=next((n for n in nodes if n.get('id')==sys.argv[2]),None)
if not worker or worker.get('status')!='active' or worker.get('health_status')!='healthy' or worker.get('available_for_provisioning') is not True:
    raise SystemExit('worker did not recover to active/healthy/available')
PY
ssh "${hub_args[@]}" "$hub" \
  "sudo -u validator env HOME=/home/validator admiralctl instances show '$instance_id'" >"$output_dir/instance-after-recovery.json"
python3 - "$output_dir/instance-after-recovery.json" "$node_id" <<'PY' >"$output_dir/instance-after-recovery-summary.txt"
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print(f"instance={x.get('id')} node={x.get('node_id')} technical={x.get('technical_status')} health={x.get('health_status')} availability={x.get('effective_availability')}")
if x.get('node_id')!=sys.argv[2] or x.get('technical_status')!='running' or x.get('effective_availability')!='available':
    raise SystemExit('instance did not recover to running/available')
PY
ssh "${worker_args[@]}" "$worker" sudo bash -s -- "$instance_id" >"$output_dir/workload-after-recovery.txt" <<'REMOTE'
set -euo pipefail
cd /tmp
instance_id=$1
uid=$(id -u admiral-apps)
run_as_apps() { runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" podman "$@"; }
db="admiral-${instance_id}-db"
app="admiral-${instance_id}-app"
marker="r67-rocky-central-db-${instance_id}"
query="SELECT value FROM admiral_audit_marker WHERE value = '$marker';"
for attempt in $(seq 1 30); do
  if run_as_apps exec "$db" sh -c 'export PGPASSWORD="$POSTGRES_PASSWORD"; pg_isready -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' >/dev/null 2>&1; then
    break
  fi
  [[ $attempt -lt 30 ]] || { echo 'workload DB did not recover'; exit 1; }
  sleep 2
done
run_as_apps exec "$db" sh -c 'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "$1"' sh "$query"
endpoint=$(run_as_apps port "$app" 80/tcp | head -n1)
printf 'app_endpoint=%s\n' "$endpoint"
REMOTE
grep -Fx "r67-rocky-central-db-$instance_id" "$output_dir/workload-after-recovery.txt" >/dev/null || {
  echo 'SQL marker did not survive the central database outage' >&2
  exit 1
}
endpoint_after=$(sed -n 's/^app_endpoint=//p' "$output_dir/workload-after-recovery.txt" | tail -n1)
http_after=$(ssh "${hub_args[@]}" "$hub" \
  "curl --connect-timeout 3 --max-time 10 -sS -o /dev/null -w '%{http_code}' 'http://$endpoint_after/'")
printf 'post_recovery_http=%s\n' "$http_after" >>"$output_dir/metadata.txt"
[[ $http_after == 200 ]]

ssh "${hub_args[@]}" "$hub" \
  "sudo -u validator env HOME=/home/validator admiralctl instances deprovision '$instance_id' --force --wait --wait-timeout 10m --output json" >"$output_dir/deprovision.json"
python3 - "$output_dir/deprovision.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print(f"deprovision_operation={x.get('id')} status={x.get('status')}")
if x.get('status')!='succeeded': raise SystemExit('deprovision failed')
PY
ssh "${worker_args[@]}" "$worker" sudo bash -s -- "$instance_id" >"$output_dir/final-inventory.txt" <<'REMOTE'
set -euo pipefail
cd /tmp
instance_id=$1
uid=$(id -u admiral-apps)
run_as_apps() { runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" podman "$@"; }
containers=$(run_as_apps ps -a --filter "name=$instance_id" --format '{{.Names}}')
pods=$(run_as_apps pod ps --format '{{.Name}}' | grep -F "$instance_id" || true)
volumes=$(run_as_apps volume ls --format '{{.Name}}' | grep -F "$instance_id" || true)
files=$(find /etc/containers/systemd /var/lib/admiral -xdev -iname "*$instance_id*" -print 2>/dev/null || true)
printf 'containers=%s\npods=%s\nvolumes=%s\nfiles=%s\n' "${containers:-none}" "${pods:-none}" "${volumes:-none}" "${files:-none}"
[[ -z $containers && -z $pods && -z $volumes && -z $files ]]
REMOTE
instance_id=
find "$output_dir" -maxdepth 1 -type f -exec chmod 0600 {} +
(cd "$output_dir" && find . -maxdepth 1 -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
chmod 0600 "$output_dir/SHA256SUMS"
echo "result=PASS evidence=$output_dir"
