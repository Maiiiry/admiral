#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Install the exact local RC candidate as an isolated admin/portal hub.
set -euo pipefail

[[ $# -eq 6 ]] || {
  echo "usage: $0 SSH_KEY KNOWN_HOSTS USER@GUEST UNDERLAY_IP NODE_ID OUTPUT_LOG" >&2
  exit 2
}
ssh_key=$1 known_hosts=$2 target=$3 underlay_ip=$4 node_id=$5 output=$6
release=${ADMIRAL_RC_RELEASE:-57}
[[ $release =~ ^[0-9]+$ ]] || { echo "invalid Admiral RPM Release: $release" >&2; exit 2; }
[[ $underlay_ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "invalid underlay IPv4" >&2; exit 2; }
[[ $node_id =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,62}$ ]] || { echo "invalid node id" >&2; exit 2; }
[[ -r $ssh_key && -r $known_hosts ]] || { echo "SSH identity or known-hosts file is unreadable" >&2; exit 1; }

repo_file=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)/packaging/build/validation/rc5-r${release}/admiral-local-el10.repo
[[ -r $repo_file ]] || { echo "local EL10 candidate repository is missing: $repo_file" >&2; exit 1; }
mkdir -p "$(dirname "$output")"
umask 077
ssh_args=(-i "$ssh_key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$known_hosts")

{
  printf 'audit_start_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  scp "${ssh_args[@]}" "$repo_file" "$target:/tmp/admiral-local.repo"
  ssh "${ssh_args[@]}" "$target" sudo bash -s -- "$release" <<'REMOTE'
set -euo pipefail
release=$1
install -o root -g root -m 0644 /tmp/admiral-local.repo /etc/yum.repos.d/admiral-local.repo
dnf install -y dnf-plugins-core
dnf install -y epel-release
dnf config-manager --set-enabled crb
dnf copr enable -y admiral-project/admiral

echo 'PUBLIC_REPOSITORY_DEPENDENCY_QUERY_BEGIN'
dnf --disablerepo=admiral-local repoquery --available --latest-limit=1 \
  --qf '%{name}-%{version}-%{release}.%{arch} %{repoid}' python3-flask python3-mistune
echo 'PUBLIC_REPOSITORY_DEPENDENCY_QUERY_END'

# The immutable seed contains support packages to make ordinary provisioning
# fast. Remove the two version-gated packages on this disposable hub so the
# exact candidate transaction must resolve them again. Keep unrelated cached
# dependencies; DNF will restore any extension packages it needs.
dnf remove -y --noautoremove python3-flask python3-mistune

packages=()
for package in admiral-common admirald admiralctl admiral-fleet admiral-harbor admiral-flagship; do
  packages+=("${package}-0.0.1rc5-${release}.el10")
done
dnf install -y "${packages[@]}"

for package in admiral-common admirald admiralctl admiral-fleet admiral-harbor admiral-flagship; do
  actual=$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' "$package")
  [[ $actual == "0.0.1rc5-${release}.el10."* ]] || {
    echo "$package has unexpected NEVRA: $actual" >&2
    exit 1
  }
done
rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' python3-flask python3-mistune
REMOTE

  ssh "${ssh_args[@]}" "$target" sudo bash -s -- "$underlay_ip" "$node_id" "$release" <<'REMOTE'
set -euo pipefail
underlay_ip=$1 node_id=$2 release=$3
before=$(mktemp)
after=$(mktemp)
trap 'rm -f -- "$before" "$after"' EXIT
rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort >"$before"
install_start_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
install_started=$SECONDS
set +e
admiral-install --admin-portal-node --validation-seed --public-ip "$underlay_ip" \
  --ssh-public-key /home/validator/validator.pub --node-id "$node_id"
install_rc=$?
set -e
install_elapsed=$((SECONDS - install_started))
install_end_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort >"$after"
printf 'installer_start_utc=%s installer_end_utc=%s installer_elapsed_seconds=%s installer_exit_code=%s\n' \
  "$install_start_utc" "$install_end_utc" "$install_elapsed" "$install_rc"
printf 'package_nevra_delta_begin (minus=before, plus=after)\n'
diff -u "$before" "$after" || true
printf 'package_nevra_delta_end\n'
if [[ $install_rc -eq 0 ]]; then
  for package in admiral-common admirald admiralctl admiral-fleet admiral-harbor admiral-flagship; do
    case "$package" in
      admiral-common|admiral-harbor|admiral-flagship) expected_arch=noarch ;;
      *) expected_arch=x86_64 ;;
    esac
    actual=$(rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}' "$package")
    expected="$package-0.0.1rc5-${release}.el10.$expected_arch"
    [[ $actual == "$expected" ]] || {
      echo "$package is not the exact Release 57 candidate after install: $actual" >&2
      exit 1
    }
  done
  rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' python3-flask python3-mistune
  audit_user=${SUDO_USER:-}
  [[ -n $audit_user && $audit_user != root ]] || {
    echo 'cannot initialize audit CLI: sudo caller is not an unprivileged operator' >&2
    exit 1
  }
  audit_home=$(getent passwd "$audit_user" | cut -d: -f6)
  audit_group=$(id -gn "$audit_user")
  [[ -n $audit_home && -n $audit_group ]] || { echo 'cannot resolve audit operator account' >&2; exit 1; }
  cli_config_dir="$audit_home/.config/admiralctl"
  install -d -o "$audit_user" -g "$audit_group" -m 0700 "$cli_config_dir"
  install -o "$audit_user" -g "$audit_group" -m 0644 /etc/admiral/tls/ca.pem "$cli_config_dir/ca.pem"
  . /etc/admiral/flagship.env
  [[ -n ${ADMIRAL_INTERNAL_TOKEN:-} && -n ${ADMIRAL_API_URL:-} ]] || {
    echo 'cannot initialize audit CLI: generated control-plane credentials are missing' >&2
    exit 1
  }
  runuser -u "$audit_user" -- env HOME="$audit_home" ADMIRAL_OPERATOR_TOKEN="$ADMIRAL_INTERNAL_TOKEN" \
    admiralctl init --server "$ADMIRAL_API_URL" --ca-cert "$cli_config_dir/ca.pem"
  runuser -u "$audit_user" -- env HOME="$audit_home" ADMIRAL_OPERATOR_TOKEN="$ADMIRAL_INTERNAL_TOKEN" \
    admiralctl status --output json >/dev/null
  unset ADMIRAL_INTERNAL_TOKEN
fi
exit "$install_rc"
REMOTE
  printf 'audit_end_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} 2>&1 | tee "$output"
chmod 0600 "$output"
