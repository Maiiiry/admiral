#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Exercise #228 on an isolated Release 67 EL10 Multi-Node lab.
set -euo pipefail

if [[ $# -ne 5 && $# -ne 7 ]]; then
  echo "Usage: $0 SSH_KEY HUB_KNOWN_HOSTS WORKER_KNOWN_HOSTS INSTANCE_ID OUTPUT_DIR [HUB_IP WORKER_IP]" >&2
  exit 2
fi

ssh_key=$1
hub_known_hosts=$2
worker_known_hosts=$3
instance_id=$4
run_dir=$5
hub_ip=${6:-10.77.0.30}
worker_ip=${7:-10.77.0.32}
[[ $instance_id =~ ^inst_[0-9a-f]{16}$ ]] || { echo "invalid instance ID" >&2; exit 2; }
[[ $run_dir == /* ]] || { echo "output directory must be absolute" >&2; exit 2; }

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
audit_dir=$(cd -- "$script_dir/../.." && pwd)
install -d -m 0700 "$run_dir"
umask 077
hub=validator@$hub_ip
worker=validator@$worker_ip

ssh_hub() {
  ssh -i "$ssh_key" -o IdentitiesOnly=yes -o BatchMode=yes \
    -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$hub_known_hosts" "$hub" "$@"
}

ssh_worker() {
  ssh -i "$ssh_key" -o IdentitiesOnly=yes -o BatchMode=yes \
    -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$worker_known_hosts" "$worker" "$@"
}

restore_needed=false
restore_podman() {
  if [[ $restore_needed == true ]]; then
    ssh_worker sudo bash -s -- "$instance_id" \
      < "$audit_dir/scripts/restore-podman-after-injection.sh" \
      > "$run_dir/podman-restore.log" 2>&1 || true
    restore_needed=false
  fi
}
trap restore_podman EXIT INT TERM

printf 'candidate=0.0.1rc5-67.el10\ninstance_id=%s\nstart_utc=%s\n' \
  "$instance_id" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$run_dir/metadata.txt"
ssh_hub 'rpm -q admiral-common admirald admiral-fleet admiralctl admiral-flagship admiral-harbor 2>&1 || true' \
  > "$run_dir/hub-rpms.txt"
ssh_worker 'rpm -q admiral-common admiral-fleet' > "$run_dir/worker-rpms.txt"
ssh_hub "admiralctl instances show '$instance_id'" > "$run_dir/instance-before.json"
ssh_worker "sudo sha256sum /usr/bin/podman" > "$run_dir/podman-before.sha256"

ssh_worker sudo bash -s -- "$instance_id" \
  < "$audit_dir/scripts/inject-podman-removal-failure.sh" \
  > "$run_dir/injection-setup.log" 2>&1
restore_needed=true

set +e
ssh_hub "admiralctl instances deprovision '$instance_id' --force --wait --wait-timeout 10m --output json" \
  > "$run_dir/deprovision-injected.json" 2> "$run_dir/deprovision-injected.stderr"
injected_rc=$?
set -e
printf 'injected_deprovision_exit=%s\n' "$injected_rc" >> "$run_dir/metadata.txt"

ssh_hub "admiralctl instances show '$instance_id'" > "$run_dir/instance-after-injected.json"
ssh_worker "sudo bash -c 'cd /tmp; uid=\$(id -u admiral-apps); runuser -u admiral-apps -- env XDG_RUNTIME_DIR=/run/user/\$uid DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$uid/bus podman ps --all --format \"{{.Names}}|{{.Status}}\"'" \
  > "$run_dir/containers-after-injected.txt"
ssh_worker "sudo bash -c 'cd /tmp; uid=\$(id -u admiral-apps); runuser -u admiral-apps -- env XDG_RUNTIME_DIR=/run/user/\$uid DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$uid/bus podman pod ps --format \"{{.Name}}|{{.Status}}\"'" \
  > "$run_dir/pods-after-injected.txt"
ssh_worker "sudo bash -c 'cd /tmp; uid=\$(id -u admiral-apps); runuser -u admiral-apps -- env XDG_RUNTIME_DIR=/run/user/\$uid DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$uid/bus podman volume ls --format \"{{.Name}}\"'" \
  > "$run_dir/volumes-after-injected.txt"
ssh_worker "sudo cat '/var/lib/admiral/audit-podman-fail-$instance_id.log'" \
  > "$run_dir/injected-commands.log"
chmod 0600 "$run_dir/injected-commands.log"
sha256sum "$run_dir/injected-commands.log" > "$run_dir/injected-commands.sha256"

restore_podman
ssh_worker 'sudo sha256sum /usr/bin/podman' > "$run_dir/podman-after-restore.sha256"
ssh_worker 'sudo podman --version' > "$run_dir/podman-version-after-restore.txt"

set +e
ssh_hub "admiralctl instances deprovision '$instance_id' --force --wait --wait-timeout 10m --output json" \
  > "$run_dir/deprovision-retry.json" 2> "$run_dir/deprovision-retry.stderr"
retry_rc=$?
set -e
printf 'retry_deprovision_exit=%s\nend_utc=%s\n' "$retry_rc" \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$run_dir/metadata.txt"
ssh_hub "admiralctl instances show '$instance_id'" > "$run_dir/instance-final.json"
ssh_worker "sudo bash -c 'cd /tmp; uid=\$(id -u admiral-apps); runuser -u admiral-apps -- env XDG_RUNTIME_DIR=/run/user/\$uid DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$uid/bus podman ps --all --format \"{{.Names}}|{{.Status}}\"'" \
  > "$run_dir/containers-final.txt"
ssh_worker "sudo bash -c 'cd /tmp; uid=\$(id -u admiral-apps); runuser -u admiral-apps -- env XDG_RUNTIME_DIR=/run/user/\$uid DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$uid/bus podman pod ps --format \"{{.Name}}|{{.Status}}\"'" \
  > "$run_dir/pods-final.txt"
ssh_worker "sudo bash -c 'cd /tmp; uid=\$(id -u admiral-apps); runuser -u admiral-apps -- env XDG_RUNTIME_DIR=/run/user/\$uid DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$uid/bus podman volume ls --format \"{{.Name}}\"'" \
  > "$run_dir/volumes-final.txt"
ssh_worker "sudo find /etc/containers/systemd /var/lib/admiral -xdev -iname '*$instance_id*' -print 2>/dev/null || true" \
  > "$run_dir/metadata-residue-final.txt"

find "$run_dir" -maxdepth 1 -type f -exec chmod 0600 {} +
(
  cd -- "$run_dir"
  find . -maxdepth 1 -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)
chmod 0600 "$run_dir/SHA256SUMS"
printf 'evidence_dir=%s\n' "$run_dir"
