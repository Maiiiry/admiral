#!/usr/bin/env bash
# Probe selected control-plane APIs on a disposable Single-Node guest without credentials.
# TLS verification is deliberately disabled for this auth-only probe; do not use
# this script to validate certificate identity or as an operational health check.
set -euo pipefail

base_url=${1:-https://127.0.0.1:8080}
if (( $# > 1 )) || [[ $base_url != https://127.0.0.1:8080 ]]; then
  echo "Usage: $0 [https://127.0.0.1:8080] (disposable local Single-Node guest only)" >&2
  exit 2
fi

probe() {
  local label=$1 method=$2 path=$3 body=${4-} result status
  local -a args=(--insecure --silent --show-error --max-time 5 -o /dev/null -w '%{http_code} %{size_download}')
  if [[ -n $body ]]; then
    args+=(-X "$method" -H 'Content-Type: application/json' --data "$body")
  else
    args+=(-X "$method")
  fi
  result=$(curl "${args[@]}" "${base_url}${path}")
  status=${result%% *}
  printf '%s http=%s bytes=%s\n' "$label" "$status" "${result#* }"
  if [[ $status != 401 && $status != 429 ]]; then
    echo "Expected HTTP 401 or rate-limit 429 for $label without credentials." >&2
    return 1
  fi
}

printf 'tls_verification=disabled_for_auth_probe_only\n'
probe fleet_claim POST /api/v1/fleet/tasks/claim '{}'
probe fleet_callback POST /api/v1/fleet/callback '{"task_id":"unauth-audit-probe","operation_id":"unauth-audit-probe","node_id":"unauth-audit-probe","success":true}'
probe node_heartbeat POST /api/v1/nodes/heartbeat '{"node_id":"unauth-audit-probe"}'
probe admin_tasks GET /api/admin/tasks

probe_invalid_token() {
  local label=$1 method=$2 path=$3 body=${4-} result status
  local -a args=(--insecure --silent --show-error --max-time 5 -o /dev/null -w '%{http_code} %{size_download}' -H 'X-Admiral-Token: audit-invalid-token')
  if [[ -n $body ]]; then
    args+=(-X "$method" -H 'Content-Type: application/json' --data "$body")
  else
    args+=(-X "$method")
  fi
  result=$(curl "${args[@]}" "${base_url}${path}")
  status=${result%% *}
  printf '%s http=%s bytes=%s\n' "$label" "$status" "${result#* }"
  if [[ $status != 401 && $status != 429 ]]; then
    echo "Expected HTTP 401 or rate-limit 429 for $label with an invalid synthetic token." >&2
    return 1
  fi
}

probe_invalid_token fleet_claim_invalid_token POST /api/v1/fleet/tasks/claim '{}'
probe_invalid_token fleet_callback_invalid_token POST /api/v1/fleet/callback '{"task_id":"unauth-audit-probe","operation_id":"unauth-audit-probe","node_id":"unauth-audit-probe","success":true}'
probe_invalid_token node_heartbeat_invalid_token POST /api/v1/nodes/heartbeat '{"node_id":"unauth-audit-probe"}'
probe_invalid_token admin_tasks_invalid_token GET /api/admin/tasks
