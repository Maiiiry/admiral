#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Exercise R68 explicit workload placement, idempotency replay, runtime state,
# and cleanup on both workers of a real AlmaLinux 10 Multi-Node lab.
set -euo pipefail

[[ $# -eq 8 ]] || {
  echo "usage: $0 SSH_KEY HUB_KNOWN_HOSTS W1_KNOWN_HOSTS W2_KNOWN_HOSTS HUB_IP W1_IP W2_IP OUTPUT_DIR" >&2
  exit 2
}
ssh_key=$1 hub_known_hosts=$2 w1_known_hosts=$3 w2_known_hosts=$4
hub_ip=$5 w1_ip=$6 w2_ip=$7 output_dir=$8
[[ $output_dir == /* ]] || { echo 'OUTPUT_DIR must be absolute' >&2; exit 2; }
for path in "$ssh_key" "$hub_known_hosts" "$w1_known_hosts" "$w2_known_hosts"; do
  [[ -r $path ]] || { echo "unreadable SSH input: $path" >&2; exit 1; }
done

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../../.." && pwd)
fixture="$repo_root/examples/apps/e2e-whoami.yaml"
[[ -r $fixture ]] || { echo "fixture not found: $fixture" >&2; exit 1; }
install -d -m 0700 "$output_dir"
[[ -z $(find "$output_dir" -mindepth 1 -maxdepth 1 -print -quit) ]] || {
  echo "OUTPUT_DIR must be empty to avoid mixing evidence: $output_dir" >&2
  exit 2
}
umask 077
ssh_args=(-i "$ssh_key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=5)
hub_ssh_args=("${ssh_args[@]}" -o "UserKnownHostsFile=$hub_known_hosts")
w1_ssh_args=("${ssh_args[@]}" -o "UserKnownHostsFile=$w1_known_hosts")
w2_ssh_args=("${ssh_args[@]}" -o "UserKnownHostsFile=$w2_known_hosts")
hub="validator@$hub_ip"
active_instances="$output_dir/active-instances.txt"
run_id=$(date -u +%Y%m%d%H%M%S)
started_utc=$(date -u +%FT%TZ)
cleanup() {
  local rc=$?
  trap - EXIT
  if [[ -f $active_instances ]]; then
    while IFS= read -r instance_id; do
      [[ $instance_id =~ ^inst_[A-Za-z0-9]+$ ]] || continue
      if ! ssh "${hub_ssh_args[@]}" "$hub" \
        "sudo -u validator env HOME=/home/validator admiralctl instances deprovision '$instance_id' --force --wait --wait-timeout 10m --output json" \
        >"$output_dir/cleanup-$instance_id.json" 2>&1; then
        echo "cleanup failed for instance $instance_id" >&2
        rc=1
      fi
    done <"$active_instances"
  fi
  if ! ssh "${hub_ssh_args[@]}" "$hub" 'rm -f -- /tmp/r68-e2e-whoami-placement.yaml' \
    >"$output_dir/remote-fixture-cleanup.txt" 2>&1; then
    echo 'cleanup failed for uploaded workload definition' >&2
    rc=1
  fi
  printf 'exit_code=%s\nfinished_utc=%s\n' "$rc" "$(date -u +%FT%TZ)" >"$output_dir/exit-status.txt"
  find "$output_dir" -maxdepth 1 -type f ! -name SHA256SUMS -exec chmod 0600 {} +
  (cd "$output_dir" && find . -maxdepth 1 -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum >SHA256SUMS)
  chmod 0600 "$output_dir/SHA256SUMS"
  exit "$rc"
}
trap cleanup EXIT

printf 'test_id=R68-ALMA-MN-PLACEMENT-01\ncandidate=0.0.1rc5-68.el10\nroot_package_source_commit=4077c4ddb9d233682961d36c3570c63e70eb6405\nstarted_utc=%s\nhub=%s\nw1=%s\nw2=%s\n' \
  "$started_utc" "$hub_ip" "$w1_ip" "$w2_ip" >"$output_dir/metadata.txt"

ssh "${hub_ssh_args[@]}" "$hub" \
  'hostnamectl --static; cat /etc/os-release; uname -r; getenforce; rpm -q --qf "%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n" admiral-common admirald admiral-fleet admiralctl admiral-flagship admiral-harbor | sort' \
  >"$output_dir/hub-baseline.txt"
ssh "${w1_ssh_args[@]}" "validator@$w1_ip" \
  'hostnamectl --static; cat /etc/os-release; uname -r; getenforce; rpm -q --qf "%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n" admiral-common admiral-fleet | sort' \
  >"$output_dir/w1-baseline.txt"
ssh "${w2_ssh_args[@]}" "validator@$w2_ip" \
  'hostnamectl --static; cat /etc/os-release; uname -r; getenforce; rpm -q --qf "%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n" admiral-common admiral-fleet | sort' \
  >"$output_dir/w2-baseline.txt"
[[ $(grep -c -- '-0.0.1rc5-68\.el10\.' "$output_dir/hub-baseline.txt") -eq 6 ]]
[[ $(grep -c -- '-0.0.1rc5-68\.el10\.' "$output_dir/w1-baseline.txt") -eq 2 ]]
[[ $(grep -c -- '-0.0.1rc5-68\.el10\.' "$output_dir/w2-baseline.txt") -eq 2 ]]

ssh "${hub_ssh_args[@]}" "$hub" \
  'sudo -u validator env HOME=/home/validator admiralctl nodes list --output json' \
  >"$output_dir/nodes-before.json"
python3 - "$output_dir/nodes-before.json" <<'PY'
import json,sys
nodes=json.load(open(sys.argv[1],encoding='utf-8'))
expected={'adm-r68-alma-mn-w1','adm-r68-alma-mn-w2'}
found={n['id'] for n in nodes if n.get('status')=='active' and n.get('health_status')=='healthy' and n.get('available_for_provisioning')}
missing=expected-found
print(f'active_healthy_available_workers={len(found & expected)}')
if missing: raise SystemExit(f'precondition failed; workers missing: {sorted(missing)}')
PY

scp "${hub_ssh_args[@]}" "$fixture" "$hub:/tmp/r68-e2e-whoami-placement.yaml"
ssh "${hub_ssh_args[@]}" "$hub" \
  'sudo -u validator env HOME=/home/validator admiralctl apps apply --file /tmp/r68-e2e-whoami-placement.yaml' \
  >"$output_dir/app-apply.log" 2>&1

provision_one() {
  local label=$1 node_id=$2 expected_ip=$3 worker worker_args customer key provision_rc=0
  case "$label" in
    w1) worker="validator@$w1_ip"; worker_args=("${w1_ssh_args[@]}") ;;
    w2) worker="validator@$w2_ip"; worker_args=("${w2_ssh_args[@]}") ;;
    *) echo "invalid worker label: $label" >&2; return 2 ;;
  esac
  customer="r68-alma-${run_id}-${label}"
  key="r68-alma-${run_id}-${label}"
  echo "test=R68-ALMA-MN-PLACEMENT-$label start_utc=$(date -u +%FT%TZ) target=$node_id"

  ssh "${hub_ssh_args[@]}" "$hub" \
    "sudo -u validator env HOME=/home/validator admiralctl instances provision --app e2e-whoami --tier small --customer '$customer' --idempotency-key '$key' --node '$node_id' --wait --wait-timeout 10m --quiet --output json" \
    >"$output_dir/$label-provision.json" || provision_rc=$?
  local instance_id
  instance_id=$(python3 - "$output_dir/$label-provision.json" <<'PY' || true
import json,sys
try: value=json.load(open(sys.argv[1],encoding='utf-8')).get('instance_id','')
except (OSError,ValueError): value=''
print(value)
PY
)
  if [[ $instance_id =~ ^inst_[A-Za-z0-9]+$ ]]; then printf '%s\n' "$instance_id" >>"$active_instances"; fi
  if [[ $provision_rc -ne 0 ]]; then echo "provision failed with exit $provision_rc on $node_id" >&2; return "$provision_rc"; fi
  [[ $instance_id =~ ^inst_[A-Za-z0-9]+$ ]] || { echo "invalid instance ID: $instance_id" >&2; return 1; }
  python3 - "$output_dir/$label-provision.json" "$node_id" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
for k in ('id','instance_id','node_id','status','created_at','updated_at'): print(f'{k}={x.get(k)}')
if x.get('status')!='succeeded' or x.get('node_id')!=sys.argv[2]: raise SystemExit('operation did not succeed on requested node')
PY

  ssh "${hub_ssh_args[@]}" "$hub" \
    "sudo -u validator env HOME=/home/validator admiralctl instances provision --app e2e-whoami --tier small --customer '$customer' --idempotency-key '$key' --node '$node_id' --wait --wait-timeout 2m --quiet --output json" \
    >"$output_dir/$label-replay.json"
  python3 - "$output_dir/$label-provision.json" "$output_dir/$label-replay.json" <<'PY'
import json,sys
a,b=(json.load(open(p,encoding='utf-8')) for p in sys.argv[1:])
same=a.get('id')==b.get('id') and a.get('instance_id')==b.get('instance_id')
print(f'idempotency_replay_same_operation_and_instance={same}')
if not same: raise SystemExit('same-key replay created or returned a different operation/instance')
PY

  local converged=0 attempt
  for attempt in $(seq 1 60); do
    if ssh "${hub_ssh_args[@]}" "$hub" \
      "sudo -u validator env HOME=/home/validator admiralctl instances show '$instance_id'" \
      >"$output_dir/$label-instance.json" 2>"$output_dir/$label-instance-error.log" && \
      python3 - "$output_dir/$label-instance.json" "$node_id" "$attempt" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
for k in ('id','node_id','technical_status','health_status','effective_availability','availability_reason','last_health_checked_at'): print(f'{k}={x.get(k)}')
if x.get('node_id')!=sys.argv[2]: raise SystemExit('instance placed on the wrong node')
if x.get('health_status')=='healthy' and x.get('effective_availability')=='available':
 print(f'health_converged_poll={sys.argv[3]}'); raise SystemExit(0)
raise SystemExit(1)
PY
    then converged=1; break; fi
    sleep 5
  done
  [[ $converged -eq 1 ]] || { echo "instance $instance_id did not become healthy/available within 5 minutes" >&2; return 1; }

  ssh "${worker_args[@]}" "$worker" sudo bash -s -- "$instance_id" "$expected_ip" \
    >"$output_dir/$label-runtime.txt" <<'REMOTE'
set -euo pipefail
instance_id=$1 expected_ip=$2
uid=$(id -u admiral-apps)
podman_as_apps() {
  runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" podman "$@"
}
app="admiral-${instance_id}-app" db="admiral-${instance_id}-db"
for attempt in $(seq 1 60); do
  if podman_as_apps exec "$db" sh -c \
    'export PGPASSWORD="$POSTGRES_PASSWORD"; pg_isready -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' >/dev/null 2>&1; then
    printf 'database_ready_attempt=%s utc=%s\n' "$attempt" "$(date -u +%FT%TZ)"; break
  fi
  [[ $attempt -lt 60 ]] || { echo 'database not ready after 5 minutes'; exit 1; }
  sleep 5
done
podman_as_apps ps --all --filter "name=$instance_id" --format '{{.Names}}|{{.Status}}|{{.Ports}}'
endpoint=$(podman_as_apps port "$app" 80/tcp | head -n1)
[[ $endpoint =~ ^([0-9.]+):([0-9]+)$ ]] || { echo "unexpected mapped endpoint: $endpoint"; exit 1; }
[[ ${BASH_REMATCH[1]} == "$expected_ip" ]] || { echo "unexpected bind address: $endpoint"; exit 1; }
printf 'app_endpoint=%s\n' "$endpoint"
marker="r68-alma-${instance_id}"
sql="CREATE TABLE IF NOT EXISTS admiral_audit_marker (value TEXT PRIMARY KEY); INSERT INTO admiral_audit_marker(value) VALUES ('$marker') ON CONFLICT DO NOTHING; SELECT value FROM admiral_audit_marker WHERE value = '$marker';"
podman_as_apps exec "$db" sh -c \
  'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "$1"' \
  sh "$sql"
REMOTE
  local endpoint http_code
  endpoint=$(sed -n 's/^app_endpoint=//p' "$output_dir/$label-runtime.txt" | tail -n1)
  [[ $endpoint =~ ^10.99.0.[23]:[0-9]+$ ]] || { echo "invalid workload endpoint: $endpoint" >&2; return 1; }
  http_code=$(ssh "${hub_ssh_args[@]}" "$hub" \
    "curl --connect-timeout 3 --max-time 10 -sS -o /dev/null -w '%{http_code}' 'http://$endpoint/'")
  printf 'hub_to_workload_http_status=%s endpoint=%s\n' "$http_code" "$endpoint" | tee "$output_dir/$label-http.txt"
  [[ $http_code == 200 ]] || { echo 'hub could not reach workload endpoint' >&2; return 1; }

  ssh "${hub_ssh_args[@]}" "$hub" \
    "sudo -u validator env HOME=/home/validator admiralctl instances deprovision '$instance_id' --force --wait --wait-timeout 10m --output json" \
    >"$output_dir/$label-deprovision.json"
  python3 - "$output_dir/$label-deprovision.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print(f"deprovision_operation={x.get('id')} status={x.get('status')}")
if x.get('status')!='succeeded': raise SystemExit('deprovision did not succeed')
PY
  grep -vxF "$instance_id" "$active_instances" >"$active_instances.tmp" || true
  mv "$active_instances.tmp" "$active_instances"
  ssh "${worker_args[@]}" "$worker" sudo bash -s -- "$instance_id" \
    >"$output_dir/$label-cleanup.txt" <<'REMOTE'
set -euo pipefail
instance_id=$1 uid=$(id -u admiral-apps)
podman_as_apps() { runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" podman "$@"; }
containers=$(podman_as_apps ps -a --filter "name=$instance_id" --format '{{.Names}}')
pods=$(podman_as_apps pod ps --format '{{.Name}}' | grep -F "$instance_id" || true)
volumes=$(podman_as_apps volume ls --format '{{.Name}}' | grep -F "$instance_id" || true)
units=$(runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" systemctl --user list-unit-files --no-legend | grep -F "$instance_id" || true)
files=$(find /etc/containers/systemd /var/lib/admiral -iname "*$instance_id*" -print 2>/dev/null || true)
printf 'remaining_containers=%s\nremaining_pods=%s\nremaining_volumes=%s\nremaining_units=%s\nremaining_files=%s\n' \
  "${containers:-none}" "${pods:-none}" "${volumes:-none}" "${units:-none}" "${files:-none}"
[[ -z $containers && -z $pods && -z $volumes && -z $units && -z $files ]]
REMOTE
  printf 'placement_lifecycle_%s=PASS instance=%s end_utc=%s\n' "$label" "$instance_id" "$(date -u +%FT%TZ)"
}

provision_one w1 adm-r68-alma-mn-w1 10.99.0.2
provision_one w2 adm-r68-alma-mn-w2 10.99.0.3

ssh "${hub_ssh_args[@]}" "$hub" \
  'sudo -u validator env HOME=/home/validator admiralctl nodes list --output json' \
  >"$output_dir/nodes-after.json"
python3 - "$output_dir/nodes-after.json" <<'PY'
import json,sys
nodes=json.load(open(sys.argv[1],encoding='utf-8'))
for node_id in ('adm-r68-alma-mn-w1','adm-r68-alma-mn-w2'):
 n=next((x for x in nodes if x.get('id')==node_id),None)
 print(f"{node_id}: status={n.get('status') if n else None} health={n.get('health_status') if n else None} available={n.get('available_for_provisioning') if n else None}")
 if not n or n.get('status')!='active' or n.get('health_status')!='healthy' or not n.get('available_for_provisioning'):
  raise SystemExit(f'worker did not remain healthy and available: {node_id}')
PY

printf 'result=PASS_SCOPED\nfinished_utc=%s\n' "$(date -u +%FT%TZ)" >"$output_dir/result.txt"
echo 'R68-ALMA-MN-PLACEMENT-01=PASS_SCOPED'
