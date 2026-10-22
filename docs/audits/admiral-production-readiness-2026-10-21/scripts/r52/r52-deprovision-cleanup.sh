#!/usr/bin/env bash
set -euo pipefail
os=$1
instance_id=$2
run_dir="/var/tmp/adm-r52-${os}-lifecycle"
printf 'deprovision_start_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
admiralctl instances deprovision "$instance_id" --force --wait --wait-timeout 10m --output json > "$run_dir/deprovision.json"
cat "$run_dir/deprovision.json"
admiralctl instances show "$instance_id" > "$run_dir/instance-deprovisioned.json"
cat "$run_dir/instance-deprovisioned.json"
python3 - "$run_dir/instance-deprovisioned.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print('deprovisioned_fields',x.get('technical_status'),x.get('health_status'),x.get('effective_availability'),x.get('availability_reason'))
if x.get('technical_status') != 'deprovisioned': raise SystemExit('instance did not reach deprovisioned technical status')
if x.get('effective_availability') != 'unavailable': raise SystemExit('deprovisioned instance incorrectly reported available')
if x.get('availability_reason') != 'instance_deprovisioned': raise SystemExit('deprovisioned lifecycle reason missing')
PY
uid=$(id -u admiral-apps)
echo '--- matching rootless containers ---'
su -s /bin/sh admiral-apps -c "cd / && podman ps --all --filter name=${instance_id} --format '{{.Names}}|{{.Status}}'" > "$run_dir/containers-after-deprovision.txt"
cat "$run_dir/containers-after-deprovision.txt"
[[ ! -s "$run_dir/containers-after-deprovision.txt" ]] || { echo 'matching containers remain after deprovision'; exit 1; }
echo '--- matching rootless volumes ---'
su -s /bin/sh admiral-apps -c "cd / && podman volume ls --filter name=${instance_id} --format '{{.Name}}'" > "$run_dir/volumes-after-deprovision.txt"
cat "$run_dir/volumes-after-deprovision.txt"
[[ ! -s "$run_dir/volumes-after-deprovision.txt" ]] || { echo 'matching volumes remain after deprovision'; exit 1; }
echo '--- matching user units ---'
runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user list-units --all --no-legend --no-pager | grep -F "$instance_id" > "$run_dir/units-after-deprovision.txt" || true
cat "$run_dir/units-after-deprovision.txt"
[[ ! -s "$run_dir/units-after-deprovision.txt" ]] || { echo 'matching user units remain after deprovision'; exit 1; }
echo '--- matching data/config paths ---'
find /var/lib/admiral /etc/containers/systemd /home/admiral-apps/.config/containers/systemd -xdev -print 2>/dev/null | grep -F "$instance_id" > "$run_dir/paths-after-deprovision.txt" || true
cat "$run_dir/paths-after-deprovision.txt"
[[ ! -s "$run_dir/paths-after-deprovision.txt" ]] || { echo 'matching files remain after deprovision'; exit 1; }
echo 'deprovision_lifecycle_and_cleanup=PASS'
printf 'deprovision_end_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
