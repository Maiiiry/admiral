#!/usr/bin/env bash
# Restart the admiral-apps user systemd manager on one disposable R69 guest.
set -euo pipefail
cd /
[[ $# -eq 3 ]] || { echo "usage: $0 {fedora|rocky|alma|centos} CUSTOMER IDEMPOTENCY_KEY" >&2; exit 2; }
os=$1 customer=$2 key=$3
run_dir="/var/tmp/adm-r69-${os}-user-systemd-restart"
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
manager_unit="user@${uid}.service"
db="admiral-${instance_id}-db"
app="admiral-${instance_id}-app"
pod_unit="admiral-${instance_id}-pod.service"
cleanup_enabled=1
cleanup() {
  rc=$?
  trap - EXIT
  if [[ ${cleanup_enabled:-0} -eq 1 ]]; then
    systemctl start "$manager_unit" >/dev/null 2>&1 || true
    admiralctl instances deprovision "$instance_id" --force --wait --wait-timeout 10m --output json \
      > "$run_dir/trap-deprovision.json" 2>&1 || rc=1
  fi
  exit "$rc"
}
trap cleanup EXIT
manager_before=$(systemctl show "$manager_unit" -p MainPID --value)
linger=$(loginctl show-user admiral-apps -p Linger --value)
printf 'instance_id=%s manager_unit=%s manager_pid_before=%s linger=%s\n' "$instance_id" "$manager_unit" "$manager_before" "$linger"
[[ $linger == yes ]] || { echo 'admiral-apps user manager does not have linger enabled'; exit 1; }
runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user is-active "$pod_unit" | tee "$run_dir/pod-unit-before.txt"
printf "CREATE TABLE IF NOT EXISTS admiral_systemd_marker (value TEXT PRIMARY KEY); TRUNCATE admiral_systemd_marker; INSERT INTO admiral_systemd_marker(value) VALUES ('r69-user-systemd-persisted');\n" | runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman exec -i "$db" sh -c 'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1' > "$run_dir/marker-before.txt"
cat "$run_dir/marker-before.txt"

printf 'user_manager_restart_requested_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
systemctl restart "$manager_unit"

recovered=0
false_healthy_count=0
for attempt in $(seq 1 60); do
  manager_state=$(systemctl is-active "$manager_unit" 2>/dev/null || true)
  manager_after=$(systemctl show "$manager_unit" -p MainPID --value 2>/dev/null || true)
  pod_state=$(runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user is-active "$pod_unit" 2>/dev/null || true)
  db_ready=$(runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman exec "$db" pg_isready -h 127.0.0.1 -p 5432 2>&1 || true)
  admiralctl instances show "$instance_id" > "$run_dir/instance-recovery-$attempt.json"
  fields=$(python3 - "$run_dir/instance-recovery-$attempt.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print(x.get('technical_status',''),x.get('health_status',''),x.get('effective_availability',''))
PY
)
  app_port=$(runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman port "$app" 80/tcp 2>/dev/null | head -n1 || true)
  http=000
  if [[ $app_port == *:* ]]; then
    http=$(curl --silent --max-time 3 --output "$run_dir/http-$attempt.txt" --write-out '%{http_code}' "http://127.0.0.1:${app_port##*:}/" || true)
  fi
  printf 'recovery_poll=%s utc=%s manager=%s manager_pid=%s pod=%s db=%s api=%s http=%s\n' "$attempt" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$manager_state" "$manager_after" "$pod_state" "$db_ready" "$fields" "$http"
  read -r tech health avail <<< "$fields"
  if [[ $health == healthy && $avail == available && ( $pod_state != active || $db_ready != *'accepting connections'* || $http != 200 ) ]]; then
    ((false_healthy_count+=1))
    printf 'FALSE_HEALTHY_AVAILABLE pod=%s db_ready=%s http=%s api=%s\n' "$pod_state" "$db_ready" "$http" "$fields"
  fi
  if [[ $manager_state == active && $manager_after =~ ^[1-9][0-9]*$ && $manager_after != "$manager_before" && $pod_state == active && $db_ready == *'accepting connections'* && $tech == running && $health == healthy && $avail == available && $http == 200 ]]; then
    recovered=1
    break
  fi
  [[ $attempt -lt 60 ]] || break
  sleep 5
done

marker_after=missing
if [[ $recovered -eq 1 ]]; then
  printf 'SELECT value FROM admiral_systemd_marker;\n' | runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman exec -i "$db" sh -c 'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -v ON_ERROR_STOP=1' > "$run_dir/marker-after.txt"
  marker_after=$(cat "$run_dir/marker-after.txt")
fi
printf 'marker_after=%s\n' "$marker_after"

cleanup_rc=0
admiralctl instances deprovision "$instance_id" --force --wait --wait-timeout 10m --output json > "$run_dir/deprovision.json" 2> "$run_dir/deprovision.stderr" || cleanup_rc=$?
cat "$run_dir/deprovision.json" "$run_dir/deprovision.stderr"
resources=$(runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman ps --all --filter name="$instance_id" --format '{{.Names}}|{{.Status}}')
printf '%s\n' "$resources" > "$run_dir/resources-after-cleanup.txt"
[[ -z $resources ]] || { printf '%s\n' "$resources"; cleanup_rc=1; }
[[ $cleanup_rc -eq 0 ]] || { echo 'cleanup failed after user systemd restart probe' >&2; exit 1; }
printf 'false_healthy_available_polls=%s\n' "$false_healthy_count"
[[ $recovered -eq 1 && $marker_after == r69-user-systemd-persisted ]] || { echo 'user systemd manager restart did not restore the workload and data' >&2; exit 1; }
[[ $false_healthy_count -eq 0 ]] || { echo 'API reported healthy/available before systemd workload readiness returned' >&2; exit 1; }
cleanup_enabled=0
echo 'user_systemd_manager_restart_and_recovery=PASS'
printf 'end_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
