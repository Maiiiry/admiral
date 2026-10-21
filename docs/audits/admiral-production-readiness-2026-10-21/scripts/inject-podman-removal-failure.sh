#!/usr/bin/env bash
# Install a narrowly scoped Podman deletion-failure wrapper in a disposable
# audit guest. A systemd timer restores the original binary after five minutes.
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script as root inside a disposable audit guest." >&2
  exit 1
fi
if [[ $# -ne 1 || ! $1 =~ ^inst_[0-9a-f]{16}$ ]]; then
  echo "Usage: $0 inst_<16 lowercase hex characters>" >&2
  exit 2
fi

instance_id=$1
podman_bin=/usr/bin/podman
backup_bin=/usr/bin/podman.admiral-audit-original
log_file="/var/lib/admiral/audit-podman-fail-${instance_id}.log"
wrapper_file="/run/admiral-audit-podman-wrapper-${instance_id}"
restore_file="/run/admiral-audit-podman-restore-${instance_id}.sh"
restore_unit="admiral-audit-podman-restore-${instance_id}"

if [[ ! -f $podman_bin || -L $podman_bin || ! -x $podman_bin ]]; then
  echo "Expected a regular executable at $podman_bin; refusing to replace it." >&2
  exit 1
fi
if [[ -e $backup_bin || -e $log_file ]]; then
  echo "An audit backup or log already exists; refusing to overwrite it." >&2
  exit 1
fi
getent passwd admiral-apps >/dev/null
getent group admiral >/dev/null

install -o admiral-apps -g admiral -m 0600 /dev/null "$log_file"
cat > "$wrapper_file" <<'WRAPPER'
#!/usr/bin/env bash
# ADMIRAL_AUDIT_PODMAN_FAILURE_INJECTION
target_id='__INSTANCE_ID__'
log_file='__LOG_FILE__'
joined=" $* "
if [[ $joined == *"$target_id"* ]] && {
  { [[ $1 == pod ]] && [[ ${2:-} == rm ]]; } ||
  [[ $1 == rm ]] ||
  { [[ $1 == volume ]] && [[ ${2:-} == rm ]]; }
}; then
  {
    printf '%s injected Podman deletion failure:' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf ' %q' "$@"
    printf '\n'
  } >> "$log_file"
  echo "injected audit Podman deletion failure for $target_id" >&2
  exit 125
fi
exec /usr/bin/podman.admiral-audit-original "$@"
WRAPPER
sed -i \
  -e "s|__INSTANCE_ID__|$instance_id|g" \
  -e "s|__LOG_FILE__|$log_file|g" \
  "$wrapper_file"
chmod 0755 "$wrapper_file"

cat > "$restore_file" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ -e '$backup_bin' ]]; then
  if [[ -f '$podman_bin' ]] && grep -q ADMIRAL_AUDIT_PODMAN_FAILURE_INJECTION '$podman_bin'; then
    rm -f '$podman_bin'
  fi
  if [[ ! -e '$podman_bin' ]]; then
    mv '$backup_bin' '$podman_bin'
    restorecon -F '$podman_bin'
  fi
fi
EOF
chmod 0700 "$restore_file"

mv "$podman_bin" "$backup_bin"
if ! install -o root -g root -m 0755 "$wrapper_file" "$podman_bin"; then
  mv "$backup_bin" "$podman_bin"
  restorecon -F "$podman_bin"
  exit 1
fi
restorecon -F "$podman_bin" "$backup_bin" "$log_file"
if ! systemd-run --quiet --unit="$restore_unit" --on-active=5m /bin/bash "$restore_file"; then
  rm -f "$podman_bin"
  mv "$backup_bin" "$podman_bin"
  restorecon -F "$podman_bin"
  exit 1
fi

echo "Injected failures only for Podman deletion commands naming $instance_id."
echo "Restore manually with scripts/restore-podman-after-injection.sh $instance_id."
echo "A five-minute systemd timer is armed as a fallback. Preserve $log_file before cleanup."
sha256sum "$backup_bin" "$podman_bin"
