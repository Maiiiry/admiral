#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Serve one local x86_64 EL10 candidate through the private libvirt network.
set -euo pipefail

[[ $# -eq 1 && $1 =~ ^[0-9]+$ ]] || { echo "usage: $0 RPM_RELEASE" >&2; exit 2; }
[[ $EUID -eq 0 ]] || { echo "run as root" >&2; exit 1; }
release=$1
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)
source_repo="$project_root/packaging/build/repos/el10-rc5-r${release}-x86_64"
validation_dir="$project_root/packaging/build/validation/rc5-r${release}"
repo_root=${ADMIRAL_VALIDATION_REPO_ROOT:-/var/lib/libvirt/images/admiral-validation/repo}
destination="$repo_root/rc5-r${release}/el10/x86_64"

[[ -d $source_repo ]] || { echo "local RPM repo not found: $source_repo" >&2; exit 1; }
[[ ! -e $destination ]] || { echo "candidate destination already exists: $destination" >&2; exit 1; }
command -v createrepo_c >/dev/null || { echo "createrepo_c is required" >&2; exit 1; }
shopt -s nullglob
rpms=("$source_repo"/*.rpm)
[[ ${#rpms[@]} -ge 14 ]] || { echo "candidate repo is incomplete: found ${#rpms[@]} RPMs" >&2; exit 1; }

mkdir -p "$destination" "$validation_dir"
for rpm in "${rpms[@]}"; do
    install -m 0644 "$rpm" "$destination/"
done
createrepo_c --checksum sha256 "$destination" >/dev/null
(cd "$destination" && sha256sum ./*.rpm > "$validation_dir/el10-RPM-SHA256SUMS")

printf '[admiral-local]\nname=Admiral RC5 Release %s local validation (EL10 x86_64)\nbaseurl=http://192.168.122.1/rc5-r%s/el10/$basearch\nenabled=1\ngpgcheck=0\npriority=1\nskip_if_unavailable=0\n' \
    "$release" "$release" > "$validation_dir/admiral-local-el10.repo"
chmod 0644 "$validation_dir/admiral-local-el10.repo"

echo "Published candidate repo on the private libvirt HTTP server: $destination"
echo "Repo config: $validation_dir/admiral-local-el10.repo"
find "$destination" -maxdepth 1 -type f -name '*.rpm' -printf '%f\n' | sort
