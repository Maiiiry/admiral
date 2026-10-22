#!/usr/bin/env bash
set -euo pipefail
os=$1
customer=$2
key=$3
run_dir="/var/tmp/adm-r57-${os}-process-recovery"
install -d -m 0700 "$run_dir"
cp /tmp/audit-e2e-whoami.yaml "$run_dir/e2e-whoami.yaml"
admiralctl apps apply --file "$run_dir/e2e-whoami.yaml" > "$run_dir/apply.log" 2>&1
printf 'os=%s start_utc=%s\n' "$os" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
admiralctl instances provision --app e2e-whoami --tier small --customer "$customer" --idempotency-key "$key" --wait --wait-timeout 10m --quiet --output json > "$run_dir/provision.json"
instance_id=$(python3 - "$run_dir/provision.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
if x.get('status')!='succeeded': raise SystemExit('initial provision not succeeded')
print(x['instance_id'])
PY
)
operation_id=$(python3 - "$run_dir/provision.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print(x.get('id') or x.get('operation_id'))
PY
)
app_container="admiral-${instance_id}-app"
app_unit="admiral-${instance_id}-app.service"
uid=$(id -u admiral-apps)
runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user show "$app_unit" -p ActiveState -p NRestarts -p ExecMainStatus > "$run_dir/app-unit-before-kill.txt"
cat "$run_dir/app-unit-before-kill.txt"
echo '--- kill app container process ---'
su -s /bin/sh admiral-apps -c "cd / && podman kill ${app_container}" > "$run_dir/podman-kill.txt"
cat "$run_dir/podman-kill.txt"
recovered=0
for attempt in $(seq 1 60); do
  su -s /bin/sh admiral-apps -c "cd / && podman inspect --format '{{.State.Status}}' ${app_container}" > "$run_dir/app-container-state.txt" 2>/dev/null || true
  state=$(cat "$run_dir/app-container-state.txt" 2>/dev/null || true)
  unit_state=$(runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user show "$app_unit" -p ActiveState --value 2>/dev/null || true)
  mapping=$(su -s /bin/sh admiral-apps -c "cd / && podman port ${app_container} 80/tcp" 2>/dev/null | head -n1 || true)
  port=${mapping##*:}
  if [[ $state == running && $unit_state == active && $port =~ ^[0-9]+$ ]]; then
    http=$(curl --silent --show-error --max-time 3 --output "$run_dir/app-after-container-kill.txt" --write-out '%{http_code}' "http://127.0.0.1:${port}/" || true)
    if [[ $http == 200 ]]; then
      restarts=$(runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user show "$app_unit" -p NRestarts --value)
      echo "app_container_recovered_attempt=$attempt state=$state unit=$unit_state nrestarts=$restarts port=$port http=$http utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      recovered=1; break
    fi
  fi
  sleep 2
done
[[ $recovered -eq 1 ]] || { echo 'app container did not recover after Podman kill within 120s'; exit 1; }
echo '--- kill admirald process ---'
admirald_pid_before=$(systemctl show admirald -p MainPID --value)
systemctl kill --signal=SIGKILL admirald
for attempt in $(seq 1 30); do
  admirald_pid_after=$(systemctl show admirald -p MainPID --value)
  if systemctl is-active --quiet admirald && [[ $admirald_pid_after =~ ^[1-9][0-9]*$ && $admirald_pid_after != "$admirald_pid_before" ]] && admiralctl status > "$run_dir/status-after-admirald-kill.txt" 2>&1 && grep -q 'Control Plane:    healthy' "$run_dir/status-after-admirald-kill.txt"; then
    echo "admirald_recovered_attempt=$attempt pid_before=$admirald_pid_before pid_after=$admirald_pid_after utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    cat "$run_dir/status-after-admirald-kill.txt"
    break
  fi
  [[ $attempt -lt 30 ]] || { systemctl status admirald --no-pager; exit 1; }
  sleep 2
done
admiralctl operations list --output json > "$run_dir/operations-after-admirald-kill.json"
python3 - "$run_dir/operations-after-admirald-kill.json" "$instance_id" "$operation_id" <<'PY'
import json,sys
items=json.load(open(sys.argv[1],encoding='utf-8'))
related=[x for x in items if x.get('instance_id')==sys.argv[2] and x.get('action') in ('provision','provision_app')]
print('related_provision_operations=',len(related),'ids=',','.join(str(x.get('id')) for x in related))
if len(related)!=1 or related[0].get('id')!=sys.argv[3]: raise SystemExit('admirald restart created duplicate provisioning operation')
PY
echo '--- kill admiral-fleet process ---'
fleet_pid_before=$(systemctl show admiral-fleet -p MainPID --value)
systemctl kill --signal=SIGKILL admiral-fleet
recovered=0
for attempt in $(seq 1 30); do
  fleet_pid_after=$(systemctl show admiral-fleet -p MainPID --value)
  if systemctl is-active --quiet admiral-fleet && [[ $fleet_pid_after =~ ^[1-9][0-9]*$ && $fleet_pid_after != "$fleet_pid_before" ]]; then
    admiralctl instances show "$instance_id" > "$run_dir/instance-after-fleet-kill.json"
    fields=$(python3 - "$run_dir/instance-after-fleet-kill.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print(x.get('technical_status',''),x.get('health_status',''),x.get('effective_availability',''))
PY
)
    read -r tech health avail <<< "$fields"
    if [[ $tech == running && $health == healthy && $avail == available ]]; then
      code=$(curl --silent --show-error --max-time 3 --output "$run_dir/app-after-fleet-kill.txt" --write-out '%{http_code}' "http://127.0.0.1:${port}/" || true)
      if [[ $code == 200 ]]; then echo "fleet_recovered_attempt=$attempt pid_before=$fleet_pid_before pid_after=$fleet_pid_after instance=$fields http=$code utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; recovered=1; break; fi
    fi
  fi
  sleep 2
done
[[ $recovered -eq 1 ]] || { echo 'Fleet did not recover safely within 60s'; exit 1; }
admiralctl instances deprovision "$instance_id" --force --wait --wait-timeout 10m --output json > "$run_dir/deprovision.json"
cat "$run_dir/deprovision.json"
su -s /bin/sh admiral-apps -c "cd / && podman ps --all --filter name=${instance_id} --format '{{.Names}}'" > "$run_dir/after-cleanup.txt"
[[ ! -s "$run_dir/after-cleanup.txt" ]] || { cat "$run_dir/after-cleanup.txt"; exit 1; }
echo 'process_and_quadlet_recovery=PASS'
printf 'end_utc=%s instance_id=%s operation_id=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$instance_id" "$operation_id"
