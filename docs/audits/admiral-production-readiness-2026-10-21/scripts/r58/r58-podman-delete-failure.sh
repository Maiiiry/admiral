#!/usr/bin/env bash
set -euo pipefail
cd /
os=$1
customer=$2
key=$3
run_dir="/var/tmp/adm-r58-${os}-podman-failure"
install -d -m 0700 "$run_dir"
cp /tmp/audit-e2e-whoami.yaml "$run_dir/e2e-whoami.yaml"
admiralctl apps apply --file "$run_dir/e2e-whoami.yaml" > "$run_dir/apply.log" 2>&1
printf 'os=%s start_utc=%s\n' "$os" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
admiralctl instances provision --app e2e-whoami --tier small --customer "$customer" --idempotency-key "$key" --wait --wait-timeout 10m --quiet --output json > "$run_dir/provision.json"
instance_id=$(python3 - "$run_dir/provision.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
if x.get('status')!='succeeded': raise SystemExit('provision not succeeded')
print(x['instance_id'])
PY
)
original_sha=$(sha256sum /usr/bin/podman | awk '{print $1}')
printf 'instance_id=%s podman_sha_before=%s\n' "$instance_id" "$original_sha"
bash /tmp/inject-podman-removal-failure.sh "$instance_id" > "$run_dir/injection-setup.txt"
cat "$run_dir/injection-setup.txt"
set +e
admiralctl instances deprovision "$instance_id" --force --wait --wait-timeout 10m --output json > "$run_dir/deprovision-injected.json" 2> "$run_dir/deprovision-injected.stderr"
injected_rc=$?
set -e
cat "$run_dir/deprovision-injected.json"
cat "$run_dir/deprovision-injected.stderr"
printf 'injected_deprovision_exit=%s\n' "$injected_rc"
[[ $injected_rc -ne 0 ]] || { echo 'deprovision reported success despite injected Podman deletion failures'; exit 1; }
admiralctl instances show "$instance_id" > "$run_dir/instance-after-injected-failure.json"
cat "$run_dir/instance-after-injected-failure.json"
python3 - "$run_dir/instance-after-injected-failure.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print('failed_delete_instance_state',x.get('technical_status'),x.get('effective_availability'),x.get('availability_reason'))
if x.get('technical_status')=='deprovisioned': raise SystemExit('instance marked deprovisioned while Podman cleanup failed')
PY
uid=$(id -u admiral-apps)
su -s /bin/sh admiral-apps -c "cd / && podman ps --all --filter name=${instance_id} --format '{{.Names}}|{{.Status}}'" > "$run_dir/resources-after-injected-failure.txt"
cat "$run_dir/resources-after-injected-failure.txt"
[[ -s "$run_dir/resources-after-injected-failure.txt" ]] || { echo 'injection did not leave expected resources to support verification'; exit 1; }
bash /tmp/restore-podman-after-injection.sh "$instance_id" > "$run_dir/podman-restore.txt"
cat "$run_dir/podman-restore.txt"
restored_sha=$(sha256sum /usr/bin/podman | awk '{print $1}')
printf 'podman_sha_after_restore=%s\n' "$restored_sha"
[[ $restored_sha == "$original_sha" ]] || { echo 'original Podman binary hash was not restored'; exit 1; }
cp "/var/lib/admiral/audit-podman-fail-${instance_id}.log" "$run_dir/injected-commands.log"
chmod 0600 "$run_dir/injected-commands.log"
sha256sum "$run_dir/injected-commands.log"
admiralctl instances deprovision "$instance_id" --force --wait --wait-timeout 10m --output json > "$run_dir/deprovision-retry.json"
cat "$run_dir/deprovision-retry.json"
su -s /bin/sh admiral-apps -c "cd / && podman ps --all --filter name=${instance_id} --format '{{.Names}}'" > "$run_dir/resources-after-retry.txt"
[[ ! -s "$run_dir/resources-after-retry.txt" ]] || { cat "$run_dir/resources-after-retry.txt"; echo 'resources remain after retry'; exit 1; }
echo 'podman_delete_failure_and_retry=PASS'
printf 'end_utc=%s instance_id=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$instance_id"
