#!/usr/bin/env bash
set -euo pipefail
os=$1
customer=$2
idempotency_key=$3
run_dir="/var/tmp/adm-r52-${os}-lifecycle"
install -d -m 0700 "$run_dir"
cp /tmp/audit-e2e-whoami.yaml "$run_dir/e2e-whoami.yaml"
chmod 0600 "$run_dir/e2e-whoami.yaml"
printf 'guest=%s\ncustomer=%s\nidempotency_key=%s\nstart_utc=%s\n' "$os" "$customer" "$idempotency_key" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
admiralctl apps apply --file "$run_dir/e2e-whoami.yaml" > "$run_dir/apply.log" 2>&1
admiralctl instances provision --app e2e-whoami --tier small --customer "$customer" --idempotency-key "$idempotency_key" --wait --wait-timeout 10m --quiet --output json > "$run_dir/provision-1.json"
admiralctl instances provision --app e2e-whoami --tier small --customer "$customer" --idempotency-key "$idempotency_key" --wait --wait-timeout 10m --quiet --output json > "$run_dir/provision-replay.json"
python3 - "$run_dir/provision-1.json" "$run_dir/provision-replay.json" <<'PY'
import json, sys

def ids(path):
    with open(path, encoding='utf-8') as f:
        obj=json.load(f)
    return (obj.get('operation_id') or obj.get('id'), obj.get('instance_id'), obj.get('status'))
a=ids(sys.argv[1]); b=ids(sys.argv[2])
print(f'first_operation={a[0]} first_instance={a[1]} first_status={a[2]}')
print(f'replay_operation={b[0]} replay_instance={b[1]} replay_status={b[2]}')
if not a[0] or not a[1] or a[2] != 'succeeded': raise SystemExit('initial provision missing IDs or not succeeded')
if a != b: raise SystemExit('same-key replay did not return the same operation/instance/status')
PY
instance_id=$(python3 - "$run_dir/provision-1.json" <<'PY'
import json,sys
print(json.load(open(sys.argv[1],encoding='utf-8'))['instance_id'])
PY
)
admiralctl instances show "$instance_id" > "$run_dir/instance-initial.json"
printf '%s\n' '--- initial instance state ---'
cat "$run_dir/instance-initial.json"
printf '%s\n' '--- rootless podman containers ---'
su -s /bin/sh admiral-apps -c "cd / && podman ps --all --format '{{.Names}}|{{.Status}}|{{.Ports}}'" > "$run_dir/podman-ps-initial.txt"
cat "$run_dir/podman-ps-initial.txt"
printf 'end_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
