#!/usr/bin/env bash
set -euo pipefail
cd /
os=$1
customer=$2
idempotency_key=$3
run_dir="/var/tmp/adm-r64-${os}-backup"
install -d -m 0700 "$run_dir"
cp /tmp/audit-e2e-backup.yaml "$run_dir/e2e-backup.yaml"
chmod 0600 "$run_dir/e2e-backup.yaml"
printf 'candidate=R64 os=%s customer=%s start_utc=%s\n' "$os" "$customer" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
admiralctl apps apply --file "$run_dir/e2e-backup.yaml" > "$run_dir/apply.log" 2>&1
admiralctl instances provision --app e2e-backup --tier small --customer "$customer" --idempotency-key "$idempotency_key" --wait --wait-timeout 10m --quiet --output json > "$run_dir/provision.json"
python3 - "$run_dir/provision.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print('provision_operation=',x.get('id') or x.get('operation_id'),'instance=',x.get('instance_id'),'status=',x.get('status'))
if x.get('status')!='succeeded' or not x.get('instance_id'): raise SystemExit('backup fixture provision failed')
PY
instance_id=$(python3 - "$run_dir/provision.json" <<'PY'
import json,sys
print(json.load(open(sys.argv[1],encoding='utf-8'))['instance_id'])
PY
)
backup_id=
cleanup() {
  rc=$?
  trap - EXIT
  if [[ -n ${instance_id:-} ]]; then
    admiralctl instances deprovision "$instance_id" --force --wait --wait-timeout 10m --output json >/dev/null 2>&1 || true
  fi
  if [[ -n ${backup_id:-} ]]; then
    printf 'y\n' | admiralctl backups delete "$backup_id" >/dev/null 2>&1 || true
  fi
  exit "$rc"
}
trap cleanup EXIT
for attempt in $(seq 1 24); do
  admiralctl instances show "$instance_id" > "$run_dir/instance-pre-backup.json"
  fields=$(python3 - "$run_dir/instance-pre-backup.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print(x.get('technical_status',''),x.get('health_status',''),x.get('effective_availability',''))
PY
)
  printf 'ready_poll=%s utc=%s %s\n' "$attempt" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$fields"
  read -r tech health avail <<< "$fields"
  [[ $tech == running && $health == healthy && $avail == available ]] && break
  [[ $attempt -lt 24 ]] || { echo 'backup fixture did not become healthy'; exit 1; }
  sleep 5
done
uid=$(id -u admiral-apps)
db_container="admiral-${instance_id}-db"
cd /
seed_sql="$run_dir/seed-marker.sql"
printf "CREATE TABLE IF NOT EXISTS admiral_audit_marker (value TEXT PRIMARY KEY); TRUNCATE admiral_audit_marker; INSERT INTO admiral_audit_marker(value) VALUES ('original'); SELECT value FROM admiral_audit_marker;\n" > "$seed_sql"
runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman exec -i "$db_container" sh -c 'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1' < "$seed_sql" > "$run_dir/marker-before-backup.txt"
cat "$run_dir/marker-before-backup.txt"
admiralctl instances backup "$instance_id" --service db --wait --wait-timeout 10m --output json > "$run_dir/backup-operation.json"
cat "$run_dir/backup-operation.json"
admiralctl backups list --output json > "$run_dir/backups-list.json"
backup_id=$(python3 - "$run_dir/backups-list.json" "$instance_id" <<'PY'
import json,sys
items=json.load(open(sys.argv[1],encoding='utf-8'))
found=[x for x in items if x.get('instance_id')==sys.argv[2] and x.get('status')=='succeeded']
if not found: raise SystemExit('no succeeded backup found for target instance')
print(sorted(found,key=lambda x:x.get('created_at',''))[-1]['id'])
PY
)
admiralctl backups show "$backup_id" > "$run_dir/backup-record.json"
python3 - "$run_dir/backup-record.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
for k in ('id','instance_id','backup_type','service','status','storage_backend','size_bytes','checksum_sha256','storage_uri_admin'):
    print(f'{k}={x.get(k)}')
if x.get('status')!='succeeded': raise SystemExit('backup status is not succeeded')
if not x.get('checksum_sha256'): raise SystemExit('backup checksum missing')
PY
set +e
admiralctl backups restore --backup-id "$backup_id" --instance-id "$instance_id" --service db > "$run_dir/restore-while-running.txt" 2>&1
restore_running_rc=$?
set -e
cat "$run_dir/restore-while-running.txt"
printf 'restore_while_running_exit=%s\n' "$restore_running_rc"
[[ $restore_running_rc -ne 0 ]] || { echo 'restore unexpectedly accepted while workload is running'; exit 1; }
grep -Eiq 'HTTP 409|only allowed when the app is paused|must be paused' "$run_dir/restore-while-running.txt" || { echo 'restore rejection did not report the paused-state precondition'; exit 1; }
mutate_sql="$run_dir/mutate-marker.sql"
printf "UPDATE admiral_audit_marker SET value='mutated-after-backup'; SELECT value FROM admiral_audit_marker;\n" > "$mutate_sql"
runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman exec -i "$db_container" sh -c 'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1' < "$mutate_sql" > "$run_dir/marker-after-mutation.txt"
cat "$run_dir/marker-after-mutation.txt"
admiralctl instances pause "$instance_id" --wait --wait-timeout 5m --output json > "$run_dir/pause.json"
cat "$run_dir/pause.json"
restore_output=$(admiralctl backups restore --backup-id "$backup_id" --instance-id "$instance_id" --service db --verify-checksum 2>&1)
printf '%s\n' "$restore_output" > "$run_dir/restore-queued.txt"
cat "$run_dir/restore-queued.txt"
restore_op=$(sed -n 's/^Operation ID: //p' "$run_dir/restore-queued.txt" | tail -n1)
[[ -n $restore_op ]] || { echo 'restore operation ID missing'; exit 1; }
for attempt in $(seq 1 120); do
  admiralctl operations show "$restore_op" > "$run_dir/restore-operation.json"
  state=$(python3 - "$run_dir/restore-operation.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print(x.get('status',''))
PY
)
  printf 'restore_poll=%s utc=%s status=%s\n' "$attempt" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$state"
  [[ $state == succeeded ]] && break
  [[ $state != failed && $state != cancelled ]] || { cat "$run_dir/restore-operation.json"; exit 1; }
  [[ $attempt -lt 120 ]] || { echo 'restore operation timed out after 4m'; exit 1; }
  sleep 2
done
admiralctl instances resume "$instance_id" --wait --wait-timeout 5m --output json > "$run_dir/resume.json"
for attempt in $(seq 1 24); do
  admiralctl instances show "$instance_id" > "$run_dir/instance-post-restore.json"
  fields=$(python3 - "$run_dir/instance-post-restore.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print(x.get('technical_status',''),x.get('health_status',''),x.get('effective_availability',''))
PY
)
  printf 'post_restore_ready_poll=%s utc=%s %s\n' "$attempt" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$fields"
  read -r tech health avail <<< "$fields"
  [[ $tech == running && $health == healthy && $avail == available ]] && break
  [[ $attempt -lt 24 ]] || { echo 'restored workload did not become healthy'; exit 1; }
  sleep 5
done
query_sql="$run_dir/query-marker.sql"
printf 'SELECT value FROM admiral_audit_marker;\n' > "$query_sql"
runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman exec -i "$db_container" sh -c 'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -v ON_ERROR_STOP=1' < "$query_sql" > "$run_dir/marker-after-restore.txt"
cat "$run_dir/marker-after-restore.txt"
[[ $(tr -d '\r\n' < "$run_dir/marker-after-restore.txt") == original ]] || { echo 'restored PostgreSQL marker did not match original'; exit 1; }
printf 'y\n' | admiralctl backups delete "$backup_id" > "$run_dir/backup-delete.txt"
cat "$run_dir/backup-delete.txt"
backup_id=
admiralctl instances deprovision "$instance_id" --force --wait --wait-timeout 10m --output json > "$run_dir/deprovision.json"
cat "$run_dir/deprovision.json"
resources=$(runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman ps --all --filter name="$instance_id" --format '{{.Names}}|{{.Status}}')
[[ -z $resources ]] || { printf 'residual runtime resources:\n%s\n' "$resources"; exit 1; }
instance_id=
echo 'backup_restore_and_marker_integrity=PASS'
printf 'backup_test_end_utc=%s instance_id=%s backup_id=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$instance_id" "$backup_id"
