#!/usr/bin/env bash
# Configure the signed, isolated R68 repository on one validation guest.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo 'run as root' >&2; exit 1; }
[[ $# -eq 1 ]] || { echo "usage: $0 {fedora|el10}" >&2; exit 2; }
case $1 in
  fedora) repo_path=fedora; repo_name='Admiral RC5 Release 68 signed local validation (Fedora Rawhide)' ;;
  el10) repo_path=el10; repo_name='Admiral RC5 Release 68 signed local validation (EL10)' ;;
  *) echo "unsupported candidate repository: $1" >&2; exit 2 ;;
esac
key_url=http://192.168.122.1/rc5-r68/RPM-GPG-KEY-admiral-r68
key_path=/etc/pki/rpm-gpg/RPM-GPG-KEY-admiral-r68
expected_sha=cf49a646e169d9716daf29b13491618a9836532b2217f3c14a630a30a6f69b39
expected_fpr=558AF753B5F48CE8303F3F56688DE7E47E3DB9CD
key_tmp=$(mktemp)
repo_tmp=$(mktemp)
trap 'rm -f -- "$key_tmp" "$repo_tmp"' EXIT
curl --fail --location --silent --show-error "$key_url" -o "$key_tmp"
printf '%s  %s\n' "$expected_sha" "$key_tmp" | sha256sum --check
fingerprint=$(gpg --show-keys --with-colons "$key_tmp" | awk -F: '$1 == "fpr" {print $10; exit}')
[[ $fingerprint == "$expected_fpr" ]] || { echo "unexpected candidate key fingerprint: $fingerprint" >&2; exit 1; }
install -o root -g root -m 0644 "$key_tmp" "$key_path"
rpm --import "$key_path"
cat >"$repo_tmp" <<EOF
[admiral-local]
name=$repo_name
baseurl=http://192.168.122.1/rc5-r68/$repo_path/\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=file://$key_path
priority=1
skip_if_unavailable=0
EOF
install -o root -g root -m 0644 "$repo_tmp" /etc/yum.repos.d/admiral-local.repo
dnf -y makecache --refresh --repo=admiral-local
printf 'repo=admiral-local baseurl=http://192.168.122.1/rc5-r68/%s/$basearch gpgcheck=1 repo_gpgcheck=1 fingerprint=%s\n' "$repo_path" "$fingerprint"
