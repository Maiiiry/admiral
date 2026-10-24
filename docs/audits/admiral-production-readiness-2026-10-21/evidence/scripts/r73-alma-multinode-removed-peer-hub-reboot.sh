#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Verify a revoked AlmaLinux worker peer stays absent across a real hub reboot.
set -euo pipefail
[[ $# -eq 6 ]] || { echo "usage: $0 SSH_KEY HUB_KNOWN_HOSTS HUB_IP HUB_GUEST REMAINING_W1_ID OUTPUT_DIR" >&2; exit 2; }
ssh_key=$1
hub_known=$2
hub_ip=$3
hub_guest=$4
w1_node=$5
out=$6
[[ $hub_guest == adm-r73-alma-mn-hub && $w1_node == adm-r73-alma-mn-w1 ]] || { echo 'unexpected AlmaLinux lab identity' >&2; exit 2; }
[[ $out == /* && ! -e $out ]] || { echo 'output directory must be an unused absolute path' >&2; exit 2; }
[[ -r $ssh_key && -r $hub_known ]] || { echo 'unreadable SSH input' >&2; exit 1; }
umask 077
mkdir -m 0700 -- "$out"
hub="validator@$hub_ip"
ssh_hub() {
  ssh -i "$ssh_key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=5 -o "UserKnownHostsFile=$hub_known" "$hub" "$@"
}
finish() {
  local rc=$?
  trap - EXIT
  printf 'exit_code=%s\n' "$rc" >"$out/exit-status.txt"
  find "$out" -maxdepth 1 -type f ! -name SHA256SUMS -exec chmod 0600 {} +
  (cd "$out" && find . -maxdepth 1 -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum >SHA256SUMS)
  chmod 0600 "$out/SHA256SUMS"
  exit "$rc"
}
trap finish EXIT

ssh_hub 'rpm -q --qf "%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n" admiral-common admirald admiral-fleet admiralctl admiral-flagship admiral-harbor | sort' >"$out/candidate-hub.txt"
[[ $(grep -c -- '-0.0.1rc5-73\.el10\.' "$out/candidate-hub.txt") -eq 6 ]]
ssh_hub 'sudo -u validator env HOME=/home/validator admiralctl nodes list --output json' >"$out/nodes-before-reboot.json"
python3 - "$out/nodes-before-reboot.json" "$w1_node" <<'PY'
import json,sys
data=json.load(open(sys.argv[1],encoding='utf-8'))
nodes=data if isinstance(data,list) else data.get('nodes',[])
if any(n.get('id')=='adm-r73-alma-mn-w2' for n in nodes): raise SystemExit('removed W2 remains registered before reboot')
w1=next((n for n in nodes if n.get('id')==sys.argv[2]),None)
if not w1 or w1.get('status')!='active' or w1.get('health_status')!='healthy' or w1.get('available_for_provisioning') is not True:
    raise SystemExit('remaining W1 is not active/healthy/available before reboot')
PY
ssh_hub sudo bash -s >"$out/wireguard-before-reboot.txt" <<'REMOTE'
set -euo pipefail
printf 'live_allowed_ips='
wg show wg-admiral allowed-ips | awk '{print $2}' | sort | paste -sd, -
printf 'persistent_allowed_ips='
awk '/^AllowedIPs[[:space:]]*=/{sub(/^.*=[[:space:]]*/,"");print}' /etc/wireguard/wg-admiral.conf | sort | paste -sd, -
REMOTE
grep -Fq '10.99.0.2/32' "$out/wireguard-before-reboot.txt"
if grep -Fq '10.99.0.3/32' "$out/wireguard-before-reboot.txt"; then echo 'removed peer exists before reboot' >&2; exit 1; fi
ssh_hub cat /proc/sys/kernel/random/boot_id >"$out/hub-boot-id-before.txt"
reboot_epoch=$(date -u +%s)
printf 'test_id=R73-ALMA-MN-REMOVED-PEER-HUB-REBOOT-01\ncandidate=0.0.1rc5-73.el10\nremoved_node=adm-r73-alma-mn-w2\nreboot_epoch=%s\n' "$reboot_epoch" >"$out/metadata.txt"
virsh reboot "$hub_guest" >"$out/virsh-reboot.log" 2>&1

ssh_ready=false
for attempt in $(seq 1 60); do
  if ssh_hub true >/dev/null 2>&1; then
    ssh_ready=true
    printf 'ssh_ready_poll=%s utc=%s\n' "$attempt" "$(date -u +%FT%TZ)" >"$out/ssh-recovery.txt"
    break
  fi
  sleep 5
done
[[ $ssh_ready == true ]] || { echo 'hub SSH did not return within five minutes' >&2; exit 1; }
ssh_hub cat /proc/sys/kernel/random/boot_id >"$out/hub-boot-id-after.txt"
[[ $(cat "$out/hub-boot-id-before.txt") != "$(cat "$out/hub-boot-id-after.txt")" ]] || { echo 'hub boot ID did not change' >&2; exit 1; }

recovered=false
for poll in $(seq 1 24); do
  ssh_hub sudo systemctl is-active admirald postgresql wg-quick@wg-admiral >"$out/services-$poll.txt" 2>&1 || true
  ssh_hub sudo wg show wg-admiral allowed-ips | awk '{print $2}' | sort >"$out/routes-$poll.txt" 2>/dev/null || : >"$out/routes-$poll.txt"
  ssh_hub sudo wg show wg-admiral latest-handshakes | awk '$2>0 && systime()-$2<300 {n++} END {print n+0}' >"$out/fresh-handshakes-$poll.txt" 2>/dev/null || echo 0 >"$out/fresh-handshakes-$poll.txt"
  if grep -Fxq '10.99.0.3/32' "$out/routes-$poll.txt"; then echo 'removed W2 route reappeared after reboot' >&2; exit 1; fi
  if ssh_hub 'sudo -u validator env HOME=/home/validator admiralctl nodes list --output json' >"$out/nodes-$poll.json" 2>/dev/null; then
    if python3 - "$out/nodes-$poll.json" "$w1_node" "$reboot_epoch" <<'PY'
import datetime,json,sys,time
data=json.load(open(sys.argv[1],encoding='utf-8'))
nodes=data if isinstance(data,list) else data.get('nodes',[])
if any(n.get('id')=='adm-r73-alma-mn-w2' for n in nodes): raise SystemExit(2)
hub=next((n for n in nodes if n.get('id')=='adm-r73-alma-mn-hub-portal'),None)
w1=next((n for n in nodes if n.get('id')==sys.argv[2]),None)
for node in (hub,w1):
    if not node or node.get('status')!='active' or node.get('health_status')!='healthy' or node.get('available_for_provisioning') is not True:
        raise SystemExit(1)
observed=w1.get('last_heartbeat')
if not observed: raise SystemExit(1)
stamp=datetime.datetime.fromisoformat(observed.replace('Z','+00:00')).timestamp()
if stamp<float(sys.argv[3]) or stamp>time.time()+5: raise SystemExit(1)
PY
    then
      if [[ $(sort -u "$out/services-$poll.txt" | paste -sd, -) == active ]] &&
         [[ $(cat "$out/routes-$poll.txt") == '10.99.0.2/32' ]] &&
         [[ $(cat "$out/fresh-handshakes-$poll.txt") -eq 1 ]]; then
        recovered=true
        cp "$out/nodes-$poll.json" "$out/nodes-after-reboot.json"
        printf 'recovery_poll=%s utc=%s\n' "$poll" "$(date -u +%FT%TZ)" >>"$out/metadata.txt"
        break
      fi
    else
      parse_rc=$?
      [[ $parse_rc -eq 2 ]] && { echo 'removed W2 node record reappeared after hub reboot' >&2; exit 1; }
    fi
  fi
  sleep 10
done
[[ $recovered == true ]] || { echo 'hub/W1 did not recover with only the W1 peer and no W2 record' >&2; exit 1; }
ssh_hub sudo bash -s >"$out/wireguard-after-reboot.txt" <<'REMOTE'
set -euo pipefail
printf 'live_allowed_ips='
wg show wg-admiral allowed-ips | awk '{print $2}' | sort | paste -sd, -
printf 'persistent_allowed_ips='
awk '/^AllowedIPs[[:space:]]*=/{sub(/^.*=[[:space:]]*/,"");print}' /etc/wireguard/wg-admiral.conf | sort | paste -sd, -
REMOTE
grep -Fq '10.99.0.2/32' "$out/wireguard-after-reboot.txt"
if grep -Fq '10.99.0.3/32' "$out/wireguard-after-reboot.txt"; then echo 'removed W2 peer reappeared in live or persistent state after reboot' >&2; exit 1; fi
printf 'finished_utc=%s\nresult=PASS-scoped\n' "$(date -u +%FT%TZ)" >>"$out/metadata.txt"
echo "removed_peer_survived_hub_reboot=PASS evidence=$out"
