#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Check active-node removal returns one authenticated HTTP 409 on Release 70.
set -euo pipefail
[[ $# -eq 7 ]] || { echo "usage: $0 SSH_KEY HUB_KNOWN WORKER_KNOWN HUB_IP WORKER_IP NODE_ID OUTPUT_DIR" >&2; exit 2; }
ssh_key=$1 hub_known=$2 worker_known=$3 hub_ip=$4 worker_ip=$5 node_id=$6 output_dir=$7
[[ $node_id =~ ^adm-r70-rocky-w[12]$ && $output_dir == /* ]] || { echo 'invalid worker node or output path' >&2; exit 2; }
for p in "$ssh_key" "$hub_known" "$worker_known"; do [[ -r $p ]] || { echo "unreadable input: $p" >&2; exit 1; }; done
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../../../../.." && pwd)
fixture="$repo_root/examples/apps/e2e-whoami.yaml"
[[ -r $fixture ]] || { echo "fixture not found: $fixture" >&2; exit 1; }
overlay_ip=10.99.0.2; [[ $node_id == adm-r70-rocky-w2 ]] && overlay_ip=10.99.0.3
install -d -m 0700 "$output_dir"; umask 077
ssh_args=(-i "$ssh_key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes)
hub_args=("${ssh_args[@]}" -o "UserKnownHostsFile=$hub_known")
worker_args=("${ssh_args[@]}" -o "UserKnownHostsFile=$worker_known")
hub="validator@$hub_ip"; worker="validator@$worker_ip"; instance_id=
cleanup() {
  local rc=$?; trap - EXIT
  if [[ -n $instance_id ]]; then
    ssh "${hub_args[@]}" "$hub" "sudo -u validator env HOME=/home/validator admiralctl instances deprovision '$instance_id' --force --wait --wait-timeout 10m --output json" >"$output_dir/final-deprovision-on-exit.json" 2>&1 || true
  fi
  ssh "${hub_args[@]}" "$hub" 'rm -f -- /tmp/r70-e2e-whoami-api-conflict.yaml' >/dev/null 2>&1 || true
  find "$output_dir" -maxdepth 1 -type f -exec chmod 0600 {} +
  (cd "$output_dir" && find . -maxdepth 1 -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
  chmod 0600 "$output_dir/SHA256SUMS"; exit "$rc"
}
trap cleanup EXIT

ssh "${hub_args[@]}" "$hub" 'rpm -q --qf "%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n" admiral-common admirald admiral-fleet admiralctl admiral-flagship admiral-harbor | sort' >"$output_dir/candidate-hub.txt"
ssh "${worker_args[@]}" "$worker" 'rpm -q --qf "%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n" admiral-common admiral-fleet | sort' >"$output_dir/candidate-worker.txt"
[[ $(grep -c -- '-0.0.1rc5-70\.el10\.' "$output_dir/candidate-hub.txt") -eq 6 ]]
[[ $(grep -c -- '-0.0.1rc5-70\.el10\.' "$output_dir/candidate-worker.txt") -eq 2 ]]
suffix=$(date -u +%Y%m%d%H%M%S); customer="r70-rocky-api-conflict-$suffix"; key="r70-rocky-api-conflict-$suffix"
scp "${hub_args[@]}" "$fixture" "$hub:/tmp/r70-e2e-whoami-api-conflict.yaml"
ssh "${hub_args[@]}" "$hub" 'sudo -u validator env HOME=/home/validator admiralctl apps apply --file /tmp/r70-e2e-whoami-api-conflict.yaml' >"$output_dir/app-apply.log" 2>&1
ssh "${hub_args[@]}" "$hub" "sudo -u validator env HOME=/home/validator admiralctl instances provision --app e2e-whoami --tier small --customer '$customer' --idempotency-key '$key' --node '$node_id' --wait --wait-timeout 10m --quiet --output json" >"$output_dir/provision.json"
instance_id=$(python3 - "$output_dir/provision.json" "$node_id" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
if x.get('status')!='succeeded' or x.get('node_id')!=sys.argv[2] or not x.get('instance_id'): raise SystemExit('provision failed on requested worker')
print(x['instance_id'])
PY
)
ssh "${hub_args[@]}" "$hub" "sudo -u validator env HOME=/home/validator admiralctl instances show '$instance_id'" >"$output_dir/instance-before-removal.json"
python3 - "$output_dir/instance-before-removal.json" "$node_id" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
if (x.get('node_id'),x.get('technical_status'),x.get('health_status'),x.get('effective_availability')) != (sys.argv[2],'running','healthy','available'): raise SystemExit('workload is not running/healthy/available')
PY
endpoint=$(ssh "${worker_args[@]}" "$worker" sudo bash -s -- "$instance_id" <<'REMOTE'
set -euo pipefail; cd /tmp; uid=$(id -u admiral-apps); app_home=$(getent passwd admiral-apps | cut -d: -f6)
runuser -u admiral-apps -- env HOME="$app_home" XDG_RUNTIME_DIR="/run/user/$uid" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" podman port "admiral-$1-app" 80/tcp | head -n1
REMOTE
)
[[ $endpoint =~ ^"$overlay_ip":[0-9]+$ ]]
http_before=$(ssh "${hub_args[@]}" "$hub" "curl --connect-timeout 3 --max-time 10 -sS -o /dev/null -w '%{http_code}' 'http://$endpoint/'")
[[ $http_before == 200 ]]

# The token stays on the hub and is never written to the captured output.
ssh "${hub_args[@]}" "$hub" sudo bash -s -- "$node_id" >"$output_dir/api-active-removal-response.txt" 2>&1 <<'REMOTE'
set -euo pipefail; node_id=$1; source /etc/admiral/flagship.env
: "${ADMIRAL_INTERNAL_TOKEN:?missing internal API token}"
response=$(mktemp /tmp/r70-node-removal-response.XXXXXX)
trap 'rm -f -- "$response"; unset ADMIRAL_INTERNAL_TOKEN' EXIT
status=$(curl --silent --show-error --connect-timeout 3 --max-time 10 --cacert /etc/admiral/tls/ca.pem -H "X-Admiral-Token: $ADMIRAL_INTERNAL_TOKEN" -X DELETE -o "$response" -w '%{http_code}' "https://10.99.0.1:8080/api/v1/nodes/$node_id")
printf 'http_status=%s\n' "$status"; cat "$response"; [[ $status == 409 ]]
REMOTE
grep -Fx 'http_status=409' "$output_dir/api-active-removal-response.txt" >/dev/null
grep -F 'node has active instances (1 active instance)' "$output_dir/api-active-removal-response.txt" >/dev/null

ssh "${hub_args[@]}" "$hub" sudo bash -s -- "$node_id" >"$output_dir/cli-active-removal-response.txt" 2>&1 <<'REMOTE'
set -u; node_id=$1; set +e
printf 'y\n' | sudo -u validator env HOME=/home/validator admiralctl nodes remove "$node_id"
rc=$?; set -e; printf 'command_exit=%s\n' "$rc"; [[ $rc == 1 ]]
REMOTE
grep -F 'node has active instances (1 active instance)' "$output_dir/cli-active-removal-response.txt" >/dev/null
grep -Fx 'command_exit=1' "$output_dir/cli-active-removal-response.txt" >/dev/null
ssh "${hub_args[@]}" "$hub" "sudo -u validator env HOME=/home/validator admiralctl nodes show '$node_id'" >"$output_dir/node-after-rejected-removal.json"
ssh "${hub_args[@]}" "$hub" "sudo -u validator env HOME=/home/validator admiralctl instances show '$instance_id'" >"$output_dir/instance-after-rejected-removal.json"
python3 - "$output_dir/instance-after-rejected-removal.json" "$node_id" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
if (x.get('node_id'),x.get('technical_status'),x.get('health_status'),x.get('effective_availability')) != (sys.argv[2],'running','healthy','available'): raise SystemExit('workload changed after rejected removal')
PY
http_after=$(ssh "${hub_args[@]}" "$hub" "curl --connect-timeout 3 --max-time 10 -sS -o /dev/null -w '%{http_code}' 'http://$endpoint/'")
[[ $http_after == 200 ]]
printf 'test_id=R70-ROCKY-MN-API-CONFLICT-01\ncandidate=0.0.1rc5-70.el10\nnode_id=%s\ninstance_id=%s\nendpoint=%s\napi_http_status=409\nhttp_after_rejection=%s\nfinished_utc=%s\nresult=PASS\n' "$node_id" "$instance_id" "$endpoint" "$http_after" "$(date -u +%FT%TZ)" >"$output_dir/metadata.txt"
ssh "${hub_args[@]}" "$hub" "sudo -u validator env HOME=/home/validator admiralctl instances deprovision '$instance_id' --force --wait --wait-timeout 10m --output json" >"$output_dir/deprovision.json"
python3 - "$output_dir/deprovision.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
if x.get('status')!='succeeded': raise SystemExit('deprovision failed')
print(f"deprovision_operation={x.get('id')} status={x.get('status')}")
PY
ssh "${worker_args[@]}" "$worker" sudo bash -s -- "$instance_id" >"$output_dir/final-inventory.txt" <<'REMOTE'
set -euo pipefail; cd /tmp; instance_id=$1; uid=$(id -u admiral-apps); app_home=$(getent passwd admiral-apps | cut -d: -f6)
run_as_apps() { runuser -u admiral-apps -- env HOME="$app_home" XDG_RUNTIME_DIR="/run/user/$uid" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" podman "$@"; }
containers=$(run_as_apps ps -a --filter "name=$instance_id" --format '{{.Names}}'); pods=$(run_as_apps pod ps --format '{{.Name}}' | grep -F "$instance_id" || true); volumes=$(run_as_apps volume ls --format '{{.Name}}' | grep -F "$instance_id" || true); files=$(find /etc/containers/systemd /var/lib/admiral "$app_home/.config/containers/systemd" -xdev -iname "*$instance_id*" -print 2>/dev/null || true)
printf 'containers=%s\npods=%s\nvolumes=%s\nfiles=%s\n' "${containers:-none}" "${pods:-none}" "${volumes:-none}" "${files:-none}"
[[ -z $containers && -z $pods && -z $volumes && -z $files ]]
REMOTE
instance_id=
echo "result=PASS evidence=$output_dir"
