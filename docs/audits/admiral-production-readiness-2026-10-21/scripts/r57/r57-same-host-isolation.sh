#!/usr/bin/env bash
set -euo pipefail
os=$1
customer_prefix=$2
run_id=${ADMIRAL_AUDIT_RUN_ID:-}
if [[ -z $run_id ]]; then
  run_id="$(date -u +%Y%m%dT%H%M%S)-$$"
fi
[[ $run_id =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,47}$ ]] || { echo "invalid ADMIRAL_AUDIT_RUN_ID: $run_id" >&2; exit 2; }
run_dir="/var/tmp/adm-r57-$os-isolation-$run_id"
install -d -m 0700 "$run_dir"
cp /tmp/audit-e2e-backup.yaml "$run_dir/e2e-backup.yaml"
admiralctl apps apply --file "$run_dir/e2e-backup.yaml" > "$run_dir/apply.log" 2>&1
printf 'os=%s run_id=%s start_utc=%s\n' "$os" "$run_id" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
for n in 1 2; do
  customer="$customer_prefix"_"$run_id"_"$n"
  key="adm-$os-isolation-$run_id-$n"
  admiralctl instances provision --app e2e-backup --tier small --customer "$customer" --idempotency-key "$key" --wait --wait-timeout 10m --quiet --output json > "$run_dir/provision-$n.json"
  python3 - "$run_dir/provision-$n.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print('provision_operation=',x.get('id') or x.get('operation_id'),'instance=',x.get('instance_id'),'status=',x.get('status'))
if x.get('status')!='succeeded' or not x.get('instance_id'): raise SystemExit('provision failed')
PY
done
id_a=$(python3 - "$run_dir/provision-1.json" <<'PY'
import json,sys
print(json.load(open(sys.argv[1],encoding='utf-8'))['instance_id'])
PY
)
id_b=$(python3 - "$run_dir/provision-2.json" <<'PY'
import json,sys
print(json.load(open(sys.argv[1],encoding='utf-8'))['instance_id'])
PY
)
[[ $id_a != "$id_b" ]] || { echo 'distinct customer requests returned the same instance'; exit 1; }
printf 'instance_a=%s\ninstance_b=%s\n' "$id_a" "$id_b"
uid=$(id -u admiral-apps)
for n in 1 2; do
  instance_id=$(python3 - "$run_dir/provision-$n.json" <<'PY'
import json,sys
print(json.load(open(sys.argv[1],encoding='utf-8'))['instance_id'])
PY
)
  for attempt in $(seq 1 24); do
    admiralctl instances show "$instance_id" > "$run_dir/instance-$n.json"
    fields=$(python3 - "$run_dir/instance-$n.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print(x.get('technical_status',''),x.get('health_status',''),x.get('effective_availability',''))
PY
)
    read -r tech health avail <<< "$fields"
    [[ $tech == running && $health == healthy && $avail == available ]] && break
    [[ $attempt -lt 24 ]] || { echo "instance $instance_id did not become healthy"; exit 1; }
    sleep 5
  done
done
app_a="admiral-${id_a}-app"; db_a="admiral-${id_a}-db"
app_b="admiral-${id_b}-app"; db_b="admiral-${id_b}-db"
echo '--- sanitized runtime inspection (no environment values emitted) ---'
su -s /bin/sh admiral-apps -c "cd / && podman inspect ${app_a} ${db_a} ${app_b} ${db_b}" | python3 -c '
import json,sys
xs=json.load(sys.stdin)
for x in xs:
    c=x.get("Config",{}); h=x.get("HostConfig",{}); st=x.get("State",{}); ns=x.get("NetworkSettings",{}).get("Networks",{})
    names=[e.split("=",1)[0] for e in c.get("Env",[]) if "=" in e]
    mounts=x.get("Mounts",[])
    print("container=%s pid=%s privileged=%s pid_mode=%s network_mode=%s networks=%s memory_bytes=%s nano_cpus=%s no_new_privileges=%s cap_add=%s cap_drop=%s podman_socket_mount=%s password_env_present=%s env_names=%s" % (
      x.get("Name",""),st.get("Pid"),h.get("Privileged"),h.get("PidMode"),h.get("NetworkMode"),sorted(ns),h.get("Memory"),h.get("NanoCpus"),h.get("SecurityOpt"),h.get("CapAdd"),h.get("CapDrop"),any("podman.sock" in (m.get("Source","")+m.get("Destination","")) for m in mounts),("POSTGRES_PASSWORD" in names),sorted(names)))
    if h.get("Privileged") is True: raise SystemExit("privileged workload container detected")
    if any("podman.sock" in (m.get("Source","")+m.get("Destination","")) for m in mounts): raise SystemExit("Podman socket mounted into workload")
'
printf '%s\n' '--- host PID/network namespace and NoNewPrivs probes ---'
for ctr in "$app_a" "$db_a" "$app_b" "$db_b"; do
  pid=$(su -s /bin/sh admiral-apps -c "cd / && podman inspect --format '{{.State.Pid}}' $ctr")
  printf 'container=%s pid=%s pidns=%s netns=%s ' "$ctr" "$pid" "$(stat -Lc %i "/proc/$pid/ns/pid")" "$(stat -Lc %i "/proc/$pid/ns/net")"
  awk '/^(NoNewPrivs|CapEff):/ {printf "%s=%s ",$1,$2} END {print ""}' "/proc/$pid/status"
done
pid_net_a=$(su -s /bin/sh admiral-apps -c "cd / && podman inspect --format '{{.State.Pid}}' $app_a")
pid_net_b=$(su -s /bin/sh admiral-apps -c "cd / && podman inspect --format '{{.State.Pid}}' $app_b")
net_a=$(stat -Lc %i "/proc/$pid_net_a/ns/net")
net_b=$(stat -Lc %i "/proc/$pid_net_b/ns/net")
printf 'app_network_namespace_a=%s\napp_network_namespace_b=%s\n' "$net_a" "$net_b"
[[ $net_a != "$net_b" ]] || { echo 'different workloads share a network namespace'; exit 1; }
echo '--- app loopback port mappings ---'
for ctr in "$app_a" "$app_b"; do su -s /bin/sh admiral-apps -c "cd / && podman port $ctr 80/tcp"; done
host_port_b=$(su -s /bin/sh admiral-apps -c "cd / && podman port $app_b 80/tcp" | sed -E 's/.*:([0-9]+)$/\1/')
[[ $host_port_b =~ ^[0-9]+$ ]] || { echo "could not determine workload B host port: $host_port_b"; exit 1; }
host_alias=$(su -s /bin/sh admiral-apps -c "cd / && podman exec $db_a getent hosts host.containers.internal" | awk 'NR==1 {print $1}')
[[ $host_alias =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "rootless host alias is unavailable: $host_alias"; exit 1; }
echo '--- cross-workload host-port reachability from workload A (expected denied) ---'
set +e
su -s /bin/sh admiral-apps -c "cd / && podman exec $db_a timeout 4 bash -c '</dev/tcp/$host_alias/$host_port_b'" > "$run_dir/cross-workload-host-port.txt" 2>&1
host_port_status=$?
set -e
cat "$run_dir/cross-workload-host-port.txt"
printf 'workload_a_to_workload_b_host_port=%s:%s exit=%s\n' "$host_alias" "$host_port_b" "$host_port_status"
[[ $host_port_status -ne 0 ]] || { echo 'workload A reached workload B through the rootless host alias'; exit 1; }
echo '--- cross-workload PostgreSQL reachability (pg_isready only; no credentials) ---'
db_ip_b=$(su -s /bin/sh admiral-apps -c "cd / && podman inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $db_b")
if [[ -n $db_ip_b ]]; then
  set +e
  cross_rc=$(su -s /bin/sh admiral-apps -c "cd / && podman exec $db_a pg_isready -h $db_ip_b -p 5432 -t 4" > "$run_dir/cross-workload-postgres.txt" 2>&1)
  cross_status=$?
  set -e
  cat "$run_dir/cross-workload-postgres.txt"
  printf 'cross_workload_pg_isready_exit=%s output=%s\n' "$cross_status" "$cross_rc"
  [[ $cross_status -ne 0 ]] || { echo 'a workload reached another workload PostgreSQL listener'; exit 1; }
else
  echo 'cross_workload_network_probe=NOT TESTED (rootless Podman exposes no container IP for the target DB)'
fi
for instance_id in "$id_a" "$id_b"; do
  admiralctl instances deprovision "$instance_id" --force --wait --wait-timeout 10m --output json > "$run_dir/deprovision-${instance_id}.json"
  cat "$run_dir/deprovision-${instance_id}.json"
  su -s /bin/sh admiral-apps -c "cd / && podman ps --all --filter name=${instance_id} --format '{{.Names}}'" > "$run_dir/cleanup-${instance_id}.txt"
  [[ ! -s "$run_dir/cleanup-${instance_id}.txt" ]] || { cat "$run_dir/cleanup-${instance_id}.txt"; exit 1; }
done
echo 'same_host_runtime_isolation_sample=PASS; host_alias_cross_workload_port=DENIED; database_direct_ip_probe=recorded_above'
printf 'end_utc=%s instance_a=%s instance_b=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$id_a" "$id_b"
