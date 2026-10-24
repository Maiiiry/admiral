#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Run the Release 69 declared-service failure regression on a disposable guest.
set -uo pipefail

if [[ $# -lt 3 || $# -gt 4 ]]; then
  echo "Usage: $0 {rocky|fedora|alma|centos} CUSTOMER_ID IDEMPOTENCY_KEY [NODE_ID]" >&2
  exit 2
fi

os=$1 customer=$2 idempotency_key=$3 node_id=${4:-}
[[ $os =~ ^(rocky|fedora|alma|centos)$ ]] || { echo 'unsupported OS key' >&2; exit 2; }
[[ $customer =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,62}$ ]] || { echo 'invalid customer ID' >&2; exit 2; }
[[ $idempotency_key =~ ^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$ ]] || { echo 'invalid idempotency key' >&2; exit 2; }
[[ -z $node_id || $node_id =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,62}$ ]] || { echo 'invalid node ID' >&2; exit 2; }

cd /
run_dir="/var/tmp/adm-r70-${os}-failed-service-${customer}"
install -d -m 0700 "$run_dir"
cp /tmp/audit-e2e-failing-db.yaml "$run_dir/fixture.yaml" || exit 1
chmod 0600 "$run_dir/fixture.yaml"

result=0
instance_id=''
topology=SN
node_args=()
if [[ -n $node_id ]]; then
  topology=MN
  node_args+=(--node "$node_id")
fi
printf 'test=R70-%s-%s-FAILED-SERVICE\nnode_id=%s\nstart_utc=%s\n' \
  "$os" "$topology" "${node_id:-scheduler}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
rpm -q admiral-common admirald admiral-fleet admiralctl admiral-flagship admiral-harbor

if ! admiralctl apps apply --file "$run_dir/fixture.yaml" > "$run_dir/apply.log" 2>&1; then
  cat "$run_dir/apply.log"
  echo 'fixture application failed'
  exit 1
fi

set +e
admiralctl instances provision --app e2e-failing-db-audit --tier small \
  --customer "$customer" --idempotency-key "$idempotency_key" \
  "${node_args[@]}" --wait --wait-timeout 10m --quiet --output json \
  > "$run_dir/provision.json" 2> "$run_dir/provision.stderr"
provision_rc=$?
set -e
cat "$run_dir/provision.json"
cat "$run_dir/provision.stderr"
printf 'provision_exit=%s\n' "$provision_rc"
[[ $provision_rc -ne 0 ]] || result=1

if ! instance_id=$(python3 - "$run_dir/provision.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print(x.get('instance_id') or '')
if x.get('status') != 'failed' or not x.get('instance_id'):
    raise SystemExit(1)
PY
); then
  echo 'FAIL: provision did not terminate failed with an instance ID'
  result=1
fi

if [[ -n "$instance_id" ]]; then
  admiralctl instances show "$instance_id" > "$run_dir/instance-after-failure.json" 2> "$run_dir/instance-show.stderr"
  cat "$run_dir/instance-after-failure.json"
  if ! python3 - "$run_dir/instance-after-failure.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print('instance_fields=%s %s %s %s' % (x.get('technical_status'),x.get('health_status'),x.get('effective_availability'),x.get('availability_reason')))
if x.get('technical_status') != 'failed' or x.get('effective_availability') != 'unavailable':
    raise SystemExit(1)
PY
  then
    echo 'FAIL: failed service was reported as completed or available'
    result=1
  fi

  uid=$(id -u admiral-apps)
  unit="admiral-${instance_id}-db.service"
  set +e
  runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
    systemctl --user show "$unit" -p LoadState -p ActiveState -p SubState -p NRestarts \
    > "$run_dir/db-unit-state.txt" 2>&1
  unit_rc=$?
  set -e
  cat "$run_dir/db-unit-state.txt"

  runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" \
    podman ps --all --filter name="$instance_id" --format '{{.Names}}|{{.Status}}' \
    > "$run_dir/containers-before-cleanup.txt" 2>&1
  cat "$run_dir/containers-before-cleanup.txt"
  if grep -F "${instance_id}-db|Up " "$run_dir/containers-before-cleanup.txt"; then
    echo 'FAIL: failed PostgreSQL workload is still running'
    result=1
  fi
  if ! grep -q '^ActiveState=failed$' "$run_dir/db-unit-state.txt" \
      && ! grep -q '^LoadState=not-found$' "$run_dir/db-unit-state.txt"; then
    echo "FAIL: DB unit is neither failed nor already removed (systemctl exit=$unit_rc)"
    result=1
  fi
  if grep -q '^LoadState=not-found$' "$run_dir/db-unit-state.txt" \
      && grep -F "${instance_id}-db" "$run_dir/containers-before-cleanup.txt"; then
    echo 'FAIL: DB unit was removed while its container remains'
    result=1
  fi

  set +e
  admiralctl instances deprovision "$instance_id" --force --wait \
    --wait-timeout 10m --output json \
    > "$run_dir/deprovision.json" 2> "$run_dir/deprovision.stderr"
  deprovision_rc=$?
  set -e
  cat "$run_dir/deprovision.json"
  cat "$run_dir/deprovision.stderr"
  printf 'deprovision_exit=%s\n' "$deprovision_rc"
  [[ $deprovision_rc -eq 0 ]] || result=1
  if ! python3 - "$run_dir/deprovision.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print('deprovision_status=',x.get('status'),'operation=',x.get('id'))
if x.get('status') != 'succeeded': raise SystemExit(1)
PY
  then
    result=1
  fi

  runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" \
    podman ps --all --filter name="$instance_id" --format '{{.Names}}' \
    > "$run_dir/containers-after-cleanup.txt" 2>&1
  runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" \
    podman pod ps --format json > "$run_dir/pods-after-cleanup.json" 2>&1
  runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" \
    podman volume ls --format '{{.Name}}' > "$run_dir/volumes-after-cleanup.txt" 2>&1
  runuser -u admiral-apps -- env XDG_RUNTIME_DIR="/run/user/$uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
    systemctl --user list-unit-files --no-legend \
    > "$run_dir/user-units-after-cleanup.txt" 2>&1
  : > "$run_dir/artifacts-after-cleanup.txt"
  for artifact_root in /etc/containers/systemd /var/lib/admiral \
      /var/lib/admiral-apps/.config/containers/systemd \
      /var/lib/admiral-apps/.config/systemd/user; do
    if [[ -e $artifact_root ]]; then
      find "$artifact_root" -xdev -iname "*${instance_id}*" -print 2>/dev/null \
        >> "$run_dir/artifacts-after-cleanup.txt" || result=1
    fi
  done

  for inventory in containers-after-cleanup.txt volumes-after-cleanup.txt user-units-after-cleanup.txt artifacts-after-cleanup.txt; do
    if grep -F "$instance_id" "$run_dir/$inventory"; then
      echo "FAIL: matching resource remains in $inventory"
      result=1
    fi
  done
  if python3 - "$run_dir/pods-after-cleanup.json" "$instance_id" <<'PY'
import json,sys
pods=json.load(open(sys.argv[1],encoding='utf-8'))
if any(sys.argv[2] in p.get('Name','') for p in pods):
    raise SystemExit(1)
PY
  then
    :
  else
    echo 'FAIL: matching Podman pod remains after cleanup'
    result=1
  fi
  admiralctl instances show "$instance_id" > "$run_dir/instance-after-cleanup.json" 2>&1 || result=1
  python3 - "$run_dir/instance-after-cleanup.json" <<'PY' || result=1
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
print('post_cleanup_state=',x.get('technical_status'),x.get('effective_availability'),x.get('availability_reason'))
if x.get('technical_status') != 'deprovisioned': raise SystemExit(1)
PY
fi

printf 'result=%s\nend_utc=%s\n' "$([[ $result -eq 0 ]] && echo PASS || echo FAIL)" \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
exit "$result"
