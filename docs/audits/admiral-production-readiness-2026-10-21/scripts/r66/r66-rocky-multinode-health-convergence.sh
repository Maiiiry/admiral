#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Capture Release 66 Rocky worker health convergence and remove the test instance.
set -euo pipefail

[[ $# -eq 8 ]] || {
  echo "usage: $0 SSH_KEY HUB_KNOWN_HOSTS WORKER_KNOWN_HOSTS HUB_IP WORKER_IP NODE_ID INSTANCE_ID OUTPUT_DIR" >&2
  exit 2
}
ssh_key=$1 hub_known_hosts=$2 worker_known_hosts=$3 hub_ip=$4 worker_ip=$5
node_id=$6 instance_id=$7 output_dir=$8
[[ $node_id =~ ^[a-z0-9][a-z0-9-]{0,62}$ ]] || { echo 'invalid node id' >&2; exit 2; }
[[ $instance_id =~ ^inst_[A-Za-z0-9]+$ ]] || { echo 'invalid instance id' >&2; exit 2; }
[[ $output_dir = /* && ! -e $output_dir ]] || { echo 'output directory must be an unused absolute path' >&2; exit 2; }
for path in "$ssh_key" "$hub_known_hosts" "$worker_known_hosts"; do
  [[ -r $path ]] || { echo "unreadable SSH input: $path" >&2; exit 1; }
done

umask 077
mkdir -m 0700 -- "$output_dir"
ssh_args=(-i "$ssh_key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes)
hub_args=("${ssh_args[@]}" -o "UserKnownHostsFile=$hub_known_hosts")
worker_args=("${ssh_args[@]}" -o "UserKnownHostsFile=$worker_known_hosts")
hub="validator@$hub_ip" worker="validator@$worker_ip"
echo "test=R66-ROCKY-MN-HEALTH-CONVERGENCE start_utc=$(date -u +%FT%TZ) node=$node_id instance=$instance_id"

ssh "${hub_args[@]}" "$hub" \
  "sudo -u validator env HOME=/home/validator admiralctl instances show '$instance_id'" \
  >"$output_dir/initial-state.json"
ssh "${worker_args[@]}" "$worker" sudo bash -s -- "$instance_id" \
  >"$output_dir/runtime-probe.txt" <<'REMOTE'
set -euo pipefail
cd /tmp
instance_id=$1
uid=$(id -u admiral-apps)
podman_as_apps() {
  runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" podman "$@"
}
app="admiral-${instance_id}-app"
db="admiral-${instance_id}-db"
for attempt in $(seq 1 60); do
  if podman_as_apps exec "$db" sh -c \
    'export PGPASSWORD="$POSTGRES_PASSWORD"; pg_isready -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' \
    >/dev/null 2>&1; then
    printf 'database_ready_attempt=%s utc=%s\n' "$attempt" "$(date -u +%FT%TZ)"
    break
  fi
  [[ $attempt -lt 60 ]] || { echo 'database did not become ready within 5 minutes'; exit 1; }
  sleep 5
done
podman_as_apps ps --all --filter "name=$instance_id" --format '{{.Names}}|{{.Status}}|{{.Ports}}'
endpoint=$(podman_as_apps port "$app" 80/tcp | head -n1)
[[ $endpoint =~ ^([0-9.]+):([0-9]+)$ ]] || { echo "unexpected mapped endpoint: $endpoint"; exit 1; }
printf 'app_endpoint=%s\n' "$endpoint"
marker="r66-rocky-${instance_id}"
sql="CREATE TABLE IF NOT EXISTS admiral_audit_marker (value TEXT PRIMARY KEY); INSERT INTO admiral_audit_marker(value) VALUES ('$marker') ON CONFLICT DO NOTHING; SELECT value FROM admiral_audit_marker WHERE value = '$marker';"
podman_as_apps exec "$db" sh -c \
  'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "$1"' \
  sh "$sql"
REMOTE
cat "$output_dir/runtime-probe.txt"
endpoint=$(sed -n 's/^app_endpoint=//p' "$output_dir/runtime-probe.txt" | tail -n1)
[[ $endpoint =~ ^10\.99\.0\.[23]:[0-9]+$ ]] || { echo "invalid workload endpoint: $endpoint"; exit 1; }
http_code=$(ssh "${hub_args[@]}" "$hub" \
  "curl --connect-timeout 3 --max-time 10 -sS -o /dev/null -w '%{http_code}' 'http://$endpoint/'")
printf 'hub_to_workload_http_status=%s endpoint=%s\n' "$http_code" "$endpoint" | tee "$output_dir/http-probe.txt"
[[ $http_code == 200 ]] || { echo 'hub could not reach workload over WireGuard' >&2; exit 1; }

for sample in $(seq 1 7); do
  ssh "${hub_args[@]}" "$hub" \
    "sudo -u validator env HOME=/home/validator admiralctl instances show '$instance_id'" \
    >"$output_dir/state-$sample.json"
  python3 - "$output_dir/state-$sample.json" "$node_id" "$sample" <<'PY' | tee -a "$output_dir/health-samples.txt"
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print('sample={} utc={} node={} technical={} health={} availability={} reason={}'.format(
    sys.argv[3],x.get('last_health_checked_at'),x.get('node_id'),x.get('technical_status'),
    x.get('health_status'),x.get('effective_availability'),x.get('availability_reason')))
if x.get('node_id')!=sys.argv[2]:
    raise SystemExit('instance moved from the requested worker')
PY
  [[ $sample -eq 7 ]] || sleep 5
done
python3 - "$output_dir/state-6.json" "$output_dir/state-7.json" <<'PY'
import json,sys
for path in sys.argv[1:]:
    x=json.load(open(path,encoding='utf-8'))
    if (x.get('technical_status'),x.get('health_status'),x.get('effective_availability')) != ('running','healthy','available'):
        raise SystemExit(f'final health sample is not healthy and available: {path}')
PY

ssh "${hub_args[@]}" "$hub" \
  "sudo -u validator env HOME=/home/validator admiralctl instances deprovision '$instance_id' --force --wait --wait-timeout 10m --output json" \
  >"$output_dir/deprovision.json"
python3 - "$output_dir/deprovision.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print(f"deprovision_operation={x.get('id')} status={x.get('status')}")
if x.get('status')!='succeeded':
    raise SystemExit('deprovision did not succeed')
PY
ssh "${worker_args[@]}" "$worker" sudo bash -s -- "$instance_id" \
  >"$output_dir/cleanup-probe.txt" <<'REMOTE'
set -euo pipefail
cd /tmp
instance_id=$1
uid=$(id -u admiral-apps)
podman_as_apps() {
  runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" podman "$@"
}
containers=$(podman_as_apps ps -a --filter "name=$instance_id" --format '{{.Names}}')
pods=$(podman_as_apps pod ps --format '{{.Name}}' | grep -F "$instance_id" || true)
volumes=$(podman_as_apps volume ls --format '{{.Name}}' | grep -F "$instance_id" || true)
units=$(runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
  systemctl --user list-unit-files --no-legend | grep -F "$instance_id" || true)
files=$(find /etc/containers/systemd /var/lib/admiral -iname "*$instance_id*" -print 2>/dev/null || true)
printf 'remaining_containers=%s\nremaining_pods=%s\nremaining_volumes=%s\nremaining_units=%s\nremaining_files=%s\n' \
  "${containers:-none}" "${pods:-none}" "${volumes:-none}" "${units:-none}" "${files:-none}"
[[ -z $containers && -z $pods && -z $volumes && -z $units && -z $files ]]
REMOTE
cat "$output_dir/cleanup-probe.txt"
sha256sum "$output_dir"/* >"$output_dir/SHA256SUMS"
echo "health_convergence_workload_cleanup=PASS end_utc=$(date -u +%FT%TZ) evidence=$output_dir"
