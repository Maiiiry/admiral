#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Refresh a disposable guest and install Admiral RPM runtime Requires before it
# is flattened into a reusable validation seed. Run as root inside the guest.
set -euo pipefail

os_id=$(. /etc/os-release && printf '%s' "$ID")
version_id=$(. /etc/os-release && printf '%s' "$VERSION_ID")
case "$os_id:$version_id" in
  rocky:10*|almalinux:10*|centos:10*)
    dnf install -y epel-release dnf-plugins-core
    dnf config-manager --set-enabled crb
    # The public EPEL mirror list returned transient checksum/TLS failures in
    # this lab. Use Fedora's canonical HTTPS origin while retaining GPG checks.
    epel_repo=/etc/yum.repos.d/epel.repo
    epel_baseurl='https://dl.fedoraproject.org/pub/epel/$releasever/Everything/$basearch/'
    if ! grep -Fq '# Admiral audit seed canonical EPEL origin' "$epel_repo"; then
      sed -i '/^\[epel\]$/,/^\[/ { s|^metalink=|#metalink=|; s|^baseurl=|#baseurl=|; }' "$epel_repo"
      sed -i "/^\[epel\]$/a # Admiral audit seed canonical EPEL origin\\nbaseurl=$epel_baseurl" "$epel_repo"
    fi
    ;;
  fedora:*)
    dnf install -y dnf5-plugins
    ;;
  *)
    echo "unsupported audit seed OS: $os_id $version_id" >&2
    exit 2
    ;;
esac

dnf copr enable -y admiral-project/admiral

copr_repo=$(find /etc/yum.repos.d -maxdepth 1 -type f \
  -name '*admiral-project*admiral*.repo' -print -quit)
[[ -n "$copr_repo" ]] || { echo "missing Admiral COPR repository file" >&2; exit 1; }
grep -Eq '^[[:space:]]*gpgcheck[[:space:]]*=[[:space:]]*1[[:space:]]*$' "$copr_repo" || {
  echo "Admiral COPR repository does not enforce GPG metadata checks" >&2
  exit 1
}

if [[ "$os_id" == rocky ]]; then
  pinned_rpm=/var/tmp/python3-pyOpenSSL-25.0.0-1.el10_1.noarch.rpm
  dnf install -y curl
  curl --fail --location --retry 3 --retry-all-errors --connect-timeout 10 --max-time 90 \
    -o "$pinned_rpm" \
    https://dl.fedoraproject.org/pub/archive/epel/10.1/Everything/x86_64/Packages/p/python3-pyOpenSSL-25.0.0-1.el10_1.noarch.rpm
  printf '%s  %s\n' \
    eb5d2a6be0e47099c63fa042f83afac12021820bfc0d79fa0f9dcd57b71941dc "$pinned_rpm" | sha256sum --check
  # epel-release installs the official EPEL key but does not always import it
  # into RPM's local keyring until a repository package transaction needs it.
  rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-10
  rpmkeys --checksig "$pinned_rpm"
  dnf install -y "$pinned_rpm"
  if ! sed -n '/^\[epel\]$/,/^\[/p' /etc/yum.repos.d/epel.repo | \
      grep -Eq '^excludepkgs=.*(^|[ ,])python3-pyOpenSSL([ ,]|$)'; then
    sed -i '/^\[epel\]$/a excludepkgs=python3-pyOpenSSL' /etc/yum.repos.d/epel.repo
  fi
fi

# Refresh the OS and enabled EPEL/Admiral repositories once while building the
# seed. These package names are the union of explicit Requires in the six
# Admiral RPM specs; admiral-common itself is installed later by the installer.
dnf -y update --refresh --allowerasing

packages=(
  ansible-collection-ansible-posix ansible-core caddy certbot curl gnupg2
  openssh-clients openssh-server openssl policycoreutils-python-utils podman
  postgresql postgresql-server python3 python3-argon2-cffi python3-cryptography
  python3-flask python3-flask-alembic python3-flask-login
  python3-flask-sqlalchemy python3-gunicorn python3-mistune python3-psycopg2
  python3-pyyaml python3-requests python3-werkzeug shadow-utils systemd
  systemd-container wireguard-tools
)
dnf install -y "${packages[@]}"

# The current local release-candidate repository carries newer Python RPMs
# than the public COPR snapshot (notably Flask and Mistune). When candidate
# RPMs are staged by the host, install them so the seed satisfies the exact
# package Requires that will be exercised by this release validation.
candidate_python_rpms=()
if [[ -d /var/tmp/admiral-candidate-python-rpms ]]; then
  shopt -s nullglob
  candidate_python_rpms=(/var/tmp/admiral-candidate-python-rpms/*.rpm)
  shopt -u nullglob
fi
if ((${#candidate_python_rpms[@]})); then
  dnf install -y "${candidate_python_rpms[@]}"
fi
dnf -y update --refresh --allowerasing

printf 'Prepared audit seed for %s %s at ' "$os_id" "$version_id"
date -u +'%Y-%m-%dT%H:%M:%SZ'
rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' "${packages[@]}"
if ((${#candidate_python_rpms[@]})); then
  rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' \
    python3-alembic python3-flask python3-flask-alembic python3-flask-login \
    python3-flask-sqlalchemy python3-mistune python3-typing-extensions
fi
if [[ "$os_id" == rocky || "$os_id" == almalinux ]]; then
  rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' python3-pyOpenSSL
fi
rpm -q --qf 'kernel-core-%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core 2>/dev/null || true
dnf history info last | sed -n '/^Transaction ID/,$p' | tail -n 20

set +e
dnf -q check-update
check_update_status=$?
set -e
if [[ $check_update_status -eq 100 ]]; then
  echo "updates remain after seed refresh" >&2
  exit 1
elif [[ $check_update_status -ne 0 ]]; then
  echo "dnf check-update failed with status $check_update_status" >&2
  exit "$check_update_status"
fi

dnf clean packages
rm -rf /var/tmp/admiral-candidate-python-rpms
rm -f /var/tmp/python3-pyOpenSSL-25.0.0-1.el10_1.noarch.rpm

# Drop source-instance identity and cloud-init state before flattening the disk.
cloud-init clean --logs --machine-id --seed --configs all
