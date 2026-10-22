#!/usr/bin/env bash
# Stop a disposable workload's PostgreSQL user unit, observe API health, restart,
# verify persisted data, and always attempt to deprovision the test instance.
set -euo pipefail
cd /
[[ $# -eq 3 ]] || { echo "usage: $0 {rocky|alma|centos} CUSTOMER IDEMPOTENCY_KEY" >&2; exit 2; }
os=$1 customer=$2 key=$3
run_dir="/var/tmp/adm-r58-${os}-db-outage"
install -d -m 0700 "$run_dir"
cp /tmp/audit-e2e-backup.yaml "$run_dir/fixture.yaml"
chmod 0600 "$run_dir/fixture.yaml"
printf 'os=%s start_utc=%s\n' "$os" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
admiralctl apps apply --file "$run_dir/fixture.yaml" > "$run_dir/apply.log" 2>&1
admiralctl instances provision --app e2e-backup --tier small --customer "$customer" --idempotency-key "$key" --wait --wait-timeout 10m --quiet --output json > "$run_dir/provision.json"
instance_id=$(python3 - "$run_dir/provision.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
if x.get('status')!='succeeded' or not x.get('instance_id'):
    raise SystemExit('initial provision did not succeed')
print(x['instance_id'])
PY
)
uid=$(id -u admiral-apps)
db_container="admiral-${instance_id}-db"
db_unit="admiral-${instance_id}-db.service"
printf 'instance_id=%s db_unit=%s\n' "$instance_id" "$db_unit"
runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user is-active "$db_unit" | tee "$run_dir/db-unit-before.txt"
runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman exec "$db_container" pg_isready -h 127.0.0.1 -p 5432 | tee "$run_dir/db-ready-before.txt"
printf "CREATE TABLE IF NOT EXISTS admiral_outage_marker (value TEXT PRIMARY KEY); TRUNCATE admiral_outage_marker; INSERT INTO admiral_outage_marker(value) VALUES ('r58-db-outage-persisted');\n" | runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman exec -i "$db_container" sh -c 'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1' > "$run_dir/marker-before.txt"
cat "$run_dir/marker-before.txt"
runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user stop "$db_unit"
stopped=$(runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user is-active "$db_unit" 2>/dev/null || true)
printf 'db_unit_after_stop=%s utc=%s\n' "$stopped" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
[[ $stopped != active ]] || { echo 'database systemd unit remained active after stop'; exit 1; }

healthy_available_polls=0
api_samples=0
for attempt in $(seq 1 12); do
  admiralctl instances show "$instance_id" > "$run_dir/instance-outage-$attempt.json"
  fields=$(python3 - "$run_dir/instance-outage-$attempt.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print(x.get('technical_status',''),x.get('health_status',''),x.get('effective_availability',''))
PY
)
  runtime=$(runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman inspect --format '{{.State.Status}}' "$db_container" 2>/dev/null || printf absent)
  printf 'outage_poll=%s utc=%s api=%s db_runtime=%s\n' "$attempt" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$fields" "$runtime"
  ((api_samples+=1))
  read -r tech health avail <<< "$fields"
  if [[ $health == healthy && $avail == available ]]; then ((healthy_available_polls+=1)); fi
  [[ $runtime != running ]] || { echo 'database container restarted unexpectedly while its user unit was stopped'; exit 1; }
  [[ $attempt -eq 12 ]] || sleep 5
done
printf 'outage_observation_seconds=55 healthy_available_polls=%s samples=%s\n' "$healthy_available_polls" "$api_samples"

runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user start "$db_unit"
recovered=0
for attempt in $(seq 1 48); do
  state=$(runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user is-active "$db_unit" 2>/dev/null || true)
  ready=$(runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman exec "$db_container" pg_isready -h 127.0.0.1 -p 5432 2>&1 || true)
  admiralctl instances show "$instance_id" > "$run_dir/instance-recovery-$attempt.json"
  fields=$(python3 - "$run_dir/instance-recovery-$attempt.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print(x.get('technical_status',''),x.get('health_status',''),x.get('effective_availability',''))
PY
)
  printf 'recovery_poll=%s utc=%s unit=%s db=%s api=%s\n' "$attempt" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$state" "$ready" "$fields"
  read -r tech health avail <<< "$fields"
  if [[ $state == active && $ready == *'accepting connections'* && $health == healthy && $avail == available ]]; then recovered=1; break; fi
  [[ $attempt -lt 48 ]] || break
  sleep 5
done
if [[ $recovered -eq 1 ]]; then
  printf 'SELECT value FROM admiral_outage_marker;\n' | runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman exec -i "$db_container" sh -c 'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -v ON_ERROR_STOP=1' > "$run_dir/marker-after.txt"
  cat "$run_dir/marker-after.txt"
  [[ $(cat "$run_dir/marker-after.txt") == r58-db-outage-persisted ]] || recovered=0
fi

cleanup_rc=0
admiralctl instances deprovision "$instance_id" --force --wait --wait-timeout 10m --output json > "$run_dir/deprovision.json" 2> "$run_dir/deprovision.stderr" || cleanup_rc=$?
cat "$run_dir/deprovision.json" "$run_dir/deprovision.stderr"
printf 'deprovision_exit=%s\n' "$cleanup_rc"
resources=$(runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman ps --all --filter name="$instance_id" --format '{{.Names}}|{{.Status}}')
printf '%s\n' "$resources" > "$run_dir/resources-after-cleanup.txt"
[[ -z $resources ]] || { printf '%s\n' "$resources"; cleanup_rc=1; }
[[ $cleanup_rc -eq 0 ]] || { echo 'cleanup failed after database outage probe' >&2; exit 1; }
[[ $recovered -eq 1 ]] || { echo 'database service did not return healthy with persisted marker' >&2; exit 1; }
echo 'database_service_outage_and_recovery=PASS'
printf 'end_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
