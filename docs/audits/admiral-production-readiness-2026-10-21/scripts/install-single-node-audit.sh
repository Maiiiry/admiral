#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Install the exact local RC candidate and run the supported secure installer.
set -euo pipefail
[[ $# -eq 7 ]] || {
  echo "usage: $0 {el10|fedora} SSH_KEY KNOWN_HOSTS USER@GUEST NODE_IP NODE_ID OUTPUT_LOG" >&2
  exit 2
}
distro=$1 ssh_key=$2 known_hosts=$3 target=$4 node_ip=$5 node_id=$6 output=$7
release=${ADMIRAL_RC_RELEASE:-65}
[[ $release =~ ^[0-9]+$ ]] || { echo "invalid Admiral RPM Release: $release" >&2; exit 2; }
[[ $node_id =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,62}$ ]] || { echo "invalid node id" >&2; exit 2; }
[[ $node_ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "invalid guest IPv4" >&2; exit 2; }
case "$distro" in
  el10) repo_name=admiral-local-el10.repo; mistune_nevra=python3-mistune-3.4.0-1.el10.noarch ;;
  fedora) repo_name=admiral-local-fedora.repo; mistune_nevra=python3-mistune-3.4.0-1.fc46.noarch ;;
  *) echo "unsupported distribution profile: $distro" >&2; exit 2 ;;
esac
repo_file=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)/packaging/build/validation/rc5-r${release}/$repo_name
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
  ssh "${ssh_args[@]}" "$target" sudo bash -s -- "$distro" "$mistune_nevra" "$release" <<'REMOTE'
set -euo pipefail
distribution=$1 expected_mistune_nevra=$2 expected_release=$3
install_args=()
if [[ $distribution == fedora ]]; then
  # The Rawhide candidate support RPM is built separately from the COPR build.
  install_args+=(--allow-vendor-change)
fi
dnf install -y dnf-plugins-core
if [[ $distribution == el10 ]]; then
  dnf install -y epel-release
  dnf config-manager --set-enabled crb
fi
dnf copr enable -y admiral-project/admiral
  packages=()
  for package in admiral-common admirald admiralctl admiral-fleet admiral-harbor admiral-flagship; do
    packages+=("${package}-0.0.1rc5-${expected_release}.el10")
  done
  dnf install -y "${install_args[@]}" "${packages[@]}"
for package in admiral-common admirald admiralctl admiral-fleet admiral-harbor admiral-flagship; do
  actual=$(rpm -q --qf '%{VERSION}-%{RELEASE}\n' "$package")
  [[ $actual == "0.0.1rc5-${expected_release}.el10" ]] || { echo "$package has unexpected NEVRA: $actual" >&2; exit 1; }
done
rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' python3-mistune | grep -Fx "$expected_mistune_nevra"
REMOTE
  ssh "${ssh_args[@]}" "$target" sudo bash -s -- "$node_ip" "$node_id" <<'REMOTE'
set -euo pipefail
node_ip=$1 node_id=$2
rpm_before=$(mktemp)
rpm_after=$(mktemp)
trap 'rm -f -- "$rpm_before" "$rpm_after"' EXIT
rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort >"$rpm_before"
install_start_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
install_started=$SECONDS
set +e
admiral-install --single-node --validation-seed --public-ip "$node_ip" \
  --ssh-public-key /home/validator/validator.pub --node-id "$node_id"
install_rc=$?
set -e
install_elapsed=$((SECONDS - install_started))
install_end_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort >"$rpm_after"
printf 'installer_start_utc=%s installer_end_utc=%s installer_elapsed_seconds=%s installer_exit_code=%s\n' \
  "$install_start_utc" "$install_end_utc" "$install_elapsed" "$install_rc"
printf 'package_nevra_delta_begin (minus=before, plus=after)\n'
diff -u "$rpm_before" "$rpm_after" || true
printf 'package_nevra_delta_end\n'
dnf history info last | sed -n '/^Transaction ID/,$p' | tail -n 30 || true
  if [[ $install_rc -eq 0 ]]; then
    audit_user=${SUDO_USER:-}
    [[ -n $audit_user && $audit_user != root ]] || {
      echo 'cannot initialize the audit CLI: sudo caller is not an unprivileged operator' >&2
      exit 1
    }
    audit_home=$(getent passwd "$audit_user" | cut -d: -f6)
    audit_group=$(id -gn "$audit_user")
    [[ -n $audit_home && -n $audit_group ]] || {
      echo "cannot resolve home and group for audit operator $audit_user" >&2
      exit 1
    }
    cli_config_dir="$audit_home/.config/admiralctl"
    install -d -o "$audit_user" -g "$audit_group" -m 0700 "$cli_config_dir"
    install -o "$audit_user" -g "$audit_group" -m 0644 \
      /etc/admiral/tls/ca.pem "$cli_config_dir/ca.pem"
    . /etc/admiral/flagship.env
    [[ -n ${ADMIRAL_INTERNAL_TOKEN:-} && -n ${ADMIRAL_API_URL:-} ]] || {
      echo 'cannot initialize the audit CLI: generated control-plane credentials are missing' >&2
      exit 1
    }
    runuser -u "$audit_user" -- env HOME="$audit_home" \
      ADMIRAL_OPERATOR_TOKEN="$ADMIRAL_INTERNAL_TOKEN" \
      admiralctl init --server "$ADMIRAL_API_URL" \
      --ca-cert "$cli_config_dir/ca.pem"
    runuser -u "$audit_user" -- env HOME="$audit_home" \
      admiralctl status --output json >/dev/null
    unset ADMIRAL_INTERNAL_TOKEN
  fi
exit "$install_rc"
REMOTE
  printf 'audit_end_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} 2>&1 | tee "$output"
chmod 0600 "$output"
