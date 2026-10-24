#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Observe storage metadata/report convergence for an R68 workload on CentOS W2.
set -euo pipefail

[[ $# -eq 6 ]] || {
  echo "usage: $0 SSH_KEY HUB_KNOWN_HOSTS W2_KNOWN_HOSTS HUB_IP W2_IP OUTPUT_DIR" >&2
  exit 2
}
ssh_key=$1 hub_known_hosts=$2 w2_known_hosts=$3 hub_ip=$4 w2_ip=$5 output_dir=$6
[[ $output_dir == /* ]] || { echo 'OUTPUT_DIR must be absolute' >&2; exit 2; }
for path in "$ssh_key" "$hub_known_hosts" "$w2_known_hosts"; do
  [[ -r $path ]] || { echo "unreadable SSH input: $path" >&2; exit 1; }
done
install -d -m 0700 "$output_dir"
[[ -z $(find "$output_dir" -mindepth 1 -maxdepth 1 -print -quit) ]] || {
  echo "OUTPUT_DIR must be empty: $output_dir" >&2
  exit 2
}
umask 077
ssh_args=(-i "$ssh_key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=5)
hub_args=("${ssh_args[@]}" -o "UserKnownHostsFile=$hub_known_hosts")
w2_args=("${ssh_args[@]}" -o "UserKnownHostsFile=$w2_known_hosts")
hub="validator@$hub_ip"
worker="validator@$w2_ip"
fixture="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../../.." && pwd)/examples/apps/e2e-whoami.yaml"
remote_fixture=/tmp/r68-centos-storage-e2e-whoami.yaml
[[ -r $fixture ]] || { echo "fixture not found: $fixture" >&2; exit 1; }
script_sha256=$(sha256sum "${BASH_SOURCE[0]}" | awk '{print $1}')
fixture_sha256=$(sha256sum "$fixture" | awk '{print $1}')
started_utc=$(date -u +%FT%TZ)
run_id=$(date -u +%Y%m%d%H%M%S)
instance_id=
cleanup() {
  local rc=$?
  trap - EXIT
  if [[ $instance_id =~ ^inst_[A-Za-z0-9]+$ ]]; then
    if ! ssh "${hub_args[@]}" "$hub" \
      "sudo -u validator env HOME=/home/validator admiralctl instances deprovision '$instance_id' --force --wait --wait-timeout 10m --output json" \
      >"$output_dir/deprovision.json" 2>&1; then
      echo "cleanup deprovision failed for $instance_id" >&2
      rc=1
    fi
    if ! ssh "${w2_args[@]}" "$worker" sudo bash -s -- "$instance_id" \
      >"$output_dir/runtime-cleanup.txt" 2>&1 <<'REMOTE'
set -euo pipefail
instance_id=$1
uid=$(id -u admiral-apps)
podman_as_apps() { runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" podman "$@"; }
containers=$(podman_as_apps ps -a --filter "name=$instance_id" --format '{{.Names}}')
pods=$(podman_as_apps pod ps --format '{{.Name}}' | grep -F "$instance_id" || true)
volumes=$(podman_as_apps volume ls --format '{{.Name}}' | grep -F "$instance_id" || true)
units=$(runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" systemctl --user list-unit-files --no-legend | grep -F "$instance_id" || true)
files=$(find /etc/containers/systemd /var/lib/admiral -iname "*$instance_id*" -print 2>/dev/null || true)
printf 'remaining_containers=%s\nremaining_pods=%s\nremaining_volumes=%s\nremaining_units=%s\nremaining_files=%s\n' \
  "${containers:-none}" "${pods:-none}" "${volumes:-none}" "${units:-none}" "${files:-none}"
[[ -z $containers && -z $pods && -z $volumes && -z $units && -z $files ]]
REMOTE
    then
      echo "cleanup verification failed for $instance_id" >&2
      rc=1
    fi
  fi
  if ! ssh "${hub_args[@]}" "$hub" "rm -f -- '$remote_fixture'" >"$output_dir/fixture-cleanup.txt" 2>&1; then
    echo 'fixture cleanup failed' >&2
    rc=1
  fi
  printf 'exit_code=%s\nfinished_utc=%s\n' "$rc" "$(date -u +%FT%TZ)" >"$output_dir/exit-status.txt"
  find "$output_dir" -maxdepth 1 -type f ! -name SHA256SUMS -exec chmod 0600 {} +
  (cd "$output_dir" && find . -maxdepth 1 -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum >SHA256SUMS)
  chmod 0600 "$output_dir/SHA256SUMS"
  exit "$rc"
}
trap cleanup EXIT

printf 'test_id=R68-CENTOS-MN-STORAGE-01\nos=CentOS Stream 10\narchitecture=x86_64\ncandidate=0.0.1rc5-68.el10\nroot_package_source_commit=4077c4ddb9d233682961d36c3570c63e70eb6405\nscript_sha256=%s\nfixture_sha256=%s\nstarted_utc=%s\nhub=adm-r68-centos-mn-hub@%s\nw2=adm-r68-centos-mn-w2@%s\n' \
  "$script_sha256" "$fixture_sha256" "$started_utc" "$hub_ip" "$w2_ip" >"$output_dir/metadata.txt"

ssh "${hub_args[@]}" "$hub" 'source /etc/os-release; printf "OS_ID=%s OS_VERSION=%s ARCH=%s SELINUX=%s\\n" "$ID" "$VERSION_ID" "$(uname -m)" "$(getenforce)"; rpm -q --qf "%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\\n" admiral-common admirald admiral-fleet admiralctl admiral-flagship admiral-harbor | sort' \
  >"$output_dir/hub-baseline.txt"
ssh "${w2_args[@]}" "$worker" 'source /etc/os-release; printf "OS_ID=%s OS_VERSION=%s ARCH=%s SELINUX=%s\\n" "$ID" "$VERSION_ID" "$(uname -m)" "$(getenforce)"; rpm -q --qf "%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\\n" admiral-common admiral-fleet | sort' \
  >"$output_dir/w2-baseline.txt"
python3 - "$output_dir/hub-baseline.txt" "$output_dir/w2-baseline.txt" <<'PY'
import sys
for path,expected_count in ((sys.argv[1],6),(sys.argv[2],2)):
    text=open(path,encoding='utf-8').read()
    if 'OS_ID=centos OS_VERSION=10 ARCH=x86_64 SELINUX=Enforcing' not in text:
        raise SystemExit(f'CentOS Stream 10 x86_64/Enforcing precondition failed in {path}')
    count=text.count('-0.0.1rc5-68.el10.')
    if count!=expected_count: raise SystemExit(f'exact R68 EL10 package count mismatch in {path}: {count}')
    print(f'host_precondition=PASS packages={count} evidence={path}')
PY

scp "${hub_args[@]}" "$fixture" "$hub:$remote_fixture"
ssh "${hub_args[@]}" "$hub" \
  'sudo -u validator env HOME=/home/validator admiralctl apps apply --file /tmp/r68-centos-storage-e2e-whoami.yaml' \
  >"$output_dir/app-apply.log" 2>&1
ssh "${hub_args[@]}" "$hub" \
  'sudo -u validator env HOME=/home/validator admiralctl nodes list --output json' >"$output_dir/nodes-before.json"
python3 - "$output_dir/nodes-before.json" <<'PY'
import json,sys
nodes=json.load(open(sys.argv[1],encoding='utf-8'))
node=next((n for n in nodes if n.get('id')=='adm-r68-centos-mn-w2'),None)
if not node or node.get('status')!='active' or node.get('health_status')!='healthy' or not node.get('available_for_provisioning'):
    raise SystemExit('W2 is not active/healthy/available')
print(f"w2_precondition=PASS node={node['id']}")
PY

customer="r68-centos-storage-$run_id"
key="r68-centos-storage-$run_id"
provision_rc=0
ssh "${hub_args[@]}" "$hub" \
  "sudo -u validator env HOME=/home/validator admiralctl instances provision --app e2e-whoami --tier small --customer '$customer' --idempotency-key '$key' --node adm-r68-centos-mn-w2 --wait --wait-timeout 10m --quiet --output json" \
  >"$output_dir/provision.json" || provision_rc=$?
instance_id=$(python3 - "$output_dir/provision.json" <<'PY'
import json,sys
try: print(json.load(open(sys.argv[1],encoding='utf-8')).get('instance_id',''))
except (OSError,ValueError): print('')
PY
)
[[ $instance_id =~ ^inst_[A-Za-z0-9]+$ ]] || { echo 'provision returned no valid instance ID' >&2; exit 1; }
if [[ $provision_rc -ne 0 ]]; then echo "provision command exited $provision_rc" >&2; exit "$provision_rc"; fi
python3 - "$output_dir/provision.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print(f"operation={x.get('id')} instance={x.get('instance_id')} node={x.get('node_id')} status={x.get('status')} created={x.get('created_at')} terminal={x.get('updated_at')}")
if x.get('status')!='succeeded' or x.get('node_id')!='adm-r68-centos-mn-w2': raise SystemExit('provision failed or wrong placement')
PY

ssh "${w2_args[@]}" "$worker" sudo bash -s -- "$instance_id" <<'REMOTE' >"$output_dir/worker-tier-file-initial.txt"
set -euo pipefail
instance_id=$1
path="/var/lib/admiral/instances/$instance_id/tier.json"
if [[ -f $path ]]; then stat -c 'path=%n mode=%a owner=%U:%G size=%s' "$path"; cat "$path"; else echo "tier_json=MISSING path=$path"; fi
pid=$(systemctl show admiral-fleet -p MainPID --value)
if [[ $pid =~ ^[1-9][0-9]*$ && -r /proc/$pid/environ ]]; then
  tr '\0' '\n' <"/proc/$pid/environ" | grep '^ADMIRAL_FLEET_STORAGE_CHECK_INTERVAL=' || echo 'storage_check_interval=default-60s'
else echo 'storage_check_interval=process-env-unavailable'; fi
REMOTE

for sample in $(seq 1 18); do
  stamp=$(date -u +%FT%TZ)
  sample_file="$output_dir/sample-$(printf '%02d' "$sample").json"
  ssh "${hub_args[@]}" "$hub" \
    "sudo -u validator env HOME=/home/validator admiralctl instances show '$instance_id'" \
    >"$sample_file" 2>"$output_dir/sample-$(printf '%02d' "$sample").error.log"
  python3 - "$sample_file" "$stamp" "$sample" >>"$output_dir/samples.tsv" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
fields=(sys.argv[2],sys.argv[3],x.get('technical_status'),x.get('health_status'),x.get('effective_availability'),x.get('storage_limit_bytes'),x.get('storage_state'),x.get('storage_message'),x.get('storage_checked_at'),x.get('last_health_checked_at'))
print('\t'.join('' if v is None else str(v) for v in fields))
PY
  sleep 5
done

ssh "${w2_args[@]}" "$worker" sudo bash -s -- "$instance_id" <<'REMOTE' >"$output_dir/worker-tier-file-final.txt"
set -euo pipefail
instance_id=$1
path="/var/lib/admiral/instances/$instance_id/tier.json"
if [[ -f $path ]]; then stat -c 'path=%n mode=%a owner=%U:%G size=%s' "$path"; cat "$path"; else echo "tier_json=MISSING path=$path"; fi
REMOTE

python3 - "$output_dir/samples.tsv" <<'PY'
import csv,sys
rows=list(csv.reader(open(sys.argv[1],encoding='utf-8'),delimiter='\t'))
if not rows: raise SystemExit('no storage samples were captured')
for row in rows: print('\t'.join(row))
last=rows[-1]
if last[5]!='1073741824' or last[6]!='ok':
    raise SystemExit(f'expected storage limit/state 1073741824/ok by the end of observation; got {last[5]}/{last[6]}')
if last[2]!='running' or last[3]!='healthy' or last[4]!='available':
    raise SystemExit(f'workload did not remain healthy/available: {last[2:5]}')
print(f'storage_limit_converged=PASS samples={len(rows)} final_checked_at={last[8]}')
PY

python3 - "$output_dir/worker-tier-file-final.txt" <<'PY'
import json,sys
lines=open(sys.argv[1],encoding='utf-8').read().splitlines()
if len(lines)<2 or not lines[0].startswith('path='):
    raise SystemExit('worker tier.json was missing at end of observation')
metadata=json.loads(lines[1])
if metadata.get('storage')!='1G': raise SystemExit(f'unexpected tier.json content: {metadata}')
print(f"worker_tier_file=PASS mode_owner={lines[0]} storage={metadata['storage']}")
PY

ssh "${hub_args[@]}" "$hub" \
  'sudo -u validator env HOME=/home/validator admiralctl nodes list --output json' >"$output_dir/nodes-after.json"
printf 'result=PASS_SCOPED\nfinished_utc=%s\n' "$(date -u +%FT%TZ)" >"$output_dir/result.txt"
echo 'R68-CENTOS-MN-STORAGE-01=PASS_SCOPED'
