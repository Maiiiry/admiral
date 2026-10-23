#!/usr/bin/env bash
# Run root-invoked audit probes through the initialized, unprivileged operator.
set -euo pipefail

binary=/usr/bin/admiralctl
[[ -x $binary ]] || { echo "admiralctl not found at $binary" >&2; exit 127; }

if (( EUID != 0 )); then
  exec "$binary" "$@"
fi

operator=${ADMIRAL_AUDIT_OPERATOR:-validator}
operator_home=$(getent passwd "$operator" | cut -d: -f6)
operator_group=$(id -gn "$operator")
[[ -n $operator_home && -n $operator_group ]] || {
  echo "cannot resolve audit operator $operator" >&2
  exit 1
}

argv=("$@")
for ((index = 0; index < ${#argv[@]}; index++)); do
  case ${argv[index]} in
    --file|-f)
      (( index + 1 < ${#argv[@]} )) || { echo "${argv[index]} requires a path" >&2; exit 2; }
      index=$((index + 1))
      input=$(realpath -m -- "${argv[index]}")
      case $input in
        /var/tmp/adm-r62-*/*)
          run_dir=$(dirname -- "$input")
          chown -R -- "$operator:$operator_group" "$run_dir"
          ;;
      esac
      ;;
  esac
done

exec runuser -u "$operator" -- env HOME="$operator_home" "$binary" "${argv[@]}"
