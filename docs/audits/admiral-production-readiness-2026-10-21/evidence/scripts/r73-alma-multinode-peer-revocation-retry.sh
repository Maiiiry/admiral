#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Inject a temporary revocation-helper failure, verify fail-closed retention,
# restore the packaged helper, retry removal, and re-enroll the AlmaLinux worker.
set -euo pipefail
[[ $# -eq 10 ]] || {
  echo "usage: $0 SSH_KEY HUB_KNOWN WORKER_KNOWN HUB_UNDERLAY HUB_WIREGUARD WORKER_UNDERLAY NODE_ID WORKER_WIREGUARD WORKER_HOST_FINGERPRINT OUTPUT_DIR" >&2
  exit 2
}
ssh_key=$1 hub_known=$2 worker_known=$3 hub_underlay=$4 hub_wireguard=$5 worker_underlay=$6 node_id=$7 worker_wireguard=$8 host_fingerprint=$9 out=${10}
[[ $node_id == adm-r73-alma-mn-w2 && $worker_wireguard == 10.99.0.3 && $hub_wireguard == 10.99.0.1 ]] || {
  echo 'expected the disposable Release 73 AlmaLinux W2 and its lab WireGuard addresses' >&2
  exit 2
}
[[ $out == /* && ! -e $out ]] || { echo 'output path must be absolute and unused' >&2; exit 2; }
for path in "$ssh_key" "$hub_known" "$worker_known"; do [[ -r $path ]] || { echo "unreadable input: $path" >&2; exit 1; }; done
[[ $host_fingerprint =~ ^SHA256:[A-Za-z0-9+/]+$ ]] || { echo 'invalid worker SSH host-key fingerprint' >&2; exit 2; }
repo_root=${ADMIRAL_REPO_ROOT:-/root/admiral}
reenroll_helper="$repo_root/docs/audits/admiral-production-readiness-2026-10-21/scripts/install-worker-audit.sh"
[[ -x $reenroll_helper ]] || { echo "worker installer helper not found: $reenroll_helper" >&2; exit 1; }
umask 077
mkdir -m 0700 -- "$out"
ssh_args=(-i "$ssh_key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=5)
hub="validator@$hub_underlay" worker="validator@$worker_underlay"
ssh_hub() { ssh "${ssh_args[@]}" -o "UserKnownHostsFile=$hub_known" "$hub" "$@"; }
ssh_worker() { ssh "${ssh_args[@]}" -o "UserKnownHostsFile=$worker_known" "$worker" "$@"; }
dropin=/run/systemd/system/admiral-wireguard-peer-revoke@.service.d
fake_helper=/run/admiral-audit-fail-peer-revoke
injection_active=0
reenroll_needed=0

restore_helper() {
  ssh_hub sudo bash -s >"$out/helper-restoration.txt" 2>&1 <<'REMOTE'
set -euo pipefail
rm -rf /run/systemd/system/admiral-wireguard-peer-revoke@.service.d
rm -f /run/admiral-audit-fail-peer-revoke
systemctl daemon-reload
systemctl restart admiral-wireguard-peer-revoke.socket
systemctl is-active admiral-wireguard-peer-revoke.socket
systemctl cat 'admiral-wireguard-peer-revoke@.service'
REMOTE
  injection_active=0
}

reenroll_worker() {
  local log="$out/re-enrollment.log"
  if ssh_hub "sudo -u validator env HOME=/home/validator admiralctl nodes show '$node_id'" >"$out/node-before-re-enrollment.json" 2>/dev/null; then
    reenroll_needed=0
    return 0
  fi
  "$reenroll_helper" "$ssh_key" "$hub_known" "$worker_known" "$hub_underlay" "$hub_wireguard" "$worker_underlay" "$node_id" "$worker_wireguard" "$host_fingerprint" "$log" >"$out/re-enrollment-summary.txt" 2>&1
  ssh_hub 'sudo -u validator env HOME=/home/validator admiralctl nodes show adm-r73-alma-mn-w2' >"$out/node-after-re-enrollment.json"
  python3 - "$out/node-after-re-enrollment.json" <<'PY'
import json,sys
n=json.load(open(sys.argv[1],encoding='utf-8'))
if n.get('id')!='adm-r73-alma-mn-w2' or n.get('status')!='active' or n.get('health_status')!='healthy' or n.get('available_for_provisioning') is not True:
    raise SystemExit('W2 did not return active/healthy/available after re-enrollment')
PY
  ssh_hub sudo bash -s >"$out/post-re-enrollment-wireguard.txt" <<'REMOTE'
set -euo pipefail
printf 'live_allowed_ips='
wg show wg-admiral allowed-ips | awk '{print $2}' | sort | paste -sd, -
printf 'persistent_allowed_ips='
awk '/^AllowedIPs[[:space:]]*=/{sub(/^.*=[[:space:]]*/,"");print}' /etc/wireguard/wg-admiral.conf | sort | paste -sd, -
REMOTE
  grep -Fq '10.99.0.3/32' "$out/post-re-enrollment-wireguard.txt"
  ssh_worker 'rpm -q --qf "%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n" admiral-common admiral-fleet | sort' >"$out/candidate-worker-after-re-enrollment.txt"
  [[ $(grep -c -- '-0.0.1rc5-73\.el10\.' "$out/candidate-worker-after-re-enrollment.txt") -eq 2 ]]
  reenroll_needed=0
}

finish() {
  local rc=$?
  trap - EXIT
  if [[ $injection_active -eq 1 ]]; then
    restore_helper || { printf 'cleanup=failed_to_restore_packaged_revocation_helper\n' >>"$out/cleanup-status.txt"; [[ $rc -ne 0 ]] || rc=1; }
  fi
  if [[ $reenroll_needed -eq 1 ]]; then
    reenroll_worker || { printf 'cleanup=failed_to_reenroll_removed_worker\n' >>"$out/cleanup-status.txt"; [[ $rc -ne 0 ]] || rc=1; }
  fi
  printf 'exit_code=%s\n' "$rc" >"$out/exit-status.txt"
  find "$out" -maxdepth 1 -type f ! -name SHA256SUMS -exec chmod 0600 {} +
  (cd "$out" && find . -maxdepth 1 -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum >SHA256SUMS)
  chmod 0600 "$out/SHA256SUMS"
  exit "$rc"
}
trap finish EXIT

ssh_hub 'rpm -q --qf "%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n" admiral-common admirald admiral-fleet admiralctl admiral-flagship admiral-harbor | sort' >"$out/candidate-hub.txt"
ssh_worker 'rpm -q --qf "%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n" admiral-common admiral-fleet | sort' >"$out/candidate-worker-before.txt"
[[ $(grep -c -- '-0.0.1rc5-73\.el10\.' "$out/candidate-hub.txt") -eq 6 ]]
[[ $(grep -c -- '-0.0.1rc5-73\.el10\.' "$out/candidate-worker-before.txt") -eq 2 ]]
ssh_hub 'sudo -u validator env HOME=/home/validator admiralctl nodes list --output json' >"$out/nodes-before.json"
ssh_hub 'sudo -u validator env HOME=/home/validator admiralctl instances list --output json' >"$out/instances-before.json"
python3 - "$out/nodes-before.json" "$out/instances-before.json" "$node_id" <<'PY'
import json,sys
data=json.load(open(sys.argv[1],encoding='utf-8')); nodes=data if isinstance(data,list) else data.get('nodes',[])
w2=next((n for n in nodes if n.get('id')==sys.argv[3]),None)
if not w2 or w2.get('status')!='active' or w2.get('health_status')!='healthy' or not w2.get('available_for_provisioning'):
    raise SystemExit('W2 must start active/healthy/available')
instances=json.load(open(sys.argv[2],encoding='utf-8'))
assigned=[i for i in instances if i.get('node_id')==sys.argv[3] and i.get('technical_status') not in ('deprovisioned','failed')]
if assigned: raise SystemExit(f'W2 has {len(assigned)} workload(s) that are not deprovisioned')
PY
ssh_hub sudo -u postgres psql -d admiral -AtX >"$out/worker-token-fingerprint-before.txt" <<SQL
SELECT token_type || ':' || token_status || ':' || length(token_hash)::text || ':' || md5(token_hash)
FROM node_tokens WHERE node_id='$node_id' AND token_type='worker';
SQL
grep -Eq '^worker:active:[0-9]+:[0-9a-f]{32}$' "$out/worker-token-fingerprint-before.txt"
ssh_hub sudo bash -s >"$out/wireguard-before.txt" <<'REMOTE'
set -euo pipefail
printf 'live_allowed_ips='
wg show wg-admiral allowed-ips | awk '{print $2}' | sort | paste -sd, -
printf 'persistent_allowed_ips='
awk '/^AllowedIPs[[:space:]]*=/{sub(/^.*=[[:space:]]*/,"");print}' /etc/wireguard/wg-admiral.conf | sort | paste -sd, -
REMOTE
grep -Fq '10.99.0.3/32' "$out/wireguard-before.txt"
ssh_hub sudo systemctl is-active admiral-wireguard-peer-revoke.socket >"$out/revocation-socket-before.txt"
ssh_hub sudo systemctl cat 'admiral-wireguard-peer-revoke@.service' >"$out/packaged-revocation-service.txt"

reenroll_needed=1
test_started=$(date -u +%FT%TZ)
ssh_hub sudo bash -s >"$out/failure-injection-setup.txt" 2>&1 <<'REMOTE'
set -euo pipefail
install -d -m 0755 /run/systemd/system/admiral-wireguard-peer-revoke@.service.d
cat >/run/admiral-audit-fail-peer-revoke <<'SH'
#!/bin/sh
IFS= read -r address || exit 2
printf 'injected peer revocation failure for %s\n' "$address" >&2
printf '{"success":false,"error":"injected helper failure"}\n'
SH
chmod 0755 /run/admiral-audit-fail-peer-revoke
cat >/run/systemd/system/admiral-wireguard-peer-revoke@.service.d/override.conf <<'UNIT'
[Service]
ExecStart=
ExecStart=/run/admiral-audit-fail-peer-revoke
UNIT
chmod 0644 /run/systemd/system/admiral-wireguard-peer-revoke@.service.d/override.conf
systemctl daemon-reload
systemctl restart admiral-wireguard-peer-revoke.socket
systemctl is-active admiral-wireguard-peer-revoke.socket
systemctl cat 'admiral-wireguard-peer-revoke@.service'
REMOTE
injection_active=1
set +e
ssh_hub sudo -u validator env HOME=/home/validator admiralctl nodes remove "$node_id" >"$out/remove-with-injected-helper-failure.txt" 2>&1 <<'REMOTE'
y
REMOTE
remove_rc=$?
set -e
printf 'command_exit=%s\n' "$remove_rc" >>"$out/remove-with-injected-helper-failure.txt"
[[ $remove_rc -ne 0 ]]
grep -Fq 'HTTP 503' "$out/remove-with-injected-helper-failure.txt"
ssh_hub sudo journalctl --since "$test_started" --no-pager --output=cat >"$out/helper-failure-journal.txt"
grep -Fq 'injected peer revocation failure for 10.99.0.3' "$out/helper-failure-journal.txt"
ssh_hub "sudo -u validator env HOME=/home/validator admiralctl nodes show '$node_id'" >"$out/node-after-injected-failure.json"
python3 - "$out/node-after-injected-failure.json" <<'PY'
import json,sys
n=json.load(open(sys.argv[1],encoding='utf-8'))
if n.get('id')!='adm-r73-alma-mn-w2' or n.get('status')!='active' or n.get('health_status')!='healthy' or n.get('available_for_provisioning') is not True:
    raise SystemExit('failed revocation did not retain the active worker')
PY
ssh_hub sudo -u postgres psql -d admiral -AtX >"$out/worker-token-fingerprint-after-failure.txt" <<SQL
SELECT token_type || ':' || token_status || ':' || length(token_hash)::text || ':' || md5(token_hash)
FROM node_tokens WHERE node_id='$node_id' AND token_type='worker';
SQL
cmp -s "$out/worker-token-fingerprint-before.txt" "$out/worker-token-fingerprint-after-failure.txt"
ssh_hub sudo wg show wg-admiral allowed-ips >"$out/live-wireguard-after-failure.txt"
grep -Fq '10.99.0.3/32' "$out/live-wireguard-after-failure.txt"
ssh_hub "sudo grep -F 'AllowedIPs = 10.99.0.3/32' /etc/wireguard/wg-admiral.conf" >"$out/persistent-wireguard-after-failure.txt"
ssh_hub 'sudo -u validator env HOME=/home/validator admiralctl nodes list --output json' >"$out/nodes-after-failure.json"
python3 - "$out/nodes-after-failure.json" <<'PY'
import json,sys
data=json.load(open(sys.argv[1],encoding='utf-8')); nodes=data if isinstance(data,list) else data.get('nodes',[])
for node_id in ('adm-r73-alma-mn-hub-portal','adm-r73-alma-mn-w1','adm-r73-alma-mn-w2'):
    node=next((n for n in nodes if n.get('id')==node_id),None)
    if not node or node.get('status')!='active' or node.get('health_status')!='healthy' or not node.get('available_for_provisioning'):
        raise SystemExit(f'{node_id} is not active/healthy/available after failed revocation')
PY

restore_helper
grep -Fq '/usr/libexec/admiral-wireguard-revoke-peer' "$out/helper-restoration.txt"
reenroll_needed=1
ssh_hub sudo -u validator env HOME=/home/validator admiralctl nodes remove "$node_id" >"$out/retry-remove-after-helper-restoration.txt" 2>&1 <<'REMOTE'
y
REMOTE
grep -Fq "Node \"$node_id\" removed." "$out/retry-remove-after-helper-restoration.txt"
ssh_hub sudo bash -s >"$out/wireguard-after-retry.txt" <<'REMOTE'
set -euo pipefail
printf 'live_allowed_ips='
wg show wg-admiral allowed-ips | awk '{print $2}' | sort | paste -sd, -
printf 'persistent_allowed_ips='
awk '/^AllowedIPs[[:space:]]*=/{sub(/^.*=[[:space:]]*/,"");print}' /etc/wireguard/wg-admiral.conf | sort | paste -sd, -
REMOTE
if grep -Fq '10.99.0.3/32' "$out/wireguard-after-retry.txt"; then echo 'W2 peer remains after the successful retry' >&2; exit 1; fi
ssh_hub sudo -u postgres psql -d admiral -AtX >"$out/node-row-count-after-retry.txt" <<SQL
SELECT count(*) FROM nodes WHERE id='$node_id';
SQL
ssh_hub sudo -u postgres psql -d admiral -AtX >"$out/node-token-row-count-after-retry.txt" <<SQL
SELECT count(*) FROM node_tokens WHERE node_id='$node_id';
SQL
[[ $(cat "$out/node-row-count-after-retry.txt") == 0 && $(cat "$out/node-token-row-count-after-retry.txt") == 0 ]]
ssh_hub 'sudo -u validator env HOME=/home/validator admiralctl nodes list --output json' >"$out/nodes-after-retry.json"
python3 - "$out/nodes-after-retry.json" <<'PY'
import json,sys
data=json.load(open(sys.argv[1],encoding='utf-8')); nodes=data if isinstance(data,list) else data.get('nodes',[])
if any(n.get('id')=='adm-r73-alma-mn-w2' for n in nodes): raise SystemExit('W2 still appears after successful retry')
w1=next((n for n in nodes if n.get('id')=='adm-r73-alma-mn-w1'),None)
if not w1 or w1.get('status')!='active' or w1.get('health_status')!='healthy' or not w1.get('available_for_provisioning'):
    raise SystemExit('W1 did not remain active/healthy/available after successful retry')
PY
reenroll_needed=1
reenroll_worker
printf 'test_id=R73-ALMA-MN-PEER-REVOCATION-RETRY-01\ncandidate=0.0.1rc5-73.el10\nstarted_utc=%s\nresult=PASS-scoped\nfinished_utc=%s\n' "$test_started" "$(date -u +%FT%TZ)" >"$out/metadata.txt"
echo "result=PASS scoped evidence=$out"
