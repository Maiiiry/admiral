#!/usr/bin/env bash
# Execute the installed R58 daemon against the shipped placeholder template.
set -euo pipefail
cd /
config_dir=$(mktemp -d /var/tmp/adm-r58-config-negative.XXXXXX)
trap 'rm -rf "$config_dir"' EXIT
install -m 0600 /tmp/audit-admirald-placeholder.ini "$config_dir/admirald.ini"
set +e
ADMIRAL_ENV=production CREDENTIALS_DIRECTORY="$config_dir" /usr/bin/admirald \
  > "$config_dir/stdout.log" 2> "$config_dir/stderr.log"
rc=$?
set -e
if [[ $rc -eq 0 ]]; then
  echo 'daemon accepted the shipped placeholder configuration' >&2
  exit 1
fi
if ! grep -q '__REQUIRED__ is a template placeholder' "$config_dir/stderr.log"; then
  cat "$config_dir/stderr.log" >&2
  echo 'daemon exited without the expected placeholder rejection' >&2
  exit 1
fi
cat "$config_dir/stderr.log"
echo 'installed_daemon_placeholder_rejection=PASS'
