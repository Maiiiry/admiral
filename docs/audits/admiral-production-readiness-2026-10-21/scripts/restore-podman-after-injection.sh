#!/usr/bin/env bash
# Restore the original Podman executable after a disposable audit injection.
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script as root inside the same disposable audit guest." >&2
  exit 1
fi
if [[ $# -ne 1 || ! $1 =~ ^inst_[0-9a-f]{16}$ ]]; then
  echo "Usage: $0 inst_<16 lowercase hex characters>" >&2
  exit 2
fi

instance_id=$1
podman_bin=/usr/bin/podman
backup_bin=/usr/bin/podman.admiral-audit-original
restore_unit="admiral-audit-podman-restore-${instance_id}"

if [[ ! -e $backup_bin ]]; then
  echo "No saved Podman executable at $backup_bin." >&2
  exit 1
fi
if [[ ! -f $podman_bin ]] || ! grep -q ADMIRAL_AUDIT_PODMAN_FAILURE_INJECTION "$podman_bin"; then
  echo "The current $podman_bin is not the expected audit wrapper; refusing to replace it." >&2
  exit 1
fi

systemctl stop "${restore_unit}.timer" "${restore_unit}.service" 2>/dev/null || true
rm -f "$podman_bin"
mv "$backup_bin" "$podman_bin"
restorecon -F "$podman_bin"
rm -f "/run/admiral-audit-podman-restore-${instance_id}.sh" "/run/admiral-audit-podman-wrapper-${instance_id}"
echo "Restored Podman; keep the audit log until it has been captured, then remove it."
sha256sum "$podman_bin"
podman --version
