#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Verify the fresh Release 70 Rocky single-node baseline.
set -euo pipefail

[[ $# -eq 5 ]] || {
  echo "usage: $0 SSH_KEY KNOWN_HOSTS GUEST_IP EXPECTED_OS OUTPUT_LOG" >&2
  exit 2
}
ssh_key=$1 known_hosts=$2 guest_ip=$3 expected_os=$4 output=$5
[[ $guest_ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo 'invalid guest IPv4' >&2; exit 2; }
[[ $expected_os == rocky ]] || { echo 'expected OS must be rocky' >&2; exit 2; }
[[ $output == /* ]] || { echo 'output path must be absolute' >&2; exit 2; }
for path in "$ssh_key" "$known_hosts"; do
  [[ -r $path ]] || { echo "unreadable SSH input: $path" >&2; exit 1; }
done
mkdir -p "$(dirname "$output")"
umask 077
(set -o noclobber; : >"$output") || { echo "refusing to overwrite $output" >&2; exit 1; }
chmod 0600 "$output"

ssh_args=(-i "$ssh_key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$known_hosts")
guest="validator@$guest_ip"
ssh "${ssh_args[@]}" "$guest" "sudo bash -s -- $expected_os" <<'REMOTE' | tee -a "$output"
set -euo pipefail
cd /
expected_os=$1
source /etc/os-release
printf 'guest=%s os=%s version=%s arch=%s boot_id=%s\n' "$(hostname -s)" "$ID" "$VERSION_ID" "$(uname -m)" "$(cat /proc/sys/kernel/random/boot_id)"
[[ $ID == "$expected_os" ]]
[[ $(uname -m) == x86_64 ]]
[[ $(getenforce) == Enforcing ]]
printf 'selinux=%s\n' "$(getenforce)"

packages=(admiral-common admirald admiral-fleet admiralctl admiral-harbor admiral-flagship)
rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' "${packages[@]}"
for package in "${packages[@]}"; do
  rpm -q --qf '%{VERSION}-%{RELEASE}\n' "$package" | grep -qx '0.0.1rc5-70.el10'
done

# Setup intentionally renders these four package-owned configuration files.
# Treat only these content/metadata differences as expected and retain the
# complete rpm verification output in the validation log.
verify_output=$(mktemp)
trap 'rm -f -- "$verify_output"' EXIT
set +e
rpm -V "${packages[@]}" >"$verify_output" 2>&1
rpm_verify_rc=$?
set -e
printf 'rpm_verify_exit=%s (generated configuration differences are expected)\n' "$rpm_verify_rc"
cat "$verify_output"
python3 - "$verify_output" <<'PY'
import pathlib,sys
expected={
    '/etc/admirald.ini',
    '/etc/admiral/fleet.env',
    '/etc/admiral/harbor.env',
    '/etc/admiral/flagship.env',
}
lines=[line.rstrip() for line in pathlib.Path(sys.argv[1]).read_text().splitlines() if line.strip()]
seen=set()
for line in lines:
    path=line.split()[-1]
    if path not in expected:
        raise SystemExit(f'unexpected RPM verification discrepancy: {line}')
    if path in seen:
        raise SystemExit(f'duplicate RPM verification discrepancy: {path}')
    seen.add(path)
if seen != expected:
    raise SystemExit(f'expected generated config differences {sorted(expected)}, observed {sorted(seen)}')
print('rpm_verify_scope=PASS only four setup-rendered configuration files differ')
PY

for spec in \
  '600 root:root /etc/admirald.ini' \
  '600 root:admiral /etc/admiral/fleet.env' \
  '600 root:admiral /etc/admiral/harbor.env' \
  '600 root:admiral /etc/admiral/flagship.env' \
  '750 root:admiral /etc/admiral' \
  '751 admiral:admiral /var/lib/admiral'; do
  read -r mode owner_group path <<<"$spec"
  actual=$(stat -c '%a %U:%G %n' "$path")
  printf 'ownership_mode=%s\n' "$actual"
  [[ $actual == "$spec" ]]
done
for path in /etc/admirald.ini /etc/admiral/fleet.env /etc/admiral/harbor.env /etc/admiral/flagship.env; do
  printf 'file_selinux_context=%s\n' "$(ls -Zd "$path")"
done

failed=$(systemctl --failed --no-legend --no-pager)
printf 'failed_units=%s\n' "${failed:-none}"
[[ -z $failed ]]
for service in postgresql admirald admiral-fleet caddy admiral-harbor admiral-flagship; do
  state=$(systemctl is-active "$service")
  printf 'service=%s state=%s\n' "$service" "$state"
  [[ $state == active ]]
done

for endpoint in https://127.0.0.1:5001/ready https://127.0.0.1:5000/flagship/api/health; do
  code=$(curl --insecure --connect-timeout 3 --max-time 10 --silent --show-error -o /dev/null -w '%{http_code}' "$endpoint")
  printf 'local_health_endpoint=%s http=%s\n' "$endpoint" "$code"
  [[ $code == 200 ]]
done
admiralctl status

nodes_file=$(mktemp)
trap 'rm -f -- "$verify_output" "$nodes_file"' EXIT
admiralctl nodes list --output json >"$nodes_file"
python3 - "$nodes_file" <<'PY'
import json,sys
nodes=json.load(open(sys.argv[1],encoding='utf-8'))
for n in nodes:
    print('node={id} role={role} status={status} health={health} available={available}'.format(
        id=n.get('id'), role=n.get('node_role'), status=n.get('status'),
        health=n.get('health_status'), available=n.get('available_for_provisioning')))
workers=[n for n in nodes if n.get('node_role')=='worker']
portals=[n for n in nodes if n.get('node_role')=='portal']
if len(workers)!=1 or len(portals)!=1:
    raise SystemExit(f'expected exactly one worker and one portal; got {len(workers)} and {len(portals)}')
for node in workers+portals:
    if node.get('status')!='active' or node.get('health_status')!='healthy':
        raise SystemExit(f'node not active and healthy: {node.get("id")}')
if not workers[0].get('available_for_provisioning'):
    raise SystemExit('worker is not available for provisioning')
print('single_node_registration=PASS')
PY

uid=$(id -u admiral-apps)
home=$(getent passwd admiral-apps | cut -d: -f6)
app_env=(env HOME="$home" XDG_RUNTIME_DIR="/run/user/$uid" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus")
rootless=$(runuser -u admiral-apps -- "${app_env[@]}" podman info --format '{{.Host.Security.Rootless}}')
printf 'podman_rootless=%s\n' "$rootless"
[[ $rootless == true ]]
containers=$(runuser -u admiral-apps -- "${app_env[@]}" podman ps -a --format '{{.ID}}')
pods=$(runuser -u admiral-apps -- "${app_env[@]}" podman pod ps --format '{{.ID}}')
volumes=$(runuser -u admiral-apps -- "${app_env[@]}" podman volume ls --format '{{.Name}}')
printf 'initial_rootless_containers=%s pods=%s volumes=%s\n' "${containers:-none}" "${pods:-none}" "${volumes:-none}"
[[ -z $containers && -z $pods && -z $volumes ]]

printf 'single_node_postcheck=PASS end_utc=%s\n' "$(date -u +%FT%TZ)"
REMOTE
status=${PIPESTATUS[0]}
chmod 0600 "$output"
exit "$status"
