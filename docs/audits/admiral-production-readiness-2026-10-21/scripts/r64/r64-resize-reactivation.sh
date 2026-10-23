#!/usr/bin/env bash
set -euo pipefail
cd /
os=$1
customer=$2
key=$3
run_dir="/var/tmp/adm-r64-${os}-resize"
install -d -m 0700 "$run_dir"
cp /tmp/audit-e2e-resize.yaml "$run_dir/e2e-resize.yaml"
admiralctl apps apply --file "$run_dir/e2e-resize.yaml" > "$run_dir/apply.log" 2>&1
admiralctl instances provision --app e2e-resize-audit --tier small --customer "$customer" --idempotency-key "$key" --wait --wait-timeout 10m --quiet --output json > "$run_dir/provision.json"
instance_id=$(python3 - "$run_dir/provision.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
if x.get('status')!='succeeded': raise SystemExit('provision failed')
print(x['instance_id'])
PY
)
uid=$(id -u admiral-apps)
db="admiral-${instance_id}-db"
app="admiral-${instance_id}-app"
cd /
wait_for_state() {
  local expected_tier=$1
  local attempt fields tech health avail tier
  for attempt in $(seq 1 36); do
    admiralctl instances show "$instance_id" > "$run_dir/instance-${expected_tier}-poll.json"
    fields=$(python3 - "$run_dir/instance-${expected_tier}-poll.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print(x.get('technical_status',''),x.get('health_status',''),x.get('effective_availability',''),x.get('tier_name',''))
PY
)
    read -r tech health avail tier <<< "$fields"
    printf 'state_poll_tier=%s attempt=%s utc=%s state=%s\n' "$expected_tier" "$attempt" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$fields"
    if [[ $tech == running && $health == healthy && $avail == available && $tier == "$expected_tier" ]]; then return 0; fi
    [[ $attempt -lt 36 ]] || { echo "instance failed to converge to tier $expected_tier within 180s"; return 1; }
    sleep 5
  done
}
wait_for_technical_status() {
  local expected=$1 attempt actual
  for attempt in $(seq 1 36); do
    admiralctl instances show "$instance_id" > "$run_dir/instance-${expected}-poll.json"
    actual=$(python3 - "$run_dir/instance-${expected}-poll.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print(x.get('technical_status',''))
PY
)
    printf 'state_poll_status=%s attempt=%s utc=%s observed=%s\n' "$expected" "$attempt" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$actual"
    [[ $actual == "$expected" ]] && return 0
    [[ $attempt -lt 36 ]] || { echo "instance failed to reach technical status $expected within 180s"; return 1; }
    sleep 5
  done
}
limit_for_pid() {
  local pid=$1 expected=$2 cg current found=0 memory cpu
  cg=$(awk -F: '$1=="0" {print $3}' "/proc/$pid/cgroup")
  current=$cg
  while [[ -n $current ]]; do
    if [[ -r /sys/fs/cgroup${current}/memory.max && -r /sys/fs/cgroup${current}/cpu.max ]]; then
      memory=$(cat "/sys/fs/cgroup${current}/memory.max")
      cpu=$(cat "/sys/fs/cgroup${current}/cpu.max")
      printf 'pid=%s cgroup=%s memory.max=%s cpu.max=%s\n' "$pid" "$current" "$memory" "$cpu"
      if [[ $memory == "$expected" && $cpu == '100000 100000' ]]; then found=1; fi
    fi
    [[ $current != / ]] || break
    current=$(dirname "$current")
    [[ $current != . ]] || break
  done
  [[ $found -eq 1 ]] || { echo "expected memory=$expected and cpu=1 at cgroup ancestor"; return 1; }
}
verify_state() {
  local tier=$1 memory=$2 app_pid mapping port http
  wait_for_state "$tier"
  printf 'instance_id=%s tier=%s\n' "$instance_id" "$tier"
  app_pid=$(runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman inspect --format '{{.State.Pid}}' "$app")
  limit_for_pid "$app_pid" "$memory"
  mapping=$(runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman port "$app" 80/tcp | head -n1)
  port=${mapping##*:}
  http=$(curl --silent --show-error --max-time 5 --output "$run_dir/http-${tier}.txt" --write-out '%{http_code}' "http://127.0.0.1:${port}/" || true)
  printf 'tier=%s app_port=%s http=%s\n' "$tier" "$mapping" "$http"
  [[ $http == 200 ]] || return 1
}
query_marker() {
  local phase=$1
  local sql="$run_dir/query-${phase}.sql"
  printf 'SELECT value FROM admiral_resize_marker;\n' > "$sql"
  runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman exec -i "$db" sh -c 'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -v ON_ERROR_STOP=1' < "$sql" > "$run_dir/marker-${phase}.txt"
  cat "$run_dir/marker-${phase}.txt"
  [[ $(tr -d '\r\n' < "$run_dir/marker-${phase}.txt") == persisted ]] || { echo "database marker changed or database credentials are unusable after $phase"; return 1; }
}
printf 'instance_id=%s initial_tier=small\n' "$instance_id"
wait_for_state small
marker_sql="$run_dir/marker.sql"
printf "CREATE TABLE IF NOT EXISTS admiral_resize_marker (value TEXT PRIMARY KEY); TRUNCATE admiral_resize_marker; INSERT INTO admiral_resize_marker(value) VALUES ('persisted'); SELECT value FROM admiral_resize_marker;\n" > "$marker_sql"
runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman exec -i "$db" sh -c 'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1' < "$marker_sql" > "$run_dir/marker-before-resize.txt"
cat "$run_dir/marker-before-resize.txt"
verify_state small 536870912
printf 'y\n' | admiralctl instances resize --tier medium "$instance_id" --wait --wait-timeout 10m --output json > "$run_dir/resize-medium.json"
cat "$run_dir/resize-medium.json"
verify_state medium 805306368
printf 'y\n' | admiralctl instances resize --tier small "$instance_id" --wait --wait-timeout 10m --output json > "$run_dir/resize-small.json"
cat "$run_dir/resize-small.json"
verify_state small 536870912
query_marker after-resize
printf 'y\n' | admiralctl instances pause "$instance_id" --force --wait --wait-timeout 10m --output json > "$run_dir/pause.json"
cat "$run_dir/pause.json"
wait_for_technical_status stopped
printf 'y\n' | admiralctl instances reactivate "$instance_id" --force --wait --wait-timeout 10m --output json > "$run_dir/reactivate.json"
cat "$run_dir/reactivate.json"
verify_state small 536870912
query_marker after-reactivation
admiralctl instances deprovision "$instance_id" --force --wait --wait-timeout 10m --output json > "$run_dir/deprovision.json"
cat "$run_dir/deprovision.json"
su -s /bin/sh admiral-apps -c "cd / && podman ps --all --filter name=${instance_id} --format '{{.Names}}'" > "$run_dir/cleanup.txt"
[[ ! -s "$run_dir/cleanup.txt" ]] || { cat "$run_dir/cleanup.txt"; exit 1; }
echo 'resize_reactivation_secrets_and_data_persistence=PASS'
printf 'end_utc=%s instance_id=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$instance_id"
