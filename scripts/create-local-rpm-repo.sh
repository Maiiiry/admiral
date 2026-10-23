#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
rpm_topdir=${RPMTOPDIR:-${RPMDIR:-"$root_dir/packaging/build"}}
rpm_dir="$rpm_topdir/RPMS"
repo_parent=${RPM_REPO_ROOT:-"$root_dir/packaging/build/repos"}
rpm_arch=${RPM_ARCH:-$(rpm --eval '%{_target_cpu}')}

specs=(
    admiral-common admirald admiral-fleet admiralctl admiral-flagship admiral-harbor
    python-alembic python-flask python-flask-alembic python-flask-login
    python-flask-sqlalchemy python-mistune python-sqlalchemy python-typing-extensions
)
admiral_packages=(
    admiral-common admirald admiral-fleet admiralctl admiral-flagship admiral-harbor
)

command -v createrepo_c >/dev/null || { echo "createrepo_c is required" >&2; exit 1; }
command -v rpmspec >/dev/null || { echo "rpmspec is required" >&2; exit 1; }
command -v rpm >/dev/null || { echo "rpm is required" >&2; exit 1; }
[[ -d "$rpm_dir" ]] || { echo "RPM directory does not exist: $rpm_dir" >&2; exit 1; }

mkdir -p "$repo_parent"
stage_dir=$(mktemp -d "$repo_parent/.local-rpm-repo.XXXXXX")
cleanup() {
    [[ -z "${stage_dir:-}" || ! -d "$stage_dir" ]] || rm -rf "$stage_dir"
}
trap cleanup EXIT

declare -A seen_names=()
admiral_release_number=
admiral_version=
for spec_name in "${specs[@]}"; do
    spec="$root_dir/packaging/rpm/$spec_name.spec"
    [[ -f "$spec" ]] || { echo "Missing spec: $spec" >&2; exit 1; }
    package_row=$(rpmspec --target "$rpm_arch" \
        --define "_topdir $rpm_topdir" \
        -q --qf '%{NAME}|%{VERSION}|%{RELEASE}|%{ARCH}\n' "$spec" 2>/dev/null | sed -n '1p')
    [[ -n "$package_row" ]] || { echo "Could not read package metadata: $spec" >&2; exit 1; }
    IFS='|' read -r name version release arch <<< "$package_row"
    [[ -z "${seen_names[$name]:-}" ]] || { echo "Duplicate package in specs: $name" >&2; exit 1; }
    seen_names[$name]=1

    if [[ " ${admiral_packages[*]} " == *" $spec_name "* ]]; then
        release_number=${release%%.*}
        [[ "$release_number" =~ ^[0-9]+$ ]] || { echo "Invalid Admiral Release in $spec: $release" >&2; exit 1; }
        if [[ -z "$admiral_release_number" ]]; then
            admiral_release_number=$release_number
            admiral_version=$version
        elif [[ "$release_number" != "$admiral_release_number" || "$version" != "$admiral_version" ]]; then
            echo "Admiral package releases are not coordinated: $spec_name has $version-$release" >&2
            exit 1
        fi
    fi

    rpm_path="$rpm_dir/$arch/$name-$version-$release.$arch.rpm"
    [[ -f "$rpm_path" ]] || { echo "Missing RPM for $spec_name: $rpm_path" >&2; exit 1; }
    actual=$(rpm -qp --qf '%{NAME}|%{VERSION}|%{RELEASE}|%{ARCH}' "$rpm_path")
    [[ "$actual" == "$name|$version|$release|$arch" ]] || {
        echo "RPM NEVRA does not match spec for $spec_name: expected $name-$version-$release.$arch, found $actual" >&2
        exit 1
    }
    cp -p "$rpm_path" "$stage_dir/"
done

[[ -n "$admiral_release_number" ]] || { echo "Could not determine Admiral Release from specs" >&2; exit 1; }
repo_dir="$repo_parent/el10-rc5-r${admiral_release_number}-${rpm_arch}"
[[ ! -e "$repo_dir" ]] || { echo "Repository already exists: $repo_dir" >&2; exit 1; }

createrepo_c "$stage_dir" >/dev/null
(
    cd "$stage_dir"
    sha256sum ./*.rpm > SHA256SUMS
    {
        printf 'name\tepoch\tversion\trelease\tarch\tsha256\tfile\n'
        for package in ./*.rpm; do
            rpm -qp --qf '%{NAME}\t%{EPOCHNUM}\t%{VERSION}\t%{RELEASE}\t%{ARCH}\t' "$package"
            sha256sum -- "$package" | awk '{printf "%s\t%s\n", $1, substr($2, 3)}'
        done
    } > RPM-MANIFEST.tsv
)

mv "$stage_dir" "$repo_dir"
stage_dir=
trap - EXIT

echo "Created local RPM repository: $repo_dir"
find "$repo_dir" -maxdepth 1 -type f -name '*.rpm' -printf '%f\n' | sort
