#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Read-only host and libvirt preflight; does not print guest credentials.
set -euo pipefail
printf 'timestamp_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cat /etc/os-release
uname -a
lscpu | rg '^(Architecture|CPU\(s\)|Model name):'
free -h
swapon --show
df -h /
printf '\nKVM: '
[[ -r /dev/kvm && -w /dev/kvm ]] && echo available || echo unavailable
printf '\nSELinux: '
getenforce
printf '\nLibvirt/QEMU:\n'
virsh version
if command -v qemu-system-x86_64 >/dev/null 2>&1; then
  qemu-system-x86_64 --version | head -n 1
elif [[ -x /usr/libexec/qemu-kvm ]]; then
  /usr/libexec/qemu-kvm --version | head -n 1
else
  rpm -q qemu-kvm qemu-kvm-core 2>&1 || true
fi
printf '\nActive guests:\n'
virsh list --name | while IFS= read -r domain; do
  [[ -n $domain ]] || continue
  printf '%s: ' "$domain"
  virsh domstate "$domain" | tr -d '\r\n'
  printf '\n'
done
printf '\nFree storage:\n'
df -h /var/lib/libvirt/images
