#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Capture non-secret package, service, listener, SELinux and rootless Podman state.
set -euo pipefail
[[ $# -eq 4 ]] || { echo "usage: $0 SSH_KEY KNOWN_HOSTS USER@HOST OUTPUT_FILE" >&2; exit 2; }
ssh_key=$1 known_hosts=$2 target=$3 output=$4
umask 077
ssh -i "$ssh_key" -o BatchMode=yes -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="$known_hosts" "$target" \
  'sudo -n bash -s' <<'REMOTE' >"$output"
set -euo pipefail
date -u +timestamp_utc=%Y-%m-%dT%H:%M:%SZ
cat /etc/os-release
uname -r
getenforce
rpm -q admiral-common admirald admiral-fleet admiralctl admiral-flagship admiral-harbor 2>&1 || true
systemctl --no-pager --plain list-units 'admiral*' 'postgresql*' 'caddy*' | sed -n '1,100p'
ss -lntup
firewall-cmd --get-active-zones 2>&1 || true
firewall-cmd --list-all 2>&1 || true
id admiral-apps 2>&1 || true
loginctl show-user admiral-apps -p Linger -p State 2>&1 || true
if id admiral-apps >/dev/null 2>&1; then
  apps_uid=$(id -u admiral-apps)
  runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$apps_uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$apps_uid/bus" \
    podman info --format '{{.Host.Security.Rootless}}' 2>&1 || true
  runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$apps_uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$apps_uid/bus" \
    podman ps -a --format '{{.ID}} {{.Names}} {{.Status}}' 2>&1 || true
fi
find /etc/containers/systemd -maxdepth 4 -type f -printf '%m %u:%g %p\n' 2>&1 | sort
find /var/lib/admiral -maxdepth 3 -type d -printf '%m %u:%g %p\n' 2>&1 | sort || true
REMOTE
chmod 0600 "$output"
