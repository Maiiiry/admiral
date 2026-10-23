#!/usr/bin/env bash
# R61 regression: sample the API while the rootless user systemd manager restarts.
set -euo pipefail
cd /
[[ $# -eq 2 ]] || { echo "usage: $0 CUSTOMER IDEMPOTENCY_KEY" >&2; exit 2; }
customer=$1 key=$2
run_dir=/var/tmp/adm-r61-rocky-user-systemd-restart
install -d -m 0700 "$run_dir"
cp /tmp/audit-e2e-backup.yaml "$run_dir/fixture.yaml"
chmod 0600 "$run_dir/fixture.yaml"
instance_id=
watch_pid=
stop_watch="$run_dir/stop-api-watch"
rm -f "$stop_watch"
api_samples="$run_dir/api-samples.tsv"
: > "$api_samples"
chmod 0600 "$api_samples"

cleanup() {
  rc=$?
  trap - EXIT
  if [[ -n ${watch_pid:-} ]]; then
    touch "$stop_watch"
    kill "$watch_pid" 2>/dev/null || true
    wait "$watch_pid" 2>/dev/null || true
  fi
  if [[ -n ${instance_id:-} ]]; then
    uid=$(id -u admiral-apps)
    runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user start "admiral-${instance_id}-db.service" >/dev/null 2>&1 || true
    admiralctl instances deprovision "$instance_id" --force --wait --wait-timeout 10m --output json >/dev/null 2>&1 || true
  fi
  exit "$rc"
}
trap cleanup EXIT

printf 'candidate=R61 os=rocky start_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
admiralctl apps apply --file "$run_dir/fixture.yaml" > "$run_dir/apply.log" 2>&1
admiralctl instances provision --app e2e-backup --tier small --customer "$customer" --idempotency-key "$key" --wait --wait-timeout 10m --quiet --output json > "$run_dir/provision.json"
instance_id=$(python3 - "$run_dir/provision.json" <<'PY'
import json, sys
x = json.load(open(sys.argv[1], encoding="utf-8"))
if x.get("status") != "succeeded" or not x.get("instance_id"):
    raise SystemExit("initial provision did not succeed")
print(x["instance_id"])
PY
)
uid=$(id -u admiral-apps)
manager_unit="user@${uid}.service"
pod_unit="admiral-${instance_id}-pod.service"
db="admiral-${instance_id}-db"
app="admiral-${instance_id}-app"
manager_before=$(systemctl show "$manager_unit" -p MainPID --value)
[[ $(loginctl show-user admiral-apps -p Linger --value) == yes ]] || { echo 'admiral-apps linger is not enabled'; exit 1; }
runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user is-active "$pod_unit" | tee "$run_dir/pod-before.txt"
printf "CREATE TABLE IF NOT EXISTS admiral_systemd_marker (value TEXT PRIMARY KEY); TRUNCATE admiral_systemd_marker; INSERT INTO admiral_systemd_marker(value) VALUES ('r61-user-systemd-persisted');\n" | runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman exec -i "$db" sh -c 'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1' > "$run_dir/marker-before.txt"
app_mapping=$(runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman port "$app" 80/tcp | head -n1)
app_port=${app_mapping##*:}
[[ $app_port =~ ^[0-9]+$ ]] || { echo "invalid app port mapping: $app_mapping"; exit 1; }
[[ $(curl --silent --max-time 3 --output "$run_dir/http-before.txt" --write-out '%{http_code}' "http://127.0.0.1:$app_port/") == 200 ]] || { echo 'pre-restart app HTTP check failed'; exit 1; }
printf 'instance_id=%s manager_before=%s app_port=%s\n' "$instance_id" "$manager_before" "$app_port"

api_watch() {
  while [[ ! -e $stop_watch ]]; do
    sample_time=$(date +%s.%N)
    sample_pid=$(systemctl show "$manager_unit" -p MainPID --value 2>/dev/null || true)
    sample_manager=$(systemctl is-active "$manager_unit" 2>/dev/null || true)
    sample_json=$(admiralctl instances show "$instance_id" 2>/dev/null || true)
    sample_fields=$(python3 -c 'import json,sys
try:
 x=json.loads(sys.stdin.read())
 print(x.get("technical_status","unknown"),x.get("health_status","unknown"),x.get("effective_availability","unknown"))
except Exception:
 print("unknown unknown unknown")' <<< "$sample_json")
    printf '%s\t%s\t%s\t%s\n' "$sample_time" "$sample_pid" "$sample_manager" "$sample_fields" >> "$api_samples"
    sleep 0.1
  done
}
api_watch &
watch_pid=$!
restart_requested=$(date +%s.%N)
printf 'user_manager_restart_requested_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
systemctl restart "$manager_unit"
restart_returned=$(date +%s.%N)
printf 'user_manager_restart_returned_utc=%s manager_pid=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(systemctl show "$manager_unit" -p MainPID --value)"

recovered=0
runtime_ready_epoch=
for attempt in $(seq 1 120); do
  manager_state=$(systemctl is-active "$manager_unit" 2>/dev/null || true)
  manager_after=$(systemctl show "$manager_unit" -p MainPID --value 2>/dev/null || true)
  pod_state=$(runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user is-active "$pod_unit" 2>/dev/null || true)
  db_ready=$(runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman exec "$db" pg_isready -h 127.0.0.1 -p 5432 2>&1 || true)
  http=$(curl --silent --max-time 1 --output "$run_dir/http-$attempt.txt" --write-out '%{http_code}' "http://127.0.0.1:$app_port/" || true)
  admiralctl instances show "$instance_id" > "$run_dir/instance-recovery-$attempt.json"
  read -r tech health avail < <(python3 - "$run_dir/instance-recovery-$attempt.json" <<'PY'
import json, sys
x = json.load(open(sys.argv[1], encoding="utf-8"))
print(x.get("technical_status", ""), x.get("health_status", ""), x.get("effective_availability", ""))
PY
)
  printf 'recovery_poll=%s utc=%s manager=%s pid=%s pod=%s db=%s api=%s/%s/%s http=%s\n' "$attempt" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$manager_state" "$manager_after" "$pod_state" "$db_ready" "$tech" "$health" "$avail" "$http"
  if [[ $manager_state == active && $manager_after =~ ^[1-9][0-9]*$ && $manager_after != "$manager_before" && $pod_state == active && $db_ready == *'accepting connections'* && $http == 200 ]]; then
    [[ -n $runtime_ready_epoch ]] || runtime_ready_epoch=$(date +%s.%N)
    if [[ $tech == running && $health == healthy && $avail == available ]]; then
      recovered=1
      break
    fi
  fi
  sleep 0.5
done
watch_stop_epoch=${runtime_ready_epoch:-$(date +%s.%N)}
touch "$stop_watch"
kill "$watch_pid" 2>/dev/null || true
wait "$watch_pid" 2>/dev/null || true
watch_pid=
printf 'runtime_ready_epoch=%s watcher_stopped_epoch=%s restart_returned_epoch=%s\n' "${runtime_ready_epoch:-not-ready}" "$watch_stop_epoch" "$restart_returned"

python3 - "$api_samples" "$manager_before" "$restart_requested" "$runtime_ready_epoch" <<'PY'
import sys
samples, initial_pid, requested, ready = sys.argv[1:]
requested = float(requested)
ready = float(ready) if ready else float("inf")
count = 0
transition_samples = 0
false_healthy = []
for line in open(samples, encoding="utf-8"):
    fields = line.rstrip("\n").split("\t")
    if len(fields) != 4:
        continue
    stamp, pid, manager, statuses = fields
    stamp = float(stamp)
    tech, health, availability = statuses.split()
    if stamp < requested:
        continue
    count += 1
    transitioned = pid != initial_pid or manager != "active"
    if transitioned:
        transition_samples += 1
    if transitioned and stamp < ready and health == "healthy" and availability == "available":
        false_healthy.append((stamp, pid, manager, tech, health, availability))
print(f"api_samples_after_restart={count} manager_transition_samples={transition_samples} false_healthy_before_runtime_ready={len(false_healthy)}")
if count == 0 or transition_samples == 0:
    raise SystemExit("API watcher did not capture the manager restart")
if false_healthy:
    for sample in false_healthy:
        print("FALSE_HEALTHY_SAMPLE", *sample)
    raise SystemExit(1)
PY
[[ $recovered -eq 1 ]] || { echo 'workload did not recover to healthy/available'; exit 1; }
marker_after=$(printf 'SELECT value FROM admiral_systemd_marker;\n' | runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman exec -i "$db" sh -c 'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -v ON_ERROR_STOP=1')
printf 'marker_after=%s\n' "$marker_after"
[[ $marker_after == r61-user-systemd-persisted ]] || { echo 'SQL marker was not preserved'; exit 1; }

admiralctl instances deprovision "$instance_id" --force --wait --wait-timeout 10m --output json > "$run_dir/deprovision.json"
cat "$run_dir/deprovision.json"
resources=$(runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman ps --all --filter name="$instance_id" --format '{{.Names}}|{{.Status}}')
[[ -z $resources ]] || { printf 'residual runtime resources:\n%s\n' "$resources"; exit 1; }
instance_id=
echo 'user_systemd_manager_restart_and_recovery=PASS'
printf 'end_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
