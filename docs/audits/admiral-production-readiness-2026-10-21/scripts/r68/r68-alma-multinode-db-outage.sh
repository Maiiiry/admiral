#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Exercise Release 68 Fleet recovery during a disposable central PostgreSQL outage.
set -euo pipefail

[[ $# -eq 8 ]] || {
  echo "usage: $0 SSH_KEY HUB_KNOWN_HOSTS W1_KNOWN_HOSTS W2_KNOWN_HOSTS HUB_IP W1_IP W2_IP OUTPUT_DIR" >&2
  exit 2
}
ssh_key=$1 hub_known_hosts=$2 w1_known_hosts=$3 w2_known_hosts=$4
hub_ip=$5 w1_ip=$6 w2_ip=$7 output_dir=$8
node_id=adm-r68-alma-mn-w1
worker_ip=$w1_ip
[[ $output_dir == /* ]] || { echo 'output directory must be absolute' >&2; exit 2; }
for path in "$ssh_key" "$hub_known_hosts" "$w1_known_hosts" "$w2_known_hosts"; do
  [[ -r $path ]] || { echo "unreadable SSH input: $path" >&2; exit 1; }
done

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../../../../.." && pwd)
fixture="$repo_root/examples/apps/e2e-whoami.yaml"
[[ -r $fixture ]] || { echo "fixture not found: $fixture" >&2; exit 1; }
umask 077
[[ ! -e $output_dir ]] || { echo "evidence directory already exists: $output_dir" >&2; exit 1; }
install -d -m 0700 "$output_dir"
ssh_args=(-i "$ssh_key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes)
hub_args=("${ssh_args[@]}" -o "UserKnownHostsFile=$hub_known_hosts")
w1_args=("${ssh_args[@]}" -o "UserKnownHostsFile=$w1_known_hosts")
w2_args=("${ssh_args[@]}" -o "UserKnownHostsFile=$w2_known_hosts")
hub="validator@$hub_ip"
worker1="validator@$w1_ip"
worker2="validator@$w2_ip"
worker=$worker1
suffix=$(date -u +%Y%m%dT%H%M%SZ)
customer="r68-alma-db-outage-$suffix"
idempotency_key="r68-alma-db-outage-$suffix"
instance_id=
restore_armed=false
restore_method=not-needed
fixture_uploaded=false
test_id=R68-ALMA-MN-DB-OUTAGE-01
candidate_commit=4077c4ddb9d233682961d36c3570c63e70eb6405

cat >"$output_dir/metadata.txt" <<EOF
test_id=$test_id
candidate=0.0.1rc5-68.el10
candidate_root_source_commit=$candidate_commit
node_id=$node_id
hub_ip=$hub_ip
w1_ip=$w1_ip
w2_ip=$w2_ip
start_utc=$(date -u +%FT%TZ)
EOF

cleanup() {
  local rc=$?
  local restore_result=$restore_method
  local deprovision_result=not-needed
  local fixture_result=not-needed
  trap - EXIT
  set +e
  if [[ $restore_armed == true ]]; then
    if ssh "${hub_args[@]}" "$hub" \
      'sudo systemctl start postgresql && sudo systemctl is-active --quiet postgresql; result=$?; sudo systemctl stop admiral-r68-alma-pg-restore.timer >/dev/null 2>&1 || true; exit "$result"' \
      >"$output_dir/final-postgres-restore.log" 2>&1; then
      restore_result=restored
      restore_method=manual-restored
      restore_armed=false
    else
      restore_result=FAILED
      rc=1
    fi
  fi
  if [[ $restore_armed == false ]]; then
    ssh "${hub_args[@]}" "$hub" \
      'sudo systemctl stop admiral-r68-alma-pg-restore.timer >/dev/null 2>&1 || true' \
      >>"$output_dir/final-postgres-restore.log" 2>&1
  fi
  if [[ -n $instance_id ]]; then
    if ssh "${hub_args[@]}" "$hub" \
      "sudo -u validator env HOME=/home/validator admiralctl instances deprovision '$instance_id' --force --wait --wait-timeout 10m --output json" \
      >"$output_dir/final-deprovision-on-exit.json" 2>&1; then
      deprovision_result=attempted
    else
      deprovision_result=FAILED
      rc=1
    fi
  fi
  if [[ $fixture_uploaded == true ]]; then
    if ssh "${hub_args[@]}" "$hub" 'sudo rm -f /tmp/r68-e2e-whoami-db-outage.yaml' \
      >"$output_dir/final-fixture-cleanup.log" 2>&1; then
      fixture_result=removed
    else
      fixture_result=FAILED
      rc=1
    fi
  fi
  printf 'result=%s\nexit_code=%s\npostgres_cleanup=%s\ndeprovision_cleanup=%s\nfixture_cleanup=%s\nend_utc=%s\n' \
    "$([[ $rc -eq 0 ]] && echo PASS || echo FAIL)" "$rc" "$restore_result" "$deprovision_result" "$fixture_result" "$(date -u +%FT%TZ)" \
    >"$output_dir/exit-status.txt"
  find "$output_dir" -maxdepth 1 -type f -exec chmod 0600 {} +
  (cd "$output_dir" && find . -maxdepth 1 -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 -r sha256sum >SHA256SUMS)
  chmod 0600 "$output_dir/SHA256SUMS"
  echo "result=$([[ $rc -eq 0 ]] && echo PASS || echo FAIL) evidence=$output_dir exit_code=$rc"
  exit "$rc"
}
trap cleanup EXIT

record_error() {
  local rc=$?
  trap - ERR
  printf 'exit_code=%s\nline=%s\ncommand=%s\n' "$rc" "${BASH_LINENO[0]:-unknown}" "$BASH_COMMAND" >"$output_dir/failure.txt"
  return "$rc"
}
trap record_error ERR

capture_host() {
  local label=$1 target=$2 args_name=$3
  local -n remote_args=$args_name
  ssh "${remote_args[@]}" "$target" sudo bash -s <<'REMOTE' >"$output_dir/host-$label.txt"
set -euo pipefail
cat /etc/os-release
printf '\narchitecture=%s\nkernel=%s\nselinux=' "$(uname -m)" "$(uname -r)"
getenforce
REMOTE
}

capture_packages() {
  local label=$1 target=$2 args_name=$3 role=$4
  local -n remote_args=$args_name
  local packages=(admiral-common admiral-fleet)
  if [[ $role == hub ]]; then
    packages=(admiral-common admirald admiral-fleet admiralctl admiral-flagship admiral-harbor)
  fi
  ssh "${remote_args[@]}" "$target" sudo bash -s -- "${packages[@]}" \
    >"$output_dir/packages-$label.txt" <<'REMOTE'
set -euo pipefail
format='%{NAME} %{VERSION}-%{RELEASE}.%{ARCH}\n'
rpm -q --qf "$format" "$@"
REMOTE
  python3 - "$output_dir/packages-$label.txt" "$role" <<'PY'
import pathlib,sys
rows=[line.split() for line in pathlib.Path(sys.argv[1]).read_text().splitlines()]
expected={'admiral-common','admiral-fleet'}
if sys.argv[2]=='hub': expected |= {'admirald','admiralctl','admiral-flagship','admiral-harbor'}
if {row[0] for row in rows} != expected or any(len(row)!=2 or not row[1].startswith('0.0.1rc5-68.el10.') for row in rows):
    raise SystemExit(f'installed RPM set does not match the exact R68 EL10 role: {rows!r}')
PY
}

capture_host hub "$hub" hub_args
capture_host worker1 "$worker1" w1_args
capture_host worker2 "$worker2" w2_args
capture_packages hub "$hub" hub_args hub
capture_packages worker1 "$worker1" w1_args worker
capture_packages worker2 "$worker2" w2_args worker
for path in "$output_dir/host-hub.txt" "$output_dir/host-worker1.txt" "$output_dir/host-worker2.txt"; do
  grep -Eq '^ID="?almalinux"?$' "$path" || { echo "unexpected OS in $path" >&2; exit 1; }
  grep -q '^VERSION_ID="10' "$path" || { echo "unexpected EL major version in $path" >&2; exit 1; }
  grep -q '^architecture=x86_64$' "$path" || { echo "unexpected architecture in $path" >&2; exit 1; }
  grep -q '^selinux=Enforcing$' "$path" || { echo "SELinux is not enforcing in $path" >&2; exit 1; }
done
ssh "${hub_args[@]}" "$hub" sudo bash -s >"$output_dir/service-preflight.txt" <<'REMOTE'
set -euo pipefail
systemctl is-active admirald postgresql
REMOTE
ssh "${w1_args[@]}" "$worker1" sudo bash -s >>"$output_dir/service-preflight.txt" <<'REMOTE'
set -euo pipefail
systemctl is-active admiral-fleet
REMOTE
ssh "${w2_args[@]}" "$worker2" sudo bash -s >>"$output_dir/service-preflight.txt" <<'REMOTE'
set -euo pipefail
systemctl is-active admiral-fleet
REMOTE
ssh "${hub_args[@]}" "$hub" \
  'sudo -u validator env HOME=/home/validator admiralctl nodes list --output json' >"$output_dir/nodes-before.json"
python3 - "$output_dir/nodes-before.json" "$node_id" <<'PY' >"$output_dir/nodes-before-summary.txt"
import json,pathlib,sys
value=json.loads(pathlib.Path(sys.argv[1]).read_text())
nodes=value.get('nodes',[]) if isinstance(value,dict) else value
for node in nodes:
    print(f"node={node.get('id')} status={node.get('status')} health={node.get('health_status')} available={node.get('available_for_provisioning')}")
required={'adm-r68-alma-mn-w1','adm-r68-alma-mn-w2'}
if not required.issubset({n.get('id') for n in nodes}): raise SystemExit('both R68 Alma workers must be registered')
for node in nodes:
    if node.get('id') in required and (node.get('status')!='active' or node.get('health_status')!='healthy' or node.get('available_for_provisioning') is not True):
        raise SystemExit(f"worker is not active/healthy/available: {node.get('id')}")
if sys.argv[2] not in required: raise SystemExit('selected node is not an expected worker')
PY

scp "${hub_args[@]}" "$fixture" "$hub:/tmp/r68-e2e-whoami-db-outage.yaml"
fixture_uploaded=true
ssh "${hub_args[@]}" "$hub" \
  'sudo -u validator env HOME=/home/validator admiralctl apps apply --file /tmp/r68-e2e-whoami-db-outage.yaml' \
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
[[ $node_id == adm-r68-alma-mn-w2 ]] && expected_wg_ip=10.99.0.3
ssh "${w1_args[@]}" "$worker" sudo bash -s -- "$instance_id" "$expected_wg_ip" >"$output_dir/workload-before-outage.txt" <<'REMOTE'
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
marker="r68-alma-central-db-${instance_id}"
sql="CREATE TABLE IF NOT EXISTS admiral_audit_marker (value TEXT PRIMARY KEY); INSERT INTO admiral_audit_marker(value) VALUES ('$marker') ON CONFLICT DO NOTHING; SELECT value FROM admiral_audit_marker WHERE value = '$marker';"
run_as_apps exec "$db" sh -c 'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "$1"' sh "$sql"
printf 'sql_marker=%s\n' "$marker"
REMOTE
endpoint=$(sed -n 's/^app_endpoint=//p' "$output_dir/workload-before-outage.txt" | tail -n1)
[[ $endpoint =~ ^10\.99\.0\.[23]:[0-9]+$ ]] || { echo 'invalid WireGuard endpoint'; exit 1; }
ssh "${hub_args[@]}" "$hub" "curl --connect-timeout 3 --max-time 10 -fsS -o /dev/null -w '%{http_code}' 'http://$endpoint/'" >"$output_dir/http-before.txt"
[[ $(cat "$output_dir/http-before.txt") == 200 ]]

# Arm restoration before requesting the stop so the EXIT trap repairs the lab
# even if the SSH connection drops while the service is being stopped.
start_utc=$(date -u +%FT%TZ)
restore_armed=true
restore_method=timer-pending
ssh "${hub_args[@]}" "$hub" sudo bash -s -- <<'REMOTE' >"$output_dir/postgres-outage-setup.log" 2>&1
set -euo pipefail
systemctl is-active --quiet postgresql
systemd-run --unit=admiral-r68-alma-pg-restore --on-active=60s /usr/bin/systemctl start postgresql
systemctl stop postgresql
systemctl is-active postgresql || true
REMOTE
printf 'instance_id=%s\noutage_start_utc=%s\n' "$instance_id" "$start_utc" >>"$output_dir/metadata.txt"

for attempt in $(seq 1 18); do
  state=$(ssh "${hub_args[@]}" "$hub" 'sudo systemctl is-active postgresql || true')
  http=$(ssh "${hub_args[@]}" "$hub" \
    "curl --connect-timeout 3 --max-time 10 -sS -o /dev/null -w '%{http_code}' 'http://$endpoint/' || true")
  printf 'poll=%s utc=%s postgresql=%s app_http=%s\n' "$attempt" "$(date -u +%FT%TZ)" "$state" "$http" >>"$output_dir/outage-polls.txt"
  if [[ $state == active ]]; then
    break
  fi
  sleep 5
done
[[ ${state:-inactive} == active ]] || { echo 'PostgreSQL recovery timer did not restore the service'; exit 1; }
ssh "${hub_args[@]}" "$hub" sudo bash -s >"$output_dir/postgres-timer-recovery.txt" <<'REMOTE'
set -euo pipefail
systemctl is-active --quiet postgresql
systemctl show admiral-r68-alma-pg-restore.service -p Result -p ExecMainStatus -p ActiveState --no-pager
systemctl list-timers admiral-r68-alma-pg-restore.timer --all --no-pager
REMOTE
grep -Fx 'Result=success' "$output_dir/postgres-timer-recovery.txt" >/dev/null
grep -Fx 'ExecMainStatus=0' "$output_dir/postgres-timer-recovery.txt" >/dev/null
grep -Fx 'ActiveState=inactive' "$output_dir/postgres-timer-recovery.txt" >/dev/null
restore_armed=false
restore_method=timer-restored
if grep -v 'app_http=200$' "$output_dir/outage-polls.txt" >/dev/null; then
  echo 'workload HTTP was not continuously available during the sampled outage' >&2
  exit 1
fi

ssh "${hub_args[@]}" "$hub" \
  "sudo journalctl -u admirald --since '$start_utc' --no-pager" >"$output_dir/admirald-outage-journal.log"
ssh "${w1_args[@]}" "$worker1" \
  "sudo journalctl -u admiral-fleet --since '$start_utc' --no-pager" >"$output_dir/fleet-w1-outage-journal.log"
ssh "${w2_args[@]}" "$worker2" \
  "sudo journalctl -u admiral-fleet --since '$start_utc' --no-pager" >"$output_dir/fleet-w2-outage-journal.log"
http_503=$(grep -Ec '"status":503' "$output_dir/admirald-outage-journal.log" || true)
http_401_429=$(grep -Ec '"status":(401|429)' "$output_dir/admirald-outage-journal.log" || true)
printf 'fleet_http_503_log_records=%s\nfleet_http_401_or_429_log_records=%s\n' "$http_503" "$http_401_429" >>"$output_dir/metadata.txt"
[[ $http_503 -gt 0 && $http_401_429 -eq 0 ]] || { echo 'expected 503 retryable auth failures and no 401/429'; exit 1; }
for worker_name in w1 w2; do
  worker_log="$output_dir/fleet-$worker_name-outage-journal.log"
  worker_503=$(grep -Ec 'HTTP 503' "$worker_log" || true)
  worker_401_429=$(grep -Ec 'HTTP (401|429)' "$worker_log" || true)
  printf '%s_http_503_records=%s\n%s_http_401_or_429_records=%s\n' "$worker_name" "$worker_503" "$worker_name" "$worker_401_429" >>"$output_dir/metadata.txt"
  [[ $worker_503 -gt 0 && $worker_401_429 -eq 0 ]] || {
    echo "expected worker $worker_name to log retryable HTTP 503 and no HTTP 401/429" >&2
    exit 1
  }
done

ssh "${hub_args[@]}" "$hub" \
  'sudo -u validator env HOME=/home/validator admiralctl nodes list --output json' >"$output_dir/nodes-after-recovery.json"
python3 - "$output_dir/nodes-after-recovery.json" <<'PY' >"$output_dir/nodes-after-recovery-summary.txt"
import json,sys
nodes=json.load(open(sys.argv[1],encoding='utf-8'))
if isinstance(nodes,dict): nodes=nodes.get('nodes',[])
for node in nodes:
    print(f"node={node.get('id')} status={node.get('status')} health={node.get('health_status')} available={node.get('available_for_provisioning')}")
required={'adm-r68-alma-mn-w1','adm-r68-alma-mn-w2'}
for node_id in required:
    worker=next((n for n in nodes if n.get('id')==node_id),None)
    if not worker or worker.get('status')!='active' or worker.get('health_status')!='healthy' or worker.get('available_for_provisioning') is not True:
        raise SystemExit(f'worker {node_id} did not recover to active/healthy/available')
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
ssh "${w1_args[@]}" "$worker" sudo bash -s -- "$instance_id" >"$output_dir/workload-after-recovery.txt" <<'REMOTE'
set -euo pipefail
cd /tmp
instance_id=$1
uid=$(id -u admiral-apps)
run_as_apps() { runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" podman "$@"; }
db="admiral-${instance_id}-db"
app="admiral-${instance_id}-app"
marker="r68-alma-central-db-${instance_id}"
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
grep -Fx "r68-alma-central-db-$instance_id" "$output_dir/workload-after-recovery.txt" >/dev/null || {
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
ssh "${w1_args[@]}" "$worker" sudo bash -s -- "$instance_id" >"$output_dir/final-inventory.txt" <<'REMOTE'
set -euo pipefail
cd /tmp
instance_id=$1
uid=$(id -u admiral-apps)
run_as_apps() { runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" podman "$@"; }
containers=$(run_as_apps ps -a --filter "name=$instance_id" --format '{{.Names}}')
pods=$(run_as_apps pod ps --format '{{.Name}}' | grep -F "$instance_id" || true)
volumes=$(run_as_apps volume ls --format '{{.Name}}' | grep -F "$instance_id" || true)
files=$(find /etc/containers/systemd /var/lib/admiral /home/admiral-apps/.config/containers/systemd /home/admiral-apps/.config/systemd/user -xdev -iname "*$instance_id*" -print 2>/dev/null || true)
printf 'containers=%s\npods=%s\nvolumes=%s\nfiles=%s\n' "${containers:-none}" "${pods:-none}" "${volumes:-none}" "${files:-none}"
[[ -z $containers && -z $pods && -z $volumes && -z $files ]]
REMOTE
instance_id=
