#!/usr/bin/env bash
set -euo pipefail
root=/var/lib/libvirt/images/admiral-validation
key=$root/keys/rc5-r73-validator.ed25519
base=$root/cloud-init
out=${1:?evidence dir required}
mkdir -m 0700 -p "$out"
for spec in 'hub 10.77.0.23' 'w1 10.77.0.24' 'w2 10.77.0.25'; do
  read -r role ip <<<"$spec"
  kh=$base/adm-r73-alma-mn-$role/known_hosts
  ssh -i "$key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$kh" "validator@$ip" sudo bash -s -- "$role" >"$out/$role.txt" <<'REMOTE'
set -euo pipefail
role=$1
printf 'checked_utc=%s\n' "$(date -u +%FT%TZ)"
. /etc/os-release
printf 'os=%s %s\narch=%s\n' "$NAME" "$VERSION_ID" "$(uname -m)"
if [[ $role == hub ]]; then
  rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' admiral-common admirald admiral-fleet admiralctl admiral-flagship admiral-harbor | sort
else
  rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' admiral-common admiral-fleet | sort
fi
printf 'selinux=%s\n' "$(getenforce)"
printf 'firewalld=%s fail2ban=%s\n' "$(systemctl is-active firewalld)" "$(systemctl is-active fail2ban)"
printf 'failed_units=%s\n' "$(systemctl --failed --no-legend | wc -l)"
if ip link show wg-admiral >/dev/null 2>&1; then
  now=$(date +%s)
  wg show wg-admiral latest-handshakes | awk -v now="$now" 'BEGIN{n=0;fresh=0} {n++; if ($2>now-120) fresh++} END{printf "wireguard_peer_count=%d\nfresh_handshake_count=%d\n",n,fresh}'
else
  echo 'wireguard_interface=missing'; exit 1
fi
if [[ $role == hub ]]; then
  for unit in postgresql admirald caddy admiral-flagship admiral-harbor; do
    printf '%s=%s\n' "$unit" "$(systemctl is-active "$unit" 2>/dev/null || true)"
  done
else
  printf 'admiral-fleet=%s\n' "$(systemctl is-active admiral-fleet)"
fi
if [[ $role != hub ]]; then
  uid=$(id -u admiral-apps)
  app_home=$(getent passwd admiral-apps | cut -d: -f6)
  subuid=$(awk -F: '$1=="admiral-apps" {print $2 ":" $3}' /etc/subuid)
  subgid=$(awk -F: '$1=="admiral-apps" {print $2 ":" $3}' /etc/subgid)
  printf 'subuid=%s\nsubgid=%s\n' "$subuid" "$subgid"
  [[ -n $subuid && -n $subgid ]]
  rootless=$(runuser -u admiral-apps -- env HOME="$app_home" XDG_RUNTIME_DIR="/run/user/$uid" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" podman info --format '{{.Host.Security.Rootless}}')
  printf 'podman_rootless=%s\n' "$rootless"
  [[ $rootless == true ]]
  runuser -u admiral-apps -- env HOME="$app_home" XDG_RUNTIME_DIR="/run/user/$uid" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" podman ps -a --format 'podman_workload={{.Names}} status={{.Status}}'
fi
REMOTE
  chmod 0600 "$out/$role.txt"
done
ssh -i "$key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$base/adm-r73-alma-mn-hub/known_hosts" validator@10.77.0.23 \
  'sudo -u validator env HOME=/home/validator admiralctl nodes list --output json' >"$out/nodes.json"
chmod 0600 "$out/nodes.json"
python3 - "$out" <<'PY'
import json, pathlib, sys
p=pathlib.Path(sys.argv[1]); nodes=json.loads((p/'nodes.json').read_text())
for n in nodes:
    print('node={id} status={status} health={health_status} provisionable={available_for_provisioning}'.format(**n))
print('node_count={}'.format(len(nodes)))
PY
(cd "$out" && sha256sum hub.txt w1.txt w2.txt nodes.json > SHA256SUMS)
chmod 0600 "$out/SHA256SUMS"
printf 'evidence_dir=%s\n' "$out"
