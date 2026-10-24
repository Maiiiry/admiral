#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Verify that a removed W2 cannot reach the hub private UI over the revoked peer.
set -euo pipefail
[[ $# -eq 6 ]] || { echo "usage: $0 SSH_KEY HUB_KNOWN WORKER_KNOWN HUB_IP WORKER_IP OUTPUT_DIR" >&2; exit 2; }
ssh_key=$1 hub_known=$2 worker_known=$3 hub_ip=$4 worker_ip=$5 output_dir=$6
[[ $output_dir == /* ]] || { echo 'expected absolute output directory' >&2; exit 2; }
for p in "$ssh_key" "$hub_known" "$worker_known"; do [[ -r $p ]] || { echo "unreadable input: $p" >&2; exit 1; }; done
install -d -m 0700 "$output_dir"
umask 077
ssh_args=(-i "$ssh_key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes)
ssh -o "UserKnownHostsFile=$worker_known" "${ssh_args[@]}" "validator@$worker_ip" 'sudo bash -s' >"$output_dir/private-ui-negative.txt" <<'REMOTE'
set -u
printf 'checked_utc=%s\n' "$(date -u +%FT%TZ)"
printf 'fleet_service_state=%s\n' "$(systemctl is-active admiral-fleet 2>/dev/null || true)"
printf 'route='; ip -4 route get 10.99.0.1 2>&1 || true
set +e
http=$(curl --connect-timeout 3 --max-time 8 -ksS -o /dev/null -w '%{http_code}' https://10.99.0.1:5001/ 2> /tmp/r73-private-ui-curl.err)
rc=$?
set -e
printf 'curl_exit=%s\nhttp_code=%s\n' "$rc" "$http"
if [[ -s /tmp/r73-private-ui-curl.err ]]; then printf 'curl_stderr='; tr '\n' ' ' </tmp/r73-private-ui-curl.err; printf '\n'; fi
[[ $rc -ne 0 && $http == 000 ]]
REMOTE
ssh -o "UserKnownHostsFile=$hub_known" "${ssh_args[@]}" "validator@$hub_ip" 'sudo bash -s' >"$output_dir/peer-revocation-postcheck.txt" <<'REMOTE'
set -euo pipefail
node_ip=10.99.0.3
printf 'checked_utc=%s\n' "$(date -u +%FT%TZ)"
live=$(wg show wg-admiral allowed-ips | awk -v ip="$node_ip/32" '$2 == ip {n++} END {print n+0}')
persistent=$({ grep -R -E -h '^[[:space:]]*AllowedIPs[[:space:]]*=[[:space:]]*10\.99\.0\.3/32([[:space:]]|$)' /etc/wireguard --include='*.conf' 2>/dev/null || true; } | wc -l)
printf 'wireguard_interface=wg-admiral\nremoved_worker_live_wireguard_peer_count=%s\nremoved_worker_persistent_peer_count=%s\n' "$live" "$persistent"
[[ $live -eq 0 && $persistent -eq 0 ]]
REMOTE
printf 'result=PASS-scoped\nchecked_utc=%s\n' "$(date -u +%FT%TZ)" >"$output_dir/private-ui-check-result.txt"
find "$output_dir" -maxdepth 1 -type f ! -name SHA256SUMS -exec chmod 0600 {} +
(cd "$output_dir" && find . -maxdepth 1 -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
chmod 0600 "$output_dir/SHA256SUMS"
cat "$output_dir/private-ui-negative.txt" "$output_dir/peer-revocation-postcheck.txt" "$output_dir/private-ui-check-result.txt"
