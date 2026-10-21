#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Run the supported worker bootstrap from an installed admin-portal node.
set -euo pipefail
[[ $# -eq 8 ]] || {
  echo "usage: $0 ADMIN_SSH_KEY KNOWN_HOSTS ADMIN_IP WORKER_IP NODE_ID WIREGUARD_IP HOST_FINGERPRINT OUTPUT_LOG" >&2
  exit 2
}
admin_key=$1 known_hosts=$2 admin_ip=$3 worker_ip=$4 node_id=$5 wg_ip=$6 fingerprint=$7 output=$8
[[ $node_id =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,62}$ ]] || { echo "invalid node id" >&2; exit 2; }
[[ $admin_ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ && $worker_ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "invalid IPv4 address" >&2; exit 2; }
[[ $wg_ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "invalid WireGuard address" >&2; exit 2; }
[[ $fingerprint =~ ^SHA256:[A-Za-z0-9+/]+$ ]] || { echo "invalid SSH fingerprint" >&2; exit 2; }
[[ -r $admin_key && -r $known_hosts ]] || { echo "admin SSH identity or known-hosts file is unreadable" >&2; exit 1; }
umask 077
mkdir -p "$(dirname "$output")"
start=$(date -u +%Y-%m-%dT%H:%M:%SZ)
set +e
ssh -i "$admin_key" -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$known_hosts" \
  "validator@$admin_ip" sudo admiral-install --worker-node --yes \
  --node-id "$node_id" --public-ip "$worker_ip" --wireguard-ip "$wg_ip" \
  --admin-endpoint "$admin_ip" --ssh-user validator \
  --ssh-key /home/validator/.ssh/validator_ed25519 --ssh-fingerprint "$fingerprint" \
  >"$output" 2>&1
rc=$?
set -e
chmod 0600 "$output"
end=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf 'start_utc=%s end_utc=%s ssh_exit_code=%s\n' "$start" "$end" "$rc"
python3 - "$output" <<'PY'
import re,sys
from pathlib import Path
for line in Path(sys.argv[1]).read_text(errors='replace').splitlines():
    if re.search(r'(?i)(secret|password|token|private|credential|fingerprint|signing[_ -]?key)', line):
        continue
    if line.startswith('TASK [') or 'PLAY RECAP' in line or re.search(r'localhost\s+: ok=', line) or 'Admiral installation completed.' in line or '[FATAL]' in line or 'ERROR!' in line:
        print(line[:220])
PY
exit "$rc"
