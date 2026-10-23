#!/usr/bin/env bash
set -euo pipefail

# Runtime-only WireGuard partition regression for the isolated R65 AlmaLinux lab.
# This changes one peer's in-memory AllowedIPs on the hub and arms an automatic
# 180-second restore before applying the partition. It never edits wg configs.
if [[ $# -ne 4 ]]; then
  echo "Usage: $0 SSH_PRIVATE_KEY HUB_KNOWN_HOSTS WORKER_KNOWN_HOSTS INSTANCE_ID" >&2
  exit 2
fi

ssh_key=$1
hub_known_hosts=$2
worker_known_hosts=$3
instance_id=$4
[[ $instance_id =~ ^inst_[A-Za-z0-9]+$ ]] || { echo "invalid instance ID" >&2; exit 2; }

hub=validator@10.77.0.10
worker=validator@10.77.0.12
node_id=adm-r65-alma-w2
peer_overlay=10.99.0.3/32
partition_overlay=10.99.0.254/32
restore_unit=admiral-r65-wg-restore

ssh_hub() {
  ssh -i "$ssh_key" -o BatchMode=yes -o StrictHostKeyChecking=yes \
    -o "UserKnownHostsFile=$hub_known_hosts" "$hub" "$@"
}

ssh_worker() {
  ssh -i "$ssh_key" -o BatchMode=yes -o StrictHostKeyChecking=yes \
    -o "UserKnownHostsFile=$worker_known_hosts" "$worker" "$@"
}

peer_key=$(ssh_hub sudo wg show wg-admiral endpoints | awk '$2 == "10.77.0.12:51820" { print $1 }')
[[ $peer_key =~ ^[A-Za-z0-9+/]{43}=$ ]] || { echo "could not identify W2 WireGuard peer" >&2; exit 1; }
current_allowed=$(ssh_hub sudo wg show wg-admiral allowed-ips | awk -v peer="$peer_key" '$1 == peer { print $2 }')
[[ $current_allowed == "$peer_overlay" ]] || {
  echo "unexpected W2 AllowedIPs: $current_allowed" >&2
  exit 1
}

restore_peer() {
  ssh_hub sudo wg set wg-admiral peer "$peer_key" allowed-ips "$peer_overlay" || true
  ssh_hub sudo systemctl stop "$restore_unit.timer" >/dev/null 2>&1 || true
}
trap restore_peer EXIT INT TERM

ssh_hub sudo systemd-run --unit="$restore_unit" --on-active=180s \
  /usr/bin/wg set wg-admiral peer "$peer_key" allowed-ips "$peer_overlay"
ssh_hub sudo wg set wg-admiral peer "$peer_key" allowed-ips "$partition_overlay"
partition_started=$(date -u +%FT%TZ)
printf 'partition_started=%s instance=%s node=%s\n' "$partition_started" "$instance_id" "$node_id"

set +e
curl_output=$(ssh_worker curl --connect-timeout 3 --max-time 5 -ksS -o /dev/null \
  -w 'worker_to_hub_http=%{http_code}\n' https://10.99.0.1:8080/health 2>&1)
curl_rc=$?
set -e
printf '%s\n' "$curl_output"
[[ $curl_rc -eq 28 ]] || { echo "partition did not cause expected curl timeout (rc=$curl_rc)" >&2; exit 1; }

partition_seen=false
for poll in $(seq 1 15); do
  nodes=$(ssh_hub admiralctl nodes list --output json)
  instance=$(ssh_hub admiralctl instances show "$instance_id")
  read -r node_status node_health heartbeat <<<"$(printf '%s' "$nodes" | python3 -c '
import json, sys
items = json.load(sys.stdin)
node = next(x for x in items if x.get("id") == sys.argv[1])
print(node.get("status", ""), node.get("health_status", ""), node.get("last_heartbeat", ""))
' "$node_id")"
  read -r technical health availability checked <<<"$(printf '%s' "$instance" | python3 -c '
import json, sys
x = json.load(sys.stdin)
print(x.get("technical_status", ""), x.get("health_status", ""), x.get("effective_availability", ""), x.get("last_health_checked_at", ""))
')"
  printf 'poll=%s utc=%s node=%s/%s heartbeat=%s instance=%s/%s/%s checked=%s\n' \
    "$poll" "$(date -u +%FT%TZ)" "$node_status" "$node_health" "$heartbeat" \
    "$technical" "$health" "$availability" "$checked"
  if [[ $node_status == offline && $node_health == degraded && $availability == unavailable ]]; then
    partition_seen=true
    break
  fi
  sleep 10
done
[[ $partition_seen == true ]] || { echo "node/instance did not reach expected unavailable state within 150 seconds" >&2; exit 1; }

restore_peer
trap - EXIT INT TERM
printf 'partition_restored=%s\n' "$(date -u +%FT%TZ)"

rejoined=false
for poll in $(seq 1 12); do
  nodes=$(ssh_hub admiralctl nodes list --output json)
  instance=$(ssh_hub admiralctl instances show "$instance_id")
  read -r node_status node_health heartbeat <<<"$(printf '%s' "$nodes" | python3 -c '
import json, sys
node = next(x for x in json.load(sys.stdin) if x.get("id") == sys.argv[1])
print(node.get("status", ""), node.get("health_status", ""), node.get("last_heartbeat", ""))
' "$node_id")"
  read -r technical health availability <<<"$(printf '%s' "$instance" | python3 -c '
import json, sys
x = json.load(sys.stdin)
print(x.get("technical_status", ""), x.get("health_status", ""), x.get("effective_availability", ""))
')"
  printf 'rejoin_poll=%s utc=%s node=%s/%s heartbeat=%s instance=%s/%s/%s\n' \
    "$poll" "$(date -u +%FT%TZ)" "$node_status" "$node_health" "$heartbeat" \
    "$technical" "$health" "$availability"
  if [[ $node_status == active && $node_health == healthy && $availability == available ]]; then
    rejoined=true
    break
  fi
  sleep 10
done
[[ $rejoined == true ]] || { echo "node or instance did not recover within 120 seconds" >&2; exit 1; }
echo 'partition_detection_and_rejoin=PASS (scenario only; not a matrix-cell result)'
