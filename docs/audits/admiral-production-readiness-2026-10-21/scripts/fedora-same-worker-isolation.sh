#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Read-only runtime probes for two disposable instances on one Fedora worker.
set -euo pipefail
if [[ $# -ne 2 ]]; then
  echo "usage: $0 INSTANCE_A INSTANCE_B" >&2
  exit 2
fi
instance_a=$1
instance_b=$2
cd /tmp
podman() { sudo -n -u admiral-apps -- /usr/bin/podman "$@"; }

printf 'captured_at=%s\n' "$(date -u +%FT%TZ)"
printf 'host=%s\n' "$(hostname)"
for instance in "$instance_a" "$instance_b"; do
  printf '\ninstance=%s\n' "$instance"
  for role in infra app db; do
    name="admiral-${instance}-${role}"
    pid=$(podman inspect --format '{{.State.Pid}}' "$name")
    printf 'container=%s pid=%s\n' "$name" "$pid"
    printf 'namespace_net=%s\n' "$(sudo -n readlink "/proc/${pid}/ns/net")"
    printf 'namespace_pid=%s\n' "$(sudo -n readlink "/proc/${pid}/ns/pid")"
    printf 'namespace_mnt=%s\n' "$(sudo -n readlink "/proc/${pid}/ns/mnt")"
    podman inspect --format 'runtime privileged={{.HostConfig.Privileged}} pid_mode={{.HostConfig.PidMode}} security_opt={{json .HostConfig.SecurityOpt}} cap_add={{json .HostConfig.CapAdd}} cap_drop={{json .HostConfig.CapDrop}}' "$name"
    podman inspect --format '{{range .Mounts}}{{printf "mount name=%s source=%s destination=%s rw=%t\\n" .Name .Source .Destination .RW}}{{end}}' "$name"
  done
done

app_a="admiral-${instance_a}-app"
app_b="admiral-${instance_b}-app"
db_a="admiral-${instance_a}-db"
db_b="admiral-${instance_b}-db"
podman inspect --format 'app_a network={{.HostConfig.NetworkMode}} sandbox={{.NetworkSettings.SandboxKey}}' "$app_a"
podman inspect --format 'app_b network={{.HostConfig.NetworkMode}} sandbox={{.NetworkSettings.SandboxKey}}' "$app_b"
podman inspect --format 'db_a_ip={{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$db_a"
podman inspect --format 'db_b_ip={{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$db_b"

secret_a=$(podman inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$db_a" | awk -F= '$1 ~ /(PASSWORD|SECRET|TOKEN)(_|$)/ {print}')
secret_b=$(podman inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$db_b" | awk -F= '$1 ~ /(PASSWORD|SECRET|TOKEN)(_|$)/ {print}')
if [[ -n "$secret_a" && -n "$secret_b" && "$secret_a" != "$secret_b" ]]; then
  echo 'database_secret_env=distinct'
else
  echo 'database_secret_env=not_proven_distinct'
fi
unset secret_a secret_b

for db in "$db_a" "$db_b"; do
  if podman exec "$db" /bin/sh -c 'test -S /run/podman/podman.sock || test -S /run/user/987/podman/podman.sock'; then
    printf 'container=%s podman_socket=present\n' "$db"
  else
    printf 'container=%s podman_socket=absent\n' "$db"
  fi
done
podman exec "$db_b" pg_isready -h 127.0.0.1 -p 5432

pid_a=$(podman inspect --format '{{.State.Pid}}' "$app_a")
ip_a=$(podman inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$db_a")
ip_b=$(podman inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$db_b")
if [[ -n "$ip_a" && -n "$ip_b" && "$ip_a" != "$ip_b" ]]; then
  if sudo -n nsenter --target "$pid_a" --net -- /usr/bin/python3 -c 'import socket,sys; s=socket.socket(); s.settimeout(3); s.connect((sys.argv[1],5432)); print("cross_workload_db_tcp=reachable"); s.close()' "$ip_b"; then
    echo 'cross_workload_db_tcp_result=FAIL'
    exit 1
  else
    echo 'cross_workload_db_tcp=blocked'
  fi
else
  echo 'cross_workload_db_tcp=not_determinate_shared_or_unreported_slirp_address'
fi
