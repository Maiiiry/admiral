#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Checksum-verified local PostgreSQL backup/restore on an R67 CentOS Stream Multi-Node worker.
set -Eeuo pipefail

[[ $# -eq 9 ]] || {
  echo "usage: $0 SSH_KEY HUB_KNOWN_HOSTS WORKER_KNOWN_HOSTS HUB_IP WORKER_IP NODE_ID WORKER_WG_IP RUN_SUFFIX OUTPUT_DIR" >&2
  exit 2
}
ssh_key=$1 hub_known_hosts=$2 worker_known_hosts=$3 hub_ip=$4 worker_ip=$5
node_id=$6 worker_wg_ip=$7 suffix=$8 output_dir=$9
[[ $node_id =~ ^[a-z0-9][a-z0-9-]{0,62}$ ]] || { echo 'invalid node id' >&2; exit 2; }
[[ $worker_wg_ip =~ ^10\.99\.0\.[23]$ ]] || { echo 'invalid WireGuard worker address' >&2; exit 2; }
[[ $suffix =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,40}$ ]] || { echo 'invalid run suffix' >&2; exit 2; }
[[ $output_dir = /* && ! -e $output_dir ]] || { echo 'output directory must be an unused absolute path' >&2; exit 2; }
for path in "$ssh_key" "$hub_known_hosts" "$worker_known_hosts"; do
  [[ -r $path ]] || { echo "unreadable SSH input: $path" >&2; exit 1; }
done

audit_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture="$audit_dir/fixtures/e2e-backup.yaml"
[[ -r $fixture ]] || { echo "backup fixture not found: $fixture" >&2; exit 1; }
umask 077
mkdir -m 0700 -- "$output_dir"
ssh_args=(-i "$ssh_key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=5)
hub_args=("${ssh_args[@]}" -o "UserKnownHostsFile=$hub_known_hosts")
worker_args=("${ssh_args[@]}" -o "UserKnownHostsFile=$worker_known_hosts")
hub="validator@$hub_ip" worker="validator@$worker_ip"
fixture_remote="/tmp/r67-${suffix}-e2e-backup.yaml"
customer="r67-backup-${suffix}"
idempotency_key="r67-backup-${suffix}"
instance_id= backup_id=

hub_admiralctl() {
  local command=$1
  ssh "${hub_args[@]}" "$hub" "sudo -u validator env HOME=/home/validator admiralctl $command"
}
cleanup() {
  local rc=$?
  trap - EXIT
  if [[ -n $instance_id ]]; then
    hub_admiralctl "instances resume '$instance_id' --wait --wait-timeout 5m --output json" \
      >"$output_dir/final-resume-on-exit.json" 2>&1 || true
  fi
  if [[ -n $backup_id ]]; then
    printf 'y\n' | hub_admiralctl "backups delete '$backup_id'" \
      >"$output_dir/final-backup-delete-on-exit.txt" 2>&1 || true
  fi
  if [[ -n $instance_id ]]; then
    hub_admiralctl "instances deprovision '$instance_id' --force --wait --wait-timeout 10m --output json" \
      >"$output_dir/final-deprovision-on-exit.json" 2>&1 || true
  fi
  exit "$rc"
}
trap cleanup EXIT

echo "test=R67-CENTOS-MN-LOCAL-BACKUP-RESTORE start_utc=$(date -u +%FT%TZ) node=$node_id"
scp "${hub_args[@]}" "$fixture" "$hub:$fixture_remote"
hub_admiralctl "apps apply --file '$fixture_remote'" >"$output_dir/app-apply.log" 2>&1
hub_admiralctl \
  "instances provision --app e2e-backup --tier small --customer '$customer' --idempotency-key '$idempotency_key' --node '$node_id' --wait --wait-timeout 10m --quiet --output json" \
  >"$output_dir/provision.json"
instance_id=$(python3 - "$output_dir/provision.json" "$node_id" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
if x.get('status')!='succeeded' or x.get('node_id')!=sys.argv[2] or not x.get('instance_id'):
    raise SystemExit('backup fixture did not provision on requested worker')
print(x['instance_id'])
PY
)
[[ $instance_id =~ ^inst_[A-Za-z0-9]+$ ]] || { echo 'invalid instance id'; exit 1; }
marker="r67-${suffix}-${instance_id}"

wait_for_instance() {
  local file=$1 attempt fields tech health avail
  for attempt in $(seq 1 30); do
    hub_admiralctl "instances show '$instance_id'" >"$output_dir/$file.json"
    fields=$(python3 - "$output_dir/$file.json" "$node_id" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print(x.get('node_id',''),x.get('technical_status',''),x.get('health_status',''),x.get('effective_availability',''))
if x.get('node_id')!=sys.argv[2]: raise SystemExit('instance is assigned to an unexpected node')
PY
)
    read -r _ tech health avail <<<"$fields"
    printf 'health_poll=%s utc=%s %s\n' "$attempt" "$(date -u +%FT%TZ)" "$fields" >>"$output_dir/health-timeline.txt"
    [[ $tech == running && $health == healthy && $avail == available ]] && return 0
    sleep 5
  done
  echo "instance did not become running/healthy/available: $file" >&2
  return 1
}
wait_for_instance pre-backup-state

ssh "${worker_args[@]}" "$worker" sudo bash -s -- "$instance_id" "$marker" insert \
  >"$output_dir/marker-before-backup.txt" <<'REMOTE'
set -euo pipefail
cd /tmp
instance_id=$1 marker=$2 action=$3
uid=$(id -u admiral-apps)
podman_as_apps() {
  runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" podman "$@"
}
db="admiral-${instance_id}-db"
for attempt in $(seq 1 60); do
  if podman_as_apps exec "$db" sh -c \
    'export PGPASSWORD="$POSTGRES_PASSWORD"; pg_isready -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' >/dev/null 2>&1; then
    printf 'database_ready_attempt=%s utc=%s\n' "$attempt" "$(date -u +%FT%TZ)"
    break
  fi
  [[ $attempt -lt 60 ]] || { echo 'worker PostgreSQL did not become ready'; exit 1; }
  sleep 5
done
if [[ $action == insert ]]; then
  sql="CREATE TABLE IF NOT EXISTS admiral_audit_marker (value TEXT PRIMARY KEY); TRUNCATE admiral_audit_marker; INSERT INTO admiral_audit_marker(value) VALUES ('$marker'); SELECT value FROM admiral_audit_marker;"
elif [[ $action == mutate ]]; then
  sql="UPDATE admiral_audit_marker SET value='mutated-after-backup'; SELECT value FROM admiral_audit_marker;"
elif [[ $action == query ]]; then
  sql="SELECT value FROM admiral_audit_marker;"
else
  echo 'invalid SQL probe action'; exit 2
fi
podman_as_apps exec "$db" sh -c \
  'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -v ON_ERROR_STOP=1 -c "$1"' \
  sh "$sql"
REMOTE
grep -Fx "$marker" "$output_dir/marker-before-backup.txt" >/dev/null || { echo 'marker insert did not return expected value'; exit 1; }

endpoint=$(ssh "${worker_args[@]}" "$worker" sudo bash -s -- "$instance_id" <<'REMOTE'
set -euo pipefail
cd /tmp
uid=$(id -u admiral-apps)
runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
  podman port "admiral-$1-app" 80/tcp | head -n1
REMOTE
)
[[ $endpoint =~ ^${worker_wg_ip//./\.}:[0-9]+$ ]] || { echo "unexpected app endpoint: $endpoint" >&2; exit 1; }
http_before=$(ssh "${hub_args[@]}" "$hub" \
  "curl --connect-timeout 3 --max-time 10 -sS -o /dev/null -w '%{http_code}' 'http://$endpoint/'")
printf 'endpoint=%s\nhttp_before_backup=%s\n' "$endpoint" "$http_before" | tee "$output_dir/http-before-backup.txt"
[[ $http_before == 200 ]] || { echo 'workload HTTP failed before backup'; exit 1; }

hub_admiralctl \
  "instances backup '$instance_id' --service db --wait --wait-timeout 10m --output json" \
  >"$output_dir/backup-operation.json"
hub_admiralctl 'backups list --output json' >"$output_dir/backups-list.json"
backup_id=$(python3 - "$output_dir/backups-list.json" "$instance_id" <<'PY'
import json,sys
items=json.load(open(sys.argv[1],encoding='utf-8'))
matches=[x for x in items if x.get('instance_id')==sys.argv[2] and x.get('status')=='succeeded']
if not matches: raise SystemExit('no succeeded backup found for test instance')
print(sorted(matches,key=lambda x:x.get('created_at',''))[-1]['id'])
PY
)
[[ $backup_id =~ ^bk_[A-Za-z0-9]+$ ]] || { echo 'invalid backup id'; exit 1; }
recorded_instance_id=$instance_id
recorded_backup_id=$backup_id
hub_admiralctl "backups show '$backup_id'" >"$output_dir/backup-record.json"
python3 - "$output_dir/backup-record.json" "$instance_id" "$backup_id" <<'PY' | tee "$output_dir/backup-summary.txt"
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
for k in ('id','instance_id','backup_type','service','status','storage_backend','size_bytes','checksum_sha256'):
    print(f'{k}={x.get(k)}')
if x.get('id')!=sys.argv[3] or x.get('instance_id')!=sys.argv[2] or x.get('status')!='succeeded' or not x.get('checksum_sha256'):
    raise SystemExit('backup metadata/status/checksum did not validate')
PY

set +e
hub_admiralctl \
  "backups restore --backup-id '$backup_id' --instance-id '$instance_id' --service db" \
  >"$output_dir/restore-while-running.txt" 2>&1
restore_running_rc=$?
set -e
printf 'restore_while_running_exit=%s\n' "$restore_running_rc" | tee -a "$output_dir/restore-while-running.txt"
[[ $restore_running_rc -ne 0 ]] || { echo 'restore unexpectedly accepted while workload is running'; exit 1; }
grep -Eiq 'HTTP 409|only allowed when the app is paused|must be paused' "$output_dir/restore-while-running.txt" || {
  echo 'running-restore rejection did not identify the pause precondition'; exit 1;
}

ssh "${worker_args[@]}" "$worker" sudo bash -s -- "$instance_id" "$marker" mutate \
  >"$output_dir/marker-after-mutation.txt" <<'REMOTE'
set -euo pipefail
cd /tmp
instance_id=$1 marker=$2 action=$3
uid=$(id -u admiral-apps)
podman_as_apps() { runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" podman "$@"; }
db="admiral-${instance_id}-db"
sql="UPDATE admiral_audit_marker SET value='mutated-after-backup'; SELECT value FROM admiral_audit_marker;"
podman_as_apps exec "$db" sh -c 'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -v ON_ERROR_STOP=1 -c "$1"' sh "$sql"
REMOTE
grep -Fx mutated-after-backup "$output_dir/marker-after-mutation.txt" >/dev/null || { echo 'SQL marker mutation was not observed'; exit 1; }
hub_admiralctl "instances pause '$instance_id' --wait --wait-timeout 5m --output json" >"$output_dir/pause.json"
restore_output=$(hub_admiralctl \
  "backups restore --backup-id '$backup_id' --instance-id '$instance_id' --service db --verify-checksum" 2>&1)
printf '%s\n' "$restore_output" >"$output_dir/restore-queued.txt"
restore_op=$(sed -n 's/^Operation ID: //p' "$output_dir/restore-queued.txt" | tail -n1)
[[ $restore_op =~ ^op_[A-Za-z0-9]+$ ]] || { echo 'restore operation ID missing or malformed'; exit 1; }
for attempt in $(seq 1 120); do
  hub_admiralctl "operations show '$restore_op'" >"$output_dir/restore-operation.json"
  state=$(python3 - "$output_dir/restore-operation.json" <<'PY'
import json,sys
print(json.load(open(sys.argv[1],encoding='utf-8')).get('status',''))
PY
)
  printf 'restore_poll=%s utc=%s status=%s\n' "$attempt" "$(date -u +%FT%TZ)" "$state" >>"$output_dir/restore-timeline.txt"
  [[ $state == succeeded ]] && break
  [[ $state != failed && $state != cancelled ]] || { cat "$output_dir/restore-operation.json"; exit 1; }
  [[ $attempt -lt 120 ]] || { echo 'restore operation exceeded four-minute polling window'; exit 1; }
  sleep 2
done
hub_admiralctl "instances resume '$instance_id' --wait --wait-timeout 5m --output json" >"$output_dir/resume.json"
wait_for_instance post-restore-state

ssh "${worker_args[@]}" "$worker" sudo bash -s -- "$instance_id" "$marker" query \
  >"$output_dir/marker-after-restore.txt" <<'REMOTE'
set -euo pipefail
cd /tmp
instance_id=$1 marker=$2 action=$3
uid=$(id -u admiral-apps)
podman_as_apps() { runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" podman "$@"; }
db="admiral-${instance_id}-db"
sql='SELECT value FROM admiral_audit_marker;'
podman_as_apps exec "$db" sh -c 'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -v ON_ERROR_STOP=1 -c "$1"' sh "$sql"
REMOTE
grep -Fx "$marker" "$output_dir/marker-after-restore.txt" >/dev/null || { echo 'restore did not return the original SQL marker'; exit 1; }
http_after=$(ssh "${hub_args[@]}" "$hub" \
  "curl --connect-timeout 3 --max-time 10 -sS -o /dev/null -w '%{http_code}' 'http://$endpoint/'")
printf 'http_after_restore=%s\n' "$http_after" | tee -a "$output_dir/http-before-backup.txt"
[[ $http_after == 200 ]] || { echo 'workload HTTP failed after restore'; exit 1; }

printf 'y\n' | hub_admiralctl "backups delete '$backup_id'" >"$output_dir/backup-delete.txt"
backup_id=
hub_admiralctl "instances deprovision '$instance_id' --force --wait --wait-timeout 10m --output json" >"$output_dir/deprovision.json"
python3 - "$output_dir/deprovision.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
if x.get('status')!='succeeded': raise SystemExit('deprovision failed')
print(f"deprovision_operation={x.get('id')} status={x.get('status')}")
PY
ssh "${worker_args[@]}" "$worker" sudo bash -s -- "$instance_id" >"$output_dir/final-inventory.txt" <<'REMOTE'
set -euo pipefail
cd /tmp
instance_id=$1
uid=$(id -u admiral-apps)
podman_as_apps() { runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" podman "$@"; }
containers=$(podman_as_apps ps -a --filter "name=$instance_id" --format '{{.Names}}')
pods=$(podman_as_apps pod ps --format '{{.Name}}' | grep -F "$instance_id" || true)
volumes=$(podman_as_apps volume ls --format '{{.Name}}' | grep -F "$instance_id" || true)
units=$(runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" systemctl --user list-unit-files --no-legend | grep -F "$instance_id" || true)
files=$(find /etc/containers/systemd /var/lib/admiral -xdev -iname "*$instance_id*" -print 2>/dev/null || true)
printf 'containers=%s\npods=%s\nvolumes=%s\nunits=%s\nfiles=%s\n' \
  "${containers:-none}" "${pods:-none}" "${volumes:-none}" "${units:-none}" "${files:-none}"
[[ -z $containers && -z $pods && -z $volumes && -z $units && -z $files ]]
REMOTE
instance_id=
printf 'candidate=0.0.1rc5-67.el10\nnode_id=%s\ninstance_id=%s\nbackup_id=%s\nend_utc=%s\n' \
  "$node_id" "$recorded_instance_id" "$recorded_backup_id" "$(date -u +%FT%TZ)" >"$output_dir/metadata.txt"
(cd "$output_dir" && find . -maxdepth 1 -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
chmod 0600 "$output_dir"/*
echo "local_backup_restore_and_cleanup=PASS node=$node_id evidence=$output_dir"
