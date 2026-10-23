#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Publish isolated, distro-native x86_64 repositories for one audit candidate.
set -euo pipefail

[[ $# -eq 1 && $1 =~ ^[0-9]+$ ]] || { echo "usage: $0 RPM_RELEASE" >&2; exit 2; }
release=$1
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)
validation_dir="$project_root/packaging/build/validation/rc5-r${release}"
repo_root=${ADMIRAL_VALIDATION_REPO_ROOT:-/var/lib/libvirt/images/admiral-validation/repo}
candidate_repo="$repo_root/rc5-r${release}"

# Build and support inputs must be kept separate by distro. Callers building in
# containers should set these to the mounted artifact and helper-RPM directories.
el10_rpms=${ADMIRAL_EL10_RPM_DIR:-$project_root/packaging/build/RPMS}
fedora_rpms=${ADMIRAL_FEDORA_RPM_DIR:-$project_root/packaging/build/fedora/RPMS}
el10_support=${ADMIRAL_EL10_SUPPORT_REPO:-$project_root/packaging/build/repos/el10-rc5-r66-x86_64}
fedora_support=${ADMIRAL_FEDORA_SUPPORT_REPO:-$project_root/packaging/build/repos/fedora-rawhide46-rc5-r66-x86_64}
fedora_tag=${ADMIRAL_FEDORA_DIST_TAG:-fc46}

mkdir -p "$validation_dir"
admiral_packages=(admiral-common admirald admiral-fleet admiralctl admiral-flagship admiral-harbor)

publish_distro() {
  local distro=$1 tag=$2 rpm_dir=$3 support_dir=$4 destination="$candidate_repo/$1/x86_64"
  [[ -d $rpm_dir ]] || { echo "missing $distro Admiral RPM directory: $rpm_dir" >&2; return 1; }
  [[ -d $support_dir ]] || { echo "missing $distro Python support RPM directory: $support_dir" >&2; return 1; }

  local -a helper_rpms=()
  local -A expected_files=()
  shopt -s nullglob
  for rpm in "$support_dir"/python3-*.rpm; do
    local name nevra
    name=$(basename -- "$rpm")
    nevra=$(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}' "$rpm")
    [[ $name == *".$tag."* && $nevra == *".$tag."* ]] || {
      echo "rejecting non-$distro helper RPM in $support_dir: $name ($nevra)" >&2
      return 1
    }
    helper_rpms+=("$rpm")
  done
  shopt -u nullglob
  [[ ${#helper_rpms[@]} -eq 8 ]] || {
    echo "expected 8 distro-native Python helper RPMs in $support_dir, found ${#helper_rpms[@]}" >&2
    return 1
  }

  mkdir -p "$destination"
  for rpm in "${helper_rpms[@]}"; do
    install -m 0644 "$rpm" "$destination/"
    expected_files[$(basename -- "$rpm")]=1
  done

  for package in "${admiral_packages[@]}"; do
    local rpm arch nevra
    case "$package" in
      admiral-common|admiral-flagship|admiral-harbor) arch=noarch ;;
      *) arch=x86_64 ;;
    esac
    rpm="$rpm_dir/$arch/${package}-0.0.1rc5-${release}.${tag}.${arch}.rpm"
    [[ -f $rpm ]] || { echo "missing $distro Admiral RPM: $rpm" >&2; return 1; }
    nevra=$(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}' "$rpm")
    [[ $nevra == "${package}-0.0.1rc5-${release}.${tag}.${arch}" ]] || {
      echo "unexpected $distro RPM identity: $nevra ($rpm)" >&2
      return 1
    }
    install -m 0644 "$rpm" "$destination/"
    expected_files[$(basename -- "$rpm")]=1
  done

  local -a staged_rpms=("$destination"/*.rpm)
  [[ ${#staged_rpms[@]} -eq ${#expected_files[@]} ]] || {
    echo "$distro repository has ${#staged_rpms[@]} RPM files; expected exactly ${#expected_files[@]}" >&2
    return 1
  }
  for rpm in "${staged_rpms[@]}"; do
    local name nevra
    name=$(basename -- "$rpm")
    [[ ${expected_files[$name]+present} == present ]] || {
      echo "unexpected stale or mixed RPM in $distro repository: $name" >&2
      return 1
    }
    nevra=$(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}' "$rpm")
    [[ $nevra == *".$tag."* ]] || {
      echo "wrong-distro RPM already staged in $distro repository: $name ($nevra)" >&2
      return 1
    }
  done

  createrepo_c --update --checksum sha256 "$destination"
  (
    cd -- "$destination"
    sha256sum ./*.rpm > SHA256SUMS
    printf 'name\tepoch\tversion\trelease\tarch\tsha256\tfile\n' > RPM-MANIFEST.tsv
    for rpm in ./*.rpm; do
      rpm -qp --qf '%{NAME}\t%{EPOCH}\t%{VERSION}\t%{RELEASE}\t%{ARCH}\n' "$rpm" |
        while IFS=$'\t' read -r name epoch version rpm_release arch; do
          hash=$(sha256sum "$rpm" | awk '{print $1}')
          printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$name" "$epoch" "$version" "$rpm_release" "$arch" "$hash" "${rpm#./}" >> RPM-MANIFEST.tsv
        done
    done
  )
  printf '[%s] published %s Admiral RPMs and %s distro-native Python helper RPMs\n' \
    "$distro" "${#admiral_packages[@]}" "${#helper_rpms[@]}"
}

publish_distro el10 el10 "$el10_rpms" "$el10_support"
publish_distro fedora "$fedora_tag" "$fedora_rpms" "$fedora_support"

cat > "$validation_dir/admiral-local-el10.repo" <<EOF
[admiral-local]
name=Admiral RC5 Release ${release} local validation (EL10)
baseurl=http://192.168.122.1/rc5-r${release}/el10/\$basearch
enabled=1
gpgcheck=0
priority=1
skip_if_unavailable=0
EOF

cat > "$validation_dir/admiral-local-fedora.repo" <<EOF
[admiral-local]
name=Admiral RC5 Release ${release} local validation (Fedora Rawhide)
baseurl=http://192.168.122.1/rc5-r${release}/fedora/\$basearch
enabled=1
gpgcheck=0
priority=1
skip_if_unavailable=0
EOF

chmod 0644 "$validation_dir"/admiral-local-*.repo
echo "Candidate repository published at $candidate_repo"
