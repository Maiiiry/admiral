#!/usr/bin/env bash
# Race a tier update against deprovision on one disposable R63 guest.
set -euo pipefail
cd /
[[ $# -eq 3 ]] || { echo "usage: $0 {rocky|alma|centos} CUSTOMER IDEMPOTENCY_KEY" >&2; exit 2; }
os=$1 customer=$2 key=$3
run_dir="/var/tmp/adm-r63-${os}-concurrent-update-delete"
install -d -m 0700 "$run_dir"
cp /tmp/audit-e2e-resize.yaml "$run_dir/fixture.yaml"
chmod 0600 "$run_dir/fixture.yaml"
printf 'candidate=R63 os=%s start_utc=%s\n' "$os" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
admiralctl apps apply --file "$run_dir/fixture.yaml" > "$run_dir/apply.log" 2>&1
admiralctl instances provision --app e2e-resize-audit --tier small --customer "$customer" --idempotency-key "$key" --wait --wait-timeout 10m --quiet --output json > "$run_dir/provision.json"
instance_id=$(python3 - "$run_dir/provision.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
if x.get('status')!='succeeded' or not x.get('instance_id'):
    raise SystemExit('initial provision did not succeed')
print(x['instance_id'])
PY
)
cleanup_enabled=1
cleanup() {
  rc=$?
  trap - EXIT
  if [[ ${cleanup_enabled:-0} -eq 1 && -n ${instance_id:-} ]]; then
    admiralctl instances deprovision "$instance_id" --force --wait --wait-timeout 10m --output json >/dev/null 2>&1 || true
  fi
  exit "$rc"
}
trap cleanup EXIT
printf 'instance_id=%s\n' "$instance_id"

set +e
(
  printf 'y\n' | admiralctl instances resize --tier medium "$instance_id" --wait --wait-timeout 10m --output json \
    > "$run_dir/resize.json" 2> "$run_dir/resize.stderr"
  echo "$?" > "$run_dir/resize.exit"
) &
resize_pid=$!
sleep 0.25
(
  admiralctl instances deprovision "$instance_id" --force --wait --wait-timeout 10m --output json \
    > "$run_dir/deprovision.json" 2> "$run_dir/deprovision.stderr"
  echo "$?" > "$run_dir/deprovision.exit"
) &
deprovision_pid=$!
wait "$resize_pid"
wait "$deprovision_pid"
set -e

[[ -s "$run_dir/resize.exit" && -s "$run_dir/deprovision.exit" ]] || {
  echo 'one concurrent CLI process did not record its exit status' >&2
  exit 1
}
printf 'resize_exit=%s\ndeprovision_exit=%s\n' "$(cat "$run_dir/resize.exit")" "$(cat "$run_dir/deprovision.exit")"
cat "$run_dir/resize.json" "$run_dir/resize.stderr" "$run_dir/deprovision.json" "$run_dir/deprovision.stderr"
python3 - "$run_dir/resize.json" "$run_dir/deprovision.json" <<'PY'
import json,sys
def load_cli_json(path):
    text=open(path,encoding='utf-8').read()
    start=text.find('{')
    if start<0:
        raise SystemExit(f'CLI output has no JSON object: {path}')
    return json.loads(text[start:])
resize=load_cli_json(sys.argv[1])
delete=load_cli_json(sys.argv[2])
print('resize_operation=',resize.get('id'),'status=',resize.get('status'),'updated_at=',resize.get('updated_at'))
print('deprovision_operation=',delete.get('id'),'status=',delete.get('status'),'updated_at=',delete.get('updated_at'))
if delete.get('action')!='deprovision_app' or delete.get('status')!='succeeded':
    raise SystemExit('deprovision did not reach a successful terminal result')
if resize.get('action')!='resize_app' or resize.get('status') not in ('succeeded','failed','cancelled'):
    raise SystemExit('resize did not reach an acceptable terminal result')
PY

admiralctl instances show "$instance_id" > "$run_dir/final-instance.json"
python3 - "$run_dir/final-instance.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print('final_instance_state=',x.get('technical_status'),x.get('effective_availability'),x.get('availability_reason'))
if x.get('technical_status')!='deprovisioned':
    raise SystemExit('final instance state is not deprovisioned')
PY
uid=$(id -u admiral-apps)
runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman ps --all --filter name="$instance_id" --format '{{.Names}}|{{.Status}}' > "$run_dir/resources-final.txt"
if [[ -s "$run_dir/resources-final.txt" ]]; then
  cat "$run_dir/resources-final.txt"
  echo 'runtime resources remain after concurrent update/delete' >&2
  exit 1
fi
cleanup_enabled=0
echo 'concurrent_update_delete_final_state=PASS'
printf 'end_utc=%s instance_id=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$instance_id"
