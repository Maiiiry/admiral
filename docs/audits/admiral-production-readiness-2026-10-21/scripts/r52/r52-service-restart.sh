#!/usr/bin/env bash
set -euo pipefail
os=$1
instance_id=$2
run_dir="/var/tmp/adm-r52-${os}-lifecycle"
printf 'restart_start_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo '--- restart admirald ---'
systemctl restart admirald
for attempt in $(seq 1 30); do
  if systemctl is-active --quiet admirald && admiralctl status > "$run_dir/status-after-admirald-restart.txt" 2>&1; then
    if grep -q 'Control Plane:    healthy' "$run_dir/status-after-admirald-restart.txt"; then
      echo "admirald_restart=active_and_healthy attempt=$attempt utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      cat "$run_dir/status-after-admirald-restart.txt"
      break
    fi
  fi
  [[ $attempt -lt 30 ]] || { cat "$run_dir/status-after-admirald-restart.txt"; echo 'admirald failed to recover within 60s'; exit 1; }
  sleep 2
done
echo '--- restart admiral-fleet ---'
systemctl restart admiral-fleet
systemctl is-active admiral-fleet
for attempt in $(seq 1 30); do
  admiralctl instances show "$instance_id" > "$run_dir/instance-after-fleet-restart.json"
  fields=$(python3 - "$run_dir/instance-after-fleet-restart.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print(x.get('technical_status',''),x.get('health_status',''),x.get('effective_availability',''),x.get('availability_reason',''))
PY
)
  printf 'fleet_restart_poll=%s utc=%s %s\n' "$attempt" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$fields"
  read -r tech health avail reason <<< "$fields"
  if [[ $tech == running && $health == healthy && $avail == available ]]; then
    status=$(curl --silent --show-error --max-time 5 --output "$run_dir/http-after-restarts.txt" --write-out '%{http_code}' http://127.0.0.1:40000/ || true)
    printf 'app_http_after_service_restarts=%s\n' "$status"
    [[ $status == 200 ]] || { echo 'HTTP endpoint not healthy after service restarts'; exit 1; }
    break
  fi
  [[ $attempt -lt 30 ]] || { echo 'instance failed to recover within 60s after Fleet restart'; exit 1; }
  sleep 2
done
echo '--- remaining rootless containers ---'
su -s /bin/sh admiral-apps -c "cd / && podman ps --all --filter name=${instance_id} --format '{{.Names}}|{{.Status}}|{{.Ports}}'" > "$run_dir/podman-after-service-restarts.txt"
cat "$run_dir/podman-after-service-restarts.txt"
count=$(wc -l < "$run_dir/podman-after-service-restarts.txt")
[[ $count -eq 3 ]] || { echo "expected 3 runtime containers after restart, found $count"; exit 1; }
echo 'service_restart_recovery=PASS'
printf 'restart_end_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
