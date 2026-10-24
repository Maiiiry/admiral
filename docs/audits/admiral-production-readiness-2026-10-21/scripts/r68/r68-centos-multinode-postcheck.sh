#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Verify native Release 68 package installation and a clean three-node baseline.
set -euo pipefail

[[ $# -eq 11 ]] || {
  echo "usage: $0 SSH_KEY HUB_KNOWN_HOSTS W1_KNOWN_HOSTS W2_KNOWN_HOSTS HUB_IP W1_IP W2_IP HUB_NODE_ID W1_NODE_ID W2_NODE_ID OUTPUT_LOG" >&2
  exit 2
}
ssh_key=$1 hub_known_hosts=$2 w1_known_hosts=$3 w2_known_hosts=$4
hub_ip=$5 w1_ip=$6 w2_ip=$7 hub_node_id=$8 w1_node_id=$9 w2_node_id=${10} output=${11}
for node_id in "$hub_node_id" "$w1_node_id" "$w2_node_id"; do
  [[ $node_id =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,62}$ ]] || { echo "invalid node ID: $node_id" >&2; exit 2; }
done
for ip in "$hub_ip" "$w1_ip" "$w2_ip"; do
  [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "invalid IPv4: $ip" >&2; exit 2; }
done
for path in "$ssh_key" "$hub_known_hosts" "$w1_known_hosts" "$w2_known_hosts"; do
  [[ -r $path ]] || { echo "unreadable SSH input: $path" >&2; exit 1; }
done
[[ $output == /* ]] || { echo 'output path must be absolute' >&2; exit 2; }
mkdir -p "$(dirname "$output")"
umask 077
(set -o noclobber; : >"$output") || { echo "refusing to overwrite $output" >&2; exit 1; }
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT
ssh_args=(-i "$ssh_key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes)

check_host() {
  local role=$1 node_id=$2 ip=$3 known_hosts=$4 expected_handshakes=$5
  echo "host_check_begin role=$role node_id=$node_id started=$(date -u +%FT%TZ)" | tee -a "$output"
  ssh "${ssh_args[@]}" -o "UserKnownHostsFile=$known_hosts" "validator@$ip" \
    "sudo bash -s -- '$role' '$node_id' 68 '$expected_handshakes'" <<'REMOTE' | tee -a "$output"
set -euo pipefail
role=$1 expected_node_id=$2 release=$3 expected_handshakes=$4
source /etc/os-release
printf 'host=%s os=%s version=%s arch=%s\n' "$(hostname -s)" "$ID" "$VERSION_ID" "$(uname -m)"
[[ $(uname -m) == x86_64 ]] || { echo 'unexpected architecture' >&2; exit 1; }
[[ $(getenforce) == Enforcing ]] || { echo 'SELinux is not Enforcing' >&2; exit 1; }
forwarding=$(sysctl -n net.ipv4.ip_forward)
printf 'selinux=%s wireguard_forwarding_v4=%s\n' "$(getenforce)" "$forwarding"
[[ $forwarding == 0 ]] || { echo 'inter-node forwarding unexpectedly enabled' >&2; exit 1; }
firewall_state=$(firewall-cmd --state)
printf 'firewalld=%s\n' "$firewall_state"
[[ $firewall_state == running ]] || exit 1
check_package() {
  local package=$1 expected_arch=$2 actual expected
  actual=$(rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}' "$package")
  expected="$package-0.0.1rc5-${release}.el10.${expected_arch}"
  [[ $actual == "$expected" ]] || { echo "unexpected package: $actual expected=$expected" >&2; exit 1; }
  printf 'package=%s\n' "$actual"
}
check_package admiral-common noarch
if [[ $role == hub ]]; then
  check_package admirald x86_64
  check_package admiralctl x86_64
  check_package admiral-fleet x86_64
  check_package admiral-harbor noarch
  check_package admiral-flagship noarch
  for package in python3-alembic python3-flask-alembic python3-flask-login python3-flask-sqlalchemy python3-flask python3-mistune python3-typing-extensions; do
    rpm -q --qf 'dependency=%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' "$package"
  done
  services='postgresql admirald caddy admiral-harbor admiral-flagship'
else
  check_package admiral-fleet x86_64
  services='admiral-fleet'
fi
for service in $services; do
  state=$(systemctl is-active "$service")
  printf 'service=%s state=%s\n' "$service" "$state"
  [[ $state == active ]] || exit 1
done
failed=$(systemctl --failed --no-legend --no-pager)
printf 'failed_units=%s\n' "${failed:-none}"
[[ -z $failed ]] || exit 1
fedora_packages=$(rpm -qa --qf '%{NAME}-%{RELEASE}\n' | grep -Ec '\.fc[0-9]+' || true)
printf 'fedora_tagged_packages=%s\n' "$fedora_packages"
[[ $fedora_packages == 0 ]] || { echo 'Fedora-tagged package found on EL10 guest' >&2; exit 1; }
handshakes=$(wg show wg-admiral latest-handshakes | awk '$2+0>0 {n++} END {print n+0}')
printf 'fresh_wireguard_handshakes=%s expected=%s\n' "$handshakes" "$expected_handshakes"
[[ $handshakes == "$expected_handshakes" ]] || exit 1
if [[ $role == worker ]]; then
  cd /tmp
  app_uid=$(id -u admiral-apps)
  app_home=$(getent passwd admiral-apps | cut -d: -f6)
  app_env=(env HOME="$app_home" XDG_RUNTIME_DIR="/run/user/$app_uid" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$app_uid/bus")
  containers=$(runuser -u admiral-apps -- "${app_env[@]}" podman ps -aq)
  pods=$(runuser -u admiral-apps -- "${app_env[@]}" podman pod ps -q)
  volumes=$(runuser -u admiral-apps -- "${app_env[@]}" podman volume ls -q)
  printf 'rootless_containers=%s rootless_pods=%s rootless_volumes=%s\n' "${containers:-none}" "${pods:-none}" "${volumes:-none}"
  [[ -z $containers && -z $pods && -z $volumes ]] || exit 1
fi
printf 'host_check=PASS node_id=%s end=%s\n' "$expected_node_id" "$(date -u +%FT%TZ)"
REMOTE
}

check_host hub "$hub_node_id-portal" "$hub_ip" "$hub_known_hosts" 2
check_host worker "$w1_node_id" "$w1_ip" "$w1_known_hosts" 1
check_host worker "$w2_node_id" "$w2_ip" "$w2_known_hosts" 1

ssh "${ssh_args[@]}" -o "UserKnownHostsFile=$hub_known_hosts" "validator@$hub_ip" \
  'sudo -u validator env HOME=/home/validator admiralctl nodes list --output json' >"$tmp_dir/nodes.json"
python3 - "$tmp_dir/nodes.json" "$hub_node_id-portal" "$w1_node_id" "$w2_node_id" <<'PY' | tee -a "$output"
import json,sys
nodes=json.load(open(sys.argv[1],encoding='utf-8'))
expected=set(sys.argv[2:])
healthy={n['id'] for n in nodes if n.get('status')=='active' and n.get('health_status')=='healthy' and n.get('available_for_provisioning')}
for node in sorted(nodes,key=lambda x:x.get('id','')):
    print(f"node={node.get('id')} status={node.get('status')} health={node.get('health_status')} available={node.get('available_for_provisioning')}")
missing=expected-healthy
if missing:
    raise SystemExit(f'active healthy available nodes missing: {sorted(missing)}')
print(f'expected_active_healthy_available_nodes={len(expected)}')
PY
printf 'topology_postcheck=PASS end=%s\n' "$(date -u +%FT%TZ)" | tee -a "$output"
chmod 0600 "$output"
