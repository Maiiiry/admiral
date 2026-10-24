#!/usr/bin/env bash
set -euo pipefail
root=/var/lib/libvirt/images/admiral-validation
key=$root/keys/rc5-r73-validator.ed25519
hub_known=$root/cloud-init/adm-r73-alma-mn-hub/known_hosts
w2_known=$root/cloud-init/adm-r73-alma-mn-w2/known_hosts
hub=validator@10.77.0.23
w2=validator@10.77.0.25
ssh_hub=(ssh -i "$key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$hub_known" "$hub")
ssh_w2=(ssh -i "$key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$w2_known" "$w2")
umask 077
pub=$("${ssh_w2[@]}" sudo wg show wg-admiral public-key)
[[ $pub =~ ^[A-Za-z0-9+/]{43}=$ ]]
if "${ssh_hub[@]}" sudo wg show wg-admiral peers | grep -Fxq "$pub"; then
  echo 'W2 peer unexpectedly remains live after node removal' >&2; exit 1
fi
if "${ssh_hub[@]}" sudo bash -c 'grep -RFl -- "$1" /etc/wireguard 2>/dev/null || true' _ "$pub" | grep -q .; then
  echo 'W2 public key remains in persistent WireGuard configuration after node removal' >&2; exit 1
fi
printf 'precondition_live_peer_absent=yes\nprecondition_persistent_peer_absent=yes\n' > precondition.txt
"${ssh_hub[@]}" sudo wg set wg-admiral peer "$pub" allowed-ips 10.99.0.3/32
cleanup() {
  local rc=$?
  trap - EXIT
  "${ssh_hub[@]}" sudo wg set wg-admiral peer "$pub" remove >/dev/null 2>&1 || rc=1
  if "${ssh_hub[@]}" sudo wg show wg-admiral peers | grep -Fxq "$pub"; then
    echo 'temporary validation peer remains on hub' >&2; rc=1
  else
    echo 'temporary_validation_peer_removed=yes' >> peer-cleanup.txt
  fi
  exit "$rc"
}
trap cleanup EXIT
handshake=0
for attempt in $(seq 1 35); do
  latest=$("${ssh_hub[@]}" sudo wg show wg-admiral latest-handshakes | awk -v p="$pub" '$1==p {print $2}')
  now=$(date +%s)
  if [[ $latest =~ ^[0-9]+$ ]] && (( latest > 0 && now-latest <= 10 )); then
    printf 'wireguard_handshake_attempt=%s age_seconds=%s\n' "$attempt" "$((now-latest))" > handshake.txt
    handshake=1; break
  fi
  sleep 1
done
[[ $handshake == 1 ]] || { echo 'temporary W2 WireGuard peer did not handshake within 35 seconds' >&2; exit 1; }
"${ssh_w2[@]}" sudo bash -s > old-token-response.txt <<'REMOTE'
set -euo pipefail
set -a
. /etc/admiral/fleet.env
set +a
python3 - <<'PY'
import json,os,ssl,urllib.error,urllib.request
url=os.environ['ADMIRAL_API_URL'].rstrip('/')+'/api/v1/nodes/heartbeat'
body=json.dumps({'node_id':os.environ['ADMIRAL_FLEET_NODE_ID'],'boot_id':'release-validation-after-node-removal','status':'active'}).encode()
ctx=ssl.create_default_context(cafile=os.environ['ADMIRAL_API_CA_FILE'])
req=urllib.request.Request(url,data=body,headers={'Authorization':'Bearer '+os.environ['ADMIRAL_FLEET_TOKEN'],'Content-Type':'application/json'},method='POST')
try:
    with urllib.request.urlopen(req,context=ctx,timeout=10) as response:
        status=response.status
except urllib.error.HTTPError as error:
    status=error.code
print(f'http_status={status}')
if status != 401:
    raise SystemExit('removed worker token was not rejected with HTTP 401')
PY
REMOTE
chmod 0600 precondition.txt handshake.txt old-token-response.txt
printf 'result=PASS old Fleet token rejected after node removal\n' > result.txt
