#!/usr/bin/env bash
set -euo pipefail
os=$1
instance_id=$2
run_dir="/var/tmp/adm-r52-${os}-lifecycle"
printf 'pause_start_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
admiralctl instances pause "$instance_id" --wait --wait-timeout 5m --output json > "$run_dir/pause.json"
admiralctl instances show "$instance_id" > "$run_dir/instance-paused.json"
printf '%s\n' '--- paused instance ---'
cat "$run_dir/instance-paused.json"
python3 - "$run_dir/instance-paused.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print('paused_fields',x.get('technical_status'),x.get('health_status'),x.get('effective_availability'),x.get('availability_reason'))
if x.get('technical_status') not in ('stopped','paused_for_storage'):
    raise SystemExit('pause action did not leave a stopped/paused state')
if x.get('effective_availability') != 'unavailable':
    raise SystemExit('paused instance was incorrectly reported as available')
if not x.get('availability_reason'):
    raise SystemExit('unavailable lifecycle reason is missing')
PY
printf '%s\n' '--- paused runtime ---'
su -s /bin/sh admiral-apps -c "cd / && podman ps --all --filter name=${instance_id} --format '{{.Names}}|{{.Status}}|{{.Ports}}'"
printf '%s\n' '--- paused app HTTP probe (expected unavailable) ---'
http_code=$(curl --silent --show-error --max-time 5 --output /dev/null --write-out '%{http_code}' http://127.0.0.1:40000/ 2> "$run_dir/paused-curl.stderr" || true)
printf 'http_status=%s\n' "$http_code"
[[ $http_code != 200 ]] || { echo 'paused workload continued to serve HTTP 200'; exit 1; }
echo 'pause_availability_regression=PASS'
printf 'pause_end_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
