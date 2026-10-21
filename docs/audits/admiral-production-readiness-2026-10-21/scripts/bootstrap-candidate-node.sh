#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Install the exact local Release 43 RPM set and required EL10 repositories.
set -euo pipefail
[[ $# -eq 4 ]] || { echo "usage: $0 {el10|fedora} SSH_KEY KNOWN_HOSTS USER@GUEST" >&2; exit 2; }
distro=$1 ssh_key=$2 known_hosts=$3 target=$4
case "$distro" in
  el10) repo_name=admiral-local-el10.repo ;;
  fedora) repo_name=admiral-local-fedora.repo ;;
  *) echo "unsupported distribution profile: $distro" >&2; exit 2 ;;
esac
repo_file=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)/packaging/build/validation/rc5-r43/$repo_name
[[ -r $repo_file && -r $ssh_key && -r $known_hosts ]] || { echo "candidate repo or SSH input is unavailable" >&2; exit 1; }
ssh_args=(-i "$ssh_key" -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$known_hosts")
scp "${ssh_args[@]}" "$repo_file" "$target:/tmp/admiral-local.repo"
ssh "${ssh_args[@]}" "$target" sudo bash -s -- "$distro" <<'REMOTE'
set -euo pipefail
distribution=$1
install -o root -g root -m 0644 /tmp/admiral-local.repo /etc/yum.repos.d/admiral-local.repo
dnf install -y dnf-plugins-core
if [[ $distribution == el10 ]]; then
    dnf install -y epel-release
    dnf config-manager --set-enabled crb
fi
dnf copr enable -y admiral-project/admiral
dnf clean all
dnf install -y admiral-common admirald admiralctl admiral-fleet admiral-harbor admiral-flagship
for package in admiral-common admirald admiralctl admiral-fleet admiral-harbor admiral-flagship; do
    rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' "$package" | grep -Fx "$package-0.0.1rc5-43.el10.$(rpm -q --qf '%{ARCH}' "$package")"
done
rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' python3-mistune | grep -Fx 'python3-mistune-3.4.0-1.el10.noarch'
REMOTE
