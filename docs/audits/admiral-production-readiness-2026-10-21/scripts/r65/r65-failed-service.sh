#!/usr/bin/env bash
set -euo pipefail
cd /
os=$1
customer=$2
idempotency_key=$3
run_dir="/var/tmp/adm-r65-${os}-failed-service"
install -d -m 0700 "$run_dir"
cp /tmp/audit-e2e-failing-db.yaml "$run_dir/fixture.yaml"
chmod 0600 "$run_dir/fixture.yaml"
printf 'os=%s customer=%s start_utc=%s\n' "$os" "$customer" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
admiralctl apps apply --file "$run_dir/fixture.yaml" > "$run_dir/apply.log" 2>&1
set +e
admiralctl instances provision --app e2e-failing-db-audit --tier small --customer "$customer" --idempotency-key "$idempotency_key" --wait --wait-timeout 10m --quiet --output json > "$run_dir/provision.json" 2> "$run_dir/provision.stderr"
provision_rc=$?
set -e
cat "$run_dir/provision.json"
cat "$run_dir/provision.stderr"
printf 'provision_exit=%s\n' "$provision_rc"
[[ $provision_rc -ne 0 ]] || { echo 'failed-service fixture unexpectedly returned success'; exit 1; }
python3 - "$run_dir/provision.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print('terminal_operation=',x.get('id') or x.get('operation_id'),'instance=',x.get('instance_id'),'status=',x.get('status'))
if x.get('status')!='failed' or not x.get('instance_id'): raise SystemExit('failed-service operation did not terminate failed with instance ID')
PY
instance_id=$(python3 - "$run_dir/provision.json" <<'PY'
import json,sys
print(json.load(open(sys.argv[1],encoding='utf-8'))['instance_id'])
PY
)
admiralctl instances show "$instance_id" > "$run_dir/instance-after-failure.json"
cat "$run_dir/instance-after-failure.json"
python3 - "$run_dir/instance-after-failure.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print('instance_fields',x.get('technical_status'),x.get('health_status'),x.get('effective_availability'),x.get('availability_reason'))
if x.get('health_status')=='healthy' or x.get('effective_availability')=='available': raise SystemExit('instance falsely reports healthy/available with a failed declared service')
PY
uid=$(id -u admiral-apps)
unit="admiral-${instance_id}-db.service"
runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user show "$unit" -p LoadState -p ActiveState -p SubState -p NRestarts > "$run_dir/db-unit-state.txt"
cat "$run_dir/db-unit-state.txt"
su -s /bin/sh admiral-apps -c "cd / && podman ps --all --filter name=${instance_id}-db --format '{{.Names}}|{{.Status}}'" > "$run_dir/db-containers.txt"
echo '--- matching db containers ---'; cat "$run_dir/db-containers.txt"
if grep -q "${instance_id}-db" "$run_dir/db-containers.txt" && grep -q '|Up ' "$run_dir/db-containers.txt"; then echo 'database container unexpectedly running'; exit 1; fi
admiralctl instances deprovision "$instance_id" --force --wait --wait-timeout 10m --output json > "$run_dir/deprovision.json"
cat "$run_dir/deprovision.json"
su -s /bin/sh admiral-apps -c "cd / && podman ps --all --filter name=${instance_id} --format '{{.Names}}'" > "$run_dir/containers-after-cleanup.txt"
[[ ! -s "$run_dir/containers-after-cleanup.txt" ]] || { echo 'resources remain after cleanup'; cat "$run_dir/containers-after-cleanup.txt"; exit 1; }
echo 'failed_service_readiness_regression=PASS'
printf 'end_utc=%s instance_id=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$instance_id"
