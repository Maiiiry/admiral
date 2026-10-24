#!/usr/bin/env bash
set -euo pipefail
cd /
os=$1
customer=$2
key=$3
run_dir="/var/tmp/adm-r70-${os}-cgroup"
install -d -m 0700 "$run_dir"
cp /tmp/audit-e2e-whoami.yaml "$run_dir/e2e-whoami.yaml"
admiralctl apps apply --file "$run_dir/e2e-whoami.yaml" > "$run_dir/apply.log" 2>&1
admiralctl instances provision --app e2e-whoami --tier small --customer "$customer" --idempotency-key "$key" --wait --wait-timeout 10m --quiet --output json > "$run_dir/provision.json"
instance_id=$(python3 - "$run_dir/provision.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
if x.get('status')!='succeeded': raise SystemExit('provision failed')
print(x['instance_id'])
PY
)
uid=$(id -u admiral-apps)
pod_unit="admiral-${instance_id}-pod.service"
app_unit="admiral-${instance_id}-app.service"
cleanup_enabled=1
cleanup() {
  rc=$?
  trap - EXIT
  if [[ ${cleanup_enabled:-0} -eq 1 && -n ${instance_id:-} ]]; then
    admiralctl instances deprovision "$instance_id" --force --wait --wait-timeout 10m --output json >/dev/null 2>&1 || true
  fi
  exit "$rc"
}
trap cleanup EXIT
printf 'candidate=R70 os=%s instance_id=%s tier_cpu=1 tier_memory=512M\n' "$os" "$instance_id"
cd /
runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user show "$pod_unit" -p ControlGroup -p MemoryMax -p CPUQuotaPerSecUSec -p CPUWeight -p Slice > "$run_dir/pod-unit-limits.txt"
cat "$run_dir/pod-unit-limits.txt"
cg=$(sed -n 's/^ControlGroup=//p' "$run_dir/pod-unit-limits.txt")
[[ -n $cg && -d "/sys/fs/cgroup${cg}" ]] || { echo "pod cgroup path is missing: $cg"; exit 1; }
printf 'pod_cgroup=%s memory.max=%s cpu.max=%s\n' "$cg" "$(cat "/sys/fs/cgroup${cg}/memory.max")" "$(cat "/sys/fs/cgroup${cg}/cpu.max")"
for suffix in app db; do
  container="admiral-${instance_id}-${suffix}"
  pid=$(runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman inspect --format '{{.State.Pid}}' "$container")
  proc_cg=$(awk -F: '$1=="0" {print $3}' "/proc/$pid/cgroup")
  printf 'container=%s pid=%s proc_cgroup=%s\n' "$container" "$pid" "$proc_cg"
  current=$proc_cg
  found=0
  while [[ -n $current ]]; do
    dir="/sys/fs/cgroup${current}"
    if [[ -r $dir/memory.max && -r $dir/cpu.max ]]; then
      memory=$(cat "$dir/memory.max")
      cpu=$(cat "$dir/cpu.max")
      printf '  ancestor=%s memory.max=%s cpu.max=%s\n' "$current" "$memory" "$cpu"
      [[ $memory == 536870912 && $cpu == '100000 100000' ]] && found=1
    fi
    [[ $current != / ]] || break
    current=$(dirname "$current")
    [[ $current != . ]] || break
  done
  [[ $found -eq 1 ]] || { echo "effective tier limits not found in $container cgroup ancestors"; exit 1; }
done
runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user show "$app_unit" -p ActiveState -p ControlGroup -p MemoryMax -p CPUQuotaPerSecUSec >> "$run_dir/pod-unit-limits.txt"
echo 'effective_cgroup_tier_limits=PASS'
admiralctl instances deprovision "$instance_id" --force --wait --wait-timeout 10m --output json > "$run_dir/deprovision.json"
cat "$run_dir/deprovision.json"
resources=$(runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" podman ps --all --filter name="$instance_id" --format '{{.Names}}|{{.Status}}')
[[ -z $resources ]] || { printf 'residual runtime resources:\n%s\n' "$resources"; exit 1; }
cleanup_enabled=0
printf 'end_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
