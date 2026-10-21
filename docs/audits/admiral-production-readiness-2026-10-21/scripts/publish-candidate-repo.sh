#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Publish an isolated x86_64 local repository for one audit candidate.
set -euo pipefail

[[ $# -eq 1 && $1 =~ ^[0-9]+$ ]] || { echo "usage: $0 RPM_RELEASE" >&2; exit 2; }
release=$1
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)
validation_dir="$project_root/packaging/build/validation/rc5-r${release}"
repo_root=${ADMIRAL_VALIDATION_REPO_ROOT:-/var/lib/libvirt/images/admiral-validation/repo}
support_repo="$repo_root/el10/x86_64"
candidate_repo="$repo_root/rc5-r${release}"
[[ -d $support_repo ]] || { echo "support RPM repository not found: $support_repo" >&2; exit 1; }
mkdir -p "$validation_dir"

support_patterns=(
  'python3-alembic-*.el10.noarch.rpm'
  'python3-flask-*.el10.noarch.rpm'
  'python3-flask-alembic-*.el10.noarch.rpm'
  'python3-flask-login-*.el10.noarch.rpm'
  'python3-flask-sqlalchemy-*.el10.noarch.rpm'
  'python3-typing-extensions-*.el10.noarch.rpm'
)
admiral_packages=(admiral-common admirald admiral-fleet admiralctl admiral-flagship admiral-harbor)

for distro in el10 fedora; do
  destination="$candidate_repo/$distro/x86_64"
  mkdir -p "$destination"
  for pattern in "${support_patterns[@]}"; do
    matches=("$support_repo"/$pattern)
    [[ -f ${matches[0]} ]] || { echo "missing local support RPM: $pattern" >&2; exit 1; }
    install -m 0644 "${matches[0]}" "$destination/"
  done

  if [[ $distro == el10 ]]; then
    mistune="$support_repo/python3-mistune-3.4.0-1.el10.noarch.rpm"
    mistune_nevra=python3-mistune-3.4.0-1.el10.noarch
  else
    mistune="$repo_root/fedora/x86_64/python3-mistune-3.4.0-1.fc46.noarch.rpm"
    mistune_nevra=python3-mistune-3.4.0-1.fc46.noarch
  fi
  [[ -f $mistune ]] || { echo "missing Mistune RPM: $mistune" >&2; exit 1; }
  install -m 0644 "$mistune" "$destination/"

  for package in "${admiral_packages[@]}"; do
    case "$package" in
      admiral-common|admiral-flagship|admiral-harbor)
        rpm="$project_root/packaging/build/RPMS/noarch/${package}-0.0.1rc5-${release}.el10.noarch.rpm"
        ;;
      *)
        rpm="$project_root/packaging/build/RPMS/x86_64/${package}-0.0.1rc5-${release}.el10.x86_64.rpm"
        ;;
    esac
    [[ -f $rpm ]] || { echo "missing Admiral RPM: $rpm" >&2; exit 1; }
    install -m 0644 "$rpm" "$destination/"
    rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' "$destination/$(basename "$rpm")"
  done

  createrepo_c --update --checksum sha256 "$destination"
  (cd "$destination" && sha256sum ./*.rpm > "$validation_dir/${distro}-RPM-SHA256SUMS")
  printf 'python3-mistune expected: %s\n' "$mistune_nevra"
done

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
