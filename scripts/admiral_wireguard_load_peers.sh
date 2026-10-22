#!/usr/bin/env bash
set -euo pipefail

interface="${1:-}"
peer_dir="${2:-/etc/wireguard/peers.d}"

if [[ "$interface" != "wg-admiral" || "$#" -gt 2 ]]; then
  printf 'Usage: %s wg-admiral [peer-fragment-directory]\n' "$0" >&2
  exit 2
fi

if [[ ! -d "$peer_dir" ]]; then
  printf 'WireGuard peer fragment directory is missing: %s\n' "$peer_dir" >&2
  exit 1
fi

export LC_ALL=C
shopt -s nullglob
fragments=("$peer_dir"/*.conf)

for fragment in "${fragments[@]}"; do
  [[ -f "$fragment" && ! -L "$fragment" ]] || continue

  # wg-quick has already configured the interface from wg-admiral.conf.
  # Add persisted peers without replacing interface settings or removing any
  # static peers. Suppress wg output because peer fragments may contain PSKs.
  if ! wg addconf "$interface" "$fragment" >/dev/null 2>&1; then
    printf 'Failed to load persisted WireGuard peer fragment %s on %s.\n' \
      "$(basename "$fragment")" "$interface" >&2
    exit 1
  fi
done
