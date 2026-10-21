#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Install the exact local RC candidate and run the supported secure installer.
set -euo pipefail
[[ $# -eq 6 ]] || {
  echo "usage: $0 SSH_KEY KNOWN_HOSTS USER@GUEST NODE_IP NODE_ID OUTPUT_LOG" >&2
  exit 2
}
ssh_key=$1 known_hosts=$2 target=$3 node_ip=$4 node_id=$5 output=$6
[[ $node_id =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,62}$ ]] || { echo "invalid node id" >&2; exit 2; }
[[ $node_ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "invalid guest IPv4" >&2; exit 2; }
repo_file=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)/packaging/build/validation/rc5-r42/admiral-local-el10.repo
[[ -r $repo_file ]] || { echo "local candidate repository config not found: $repo_file" >&2; exit 1; }
[[ -r $ssh_key && -r $known_hosts ]] || { echo "SSH identity or known-hosts file not readable" >&2; exit 1; }
mkdir -p "$(dirname "$output")"
umask 077
ssh_args=(-i "$ssh_key" -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$known_hosts")
{
  printf 'audit_start_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  scp "${ssh_args[@]}" "$repo_file" "$target:/tmp/admiral-local.repo"
  ssh "${ssh_args[@]}" "$target" sudo install -o root -g root -m 0644 \
    /tmp/admiral-local.repo /etc/yum.repos.d/admiral-local.repo
  ssh "${ssh_args[@]}" "$target" sudo bash -s <<'REMOTE'
set -euo pipefail
dnf install -y dnf-plugins-core
dnf install -y epel-release
dnf config-manager --set-enabled crb
dnf copr enable -y admiral-project/admiral
dnf clean all
dnf install -y admiral-common admirald admiralctl admiral-fleet admiral-harbor admiral-flagship
REMOTE
  ssh "${ssh_args[@]}" "$target" sudo admiral-install --single-node \
    --public-ip "$node_ip" --ssh-public-key /home/validator/validator.pub \
    --node-id "$node_id"
  printf 'audit_end_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} 2>&1 | tee "$output"
chmod 0600 "$output"
