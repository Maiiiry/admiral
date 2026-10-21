#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Install the exact local Release 42 RPM set and required EL10 repositories.
set -euo pipefail
[[ $# -eq 3 ]] || { echo "usage: $0 SSH_KEY KNOWN_HOSTS USER@GUEST" >&2; exit 2; }
ssh_key=$1 known_hosts=$2 target=$3
repo_file=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)/packaging/build/validation/rc5-r42/admiral-local-el10.repo
[[ -r $repo_file && -r $ssh_key && -r $known_hosts ]] || { echo "candidate repo or SSH input is unavailable" >&2; exit 1; }
ssh_args=(-i "$ssh_key" -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$known_hosts")
scp "${ssh_args[@]}" "$repo_file" "$target:/tmp/admiral-local.repo"
ssh "${ssh_args[@]}" "$target" sudo bash -s <<'REMOTE'
set -euo pipefail
install -o root -g root -m 0644 /tmp/admiral-local.repo /etc/yum.repos.d/admiral-local.repo
dnf install -y dnf-plugins-core
dnf install -y epel-release
dnf config-manager --set-enabled crb
dnf copr enable -y admiral-project/admiral
dnf clean all
dnf install -y admiral-common admirald admiralctl admiral-fleet admiral-harbor admiral-flagship
rpm -q admiral-common admirald admiralctl admiral-fleet admiral-harbor admiral-flagship
REMOTE
