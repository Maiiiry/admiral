#!/usr/bin/env bash
set -euo pipefail
cd /
os=$1
customer=$2
key=$3
run_dir="/var/tmp/adm-r62-${os}-concurrent-idempotency"
install -d -m 0700 "$run_dir"
cleanup_enabled=1
cleanup() {
  rc=$?
  trap - EXIT
  if [[ ${cleanup_enabled:-0} -eq 1 ]]; then
    while IFS= read -r leftover; do
      [[ -n $leftover ]] || continue
      admiralctl instances deprovision "$leftover" --force --wait --wait-timeout 10m --output json >/dev/null 2>&1 || true
    done < <(python3 - "$run_dir" <<'PY'
import glob, json, pathlib, sys
seen = set()
for name in glob.glob(str(pathlib.Path(sys.argv[1]) / "request-*.json")):
    try:
        item = json.load(open(name, encoding="utf-8"))
    except (OSError, ValueError):
        continue
    instance_id = item.get("instance_id")
    if instance_id and instance_id not in seen:
        seen.add(instance_id)
        print(instance_id)
PY
    )
  fi
  exit "$rc"
}
trap cleanup EXIT
cp /tmp/audit-e2e-whoami.yaml "$run_dir/e2e-whoami.yaml"
chmod 0600 "$run_dir/e2e-whoami.yaml"
printf 'candidate=R62 os=%s customer=%s key=%s start_utc=%s\n' "$os" "$customer" "$key" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
admiralctl apps apply --file "$run_dir/e2e-whoami.yaml" > "$run_dir/apply.log" 2>&1
for n in 1 2 3; do
  admiralctl instances provision --app e2e-whoami --tier small --customer "$customer" --idempotency-key "$key" --wait --wait-timeout 10m --quiet --output json > "$run_dir/request-$n.json" 2> "$run_dir/request-$n.stderr" &
  echo "request_${n}_pid=$!"
done
wait
python3 - "$run_dir" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])
rows=[]
for n in range(1,4):
    x=json.load(open(p/f'request-{n}.json',encoding='utf-8'))
    row=(x.get('id') or x.get('operation_id'),x.get('instance_id'),x.get('status'))
    print(f'request_{n}_operation={row[0]} instance={row[1]} status={row[2]}')
    if not row[0] or not row[1] or row[2]!='succeeded': raise SystemExit(f'request {n} did not succeed')
    rows.append(row)
if len(set(rows))!=1: raise SystemExit(f'concurrent requests diverged: {rows}')
PY
instance_id=$(python3 - "$run_dir/request-1.json" <<'PY'
import json,sys
print(json.load(open(sys.argv[1],encoding='utf-8'))['instance_id'])
PY
)
admiralctl instances list --customer "$customer" --output json > "$run_dir/customer-instances.json"
python3 - "$run_dir/customer-instances.json" "$instance_id" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print('customer_instance_count=',len(x))
for row in x: print('instance_id=',row.get('id'))
if len(x)!=1 or x[0].get('id')!=sys.argv[2]: raise SystemExit('customer has duplicate or unexpected instances')
PY
sudo -n -u admiral-apps podman ps --all --filter name=${instance_id} --format '{{.Names}}|{{.Status}}|{{.Ports}}' > "$run_dir/runtime-resources.txt"
cat "$run_dir/runtime-resources.txt"
[[ $(wc -l < "$run_dir/runtime-resources.txt") -eq 3 ]] || { echo 'runtime resource count is not exactly three'; exit 1; }
admiralctl instances deprovision "$instance_id" --force --wait --wait-timeout 10m --output json > "$run_dir/deprovision.json"
cat "$run_dir/deprovision.json"
sudo -n -u admiral-apps podman ps --all --filter name=${instance_id} --format '{{.Names}}' > "$run_dir/after-cleanup.txt"
[[ ! -s "$run_dir/after-cleanup.txt" ]] || { cat "$run_dir/after-cleanup.txt"; exit 1; }
cleanup_enabled=0
echo 'concurrent_same_key_idempotency=PASS'
printf 'end_utc=%s instance_id=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$instance_id"
