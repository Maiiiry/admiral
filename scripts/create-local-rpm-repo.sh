#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
rpm_dir="$root_dir/packaging/build/RPMS"
repo_dir="$root_dir/packaging/build/repos/el10-rc5-r58-x86_64"
repo_parent=$(dirname "$repo_dir")
mkdir -p "$repo_parent"
stage_dir=$(mktemp -d "$repo_parent/.local-rpm-repo.XXXXXX")

specs=(
    admiral-common admirald admiral-fleet admiralctl admiral-flagship admiral-harbor
    python-alembic python-flask python-flask-alembic python-flask-login
    python-flask-sqlalchemy python-mistune python-sqlalchemy python-typing-extensions
)

command -v createrepo_c >/dev/null || { echo "createrepo_c is required" >&2; exit 1; }

for spec_name in "${specs[@]}"; do
    spec="$root_dir/packaging/rpm/$spec_name.spec"
    [[ -f "$spec" ]] || { echo "Missing spec: $spec" >&2; exit 1; }
    package_row=$(rpmspec --target x86_64 \
        --define "_topdir $root_dir/packaging/build" \
        -q --qf '%{NAME}|%{VERSION}|%{RELEASE}|%{ARCH}\n' "$spec" 2>/dev/null | sed -n '1p')
    [[ -n "$package_row" ]] || { echo "Could not read package metadata: $spec" >&2; exit 1; }
    IFS='|' read -r name version release arch <<< "$package_row"
    rpm_path="$rpm_dir/$arch/$name-$version-$release.$arch.rpm"
    [[ -f "$rpm_path" ]] || { echo "Missing RPM for $spec_name: $rpm_path" >&2; exit 1; }
    cp -p "$rpm_path" "$stage_dir/"
done

createrepo_c "$stage_dir" >/dev/null
(
    cd "$stage_dir"
    sha256sum ./*.rpm > SHA256SUMS
)

[[ ! -e "$repo_dir" ]] || { echo "Repository already exists: $repo_dir" >&2; exit 1; }
mkdir -p "$repo_parent"
mv "$stage_dir" "$repo_dir"

echo "Created local RPM repository: $repo_dir"
find "$repo_dir" -maxdepth 1 -type f -name '*.rpm' -printf '%f\n' | sort
