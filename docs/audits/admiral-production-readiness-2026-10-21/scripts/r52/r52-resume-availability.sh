#!/usr/bin/env bash
set -euo pipefail
os=$1
instance_id=$2
run_dir="/var/tmp/adm-r52-${os}-lifecycle"
printf 'resume_start_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
admiralctl instances resume "$instance_id" --wait --wait-timeout 5m --output json > "$run_dir/resume.json"
cat "$run_dir/resume.json"
for attempt in $(seq 1 20); do
  admiralctl instances show "$instance_id" > "$run_dir/instance-resumed.json"
  fields=$(python3 - "$run_dir/instance-resumed.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print(x.get('technical_status',''),x.get('health_status',''),x.get('effective_availability',''),x.get('availability_reason',''))
PY
)
  printf 'poll=%s utc=%s %s\n' "$attempt" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$fields"
  read -r tech health avail reason <<< "$fields"
  if [[ $tech == running && $health == healthy && $avail == available ]]; then
    for probe in $(seq 1 10); do
      status=$(curl --silent --show-error --max-time 5 --output "$run_dir/http-body.txt" --write-out '%{http_code}' http://127.0.0.1:40000/ || true)
      body=$(head -n 1 "$run_dir/http-body.txt" 2>/dev/null || true)
      printf 'http_probe=%s utc=%s status=%s body_first_line=%s\n' "$probe" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$status" "$body"
      [[ $status == 200 ]] || { echo 'resumed workload did not return HTTP 200'; exit 1; }
      sleep 1
    done
    echo 'resume_availability_regression=PASS'
    exit 0
  fi
  sleep 5
done
echo 'resumed instance did not converge within 100-second poll window'
exit 1
