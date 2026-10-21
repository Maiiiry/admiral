# AlmaLinux Multi-Node unauthenticated API probes

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Test ID: `ALMA-MN-010`<br>
Candidate: Release 42; source commit `748b703662eafdaf3919bad28787d0264f06bf16`; component identities in `source-manifest.txt`.<br>
Environment: AlmaLinux 10.2 x86_64 three-guest lab; request originated on worker1 (`10.99.0.2`) and traversed WireGuard to hub `10.99.0.1:8080`.<br>
Result: **PASS for missing-credential rejection on the four probed routes; NOT TESTED for state-diff verification, invalid-but-present worker tokens, callback signatures, and cross-node task ownership.**

At `2026-10-21T17:33:49Z`, a direct probe ran; at `17:35:18Z`, the tracked helper repeated it from worker1. Requests had no `Authorization` or `X-Admiral-Token` header and targeted these hub routes:

| Request | Result |
| --- | --- |
| `POST /api/v1/fleet/tasks/claim` with `{}` | HTTP 401, 25-byte generic response |
| `POST /api/v1/fleet/callback` with synthetic nonexistent task/operation/node IDs | HTTP 401, 25-byte generic response |
| `POST /api/v1/nodes/heartbeat` with a synthetic node ID | HTTP 401, 25-byte generic response |
| `GET /api/admin/tasks` | HTTP 401, 25-byte generic response; response body discarded |

The second run used `scripts/probe-unauthenticated-worker-api.sh`; it printed only status and response length. Source inspection confirms missing credentials return from `NodeAuthMiddleware` or admin auth before the route handler. No credential was supplied. The runtime state was not independently snapshotted before/after this probe, so absence of state mutation is not claimed as separately measured.

TLS certificate verification was disabled (`curl --insecure`) solely to isolate application authentication. This test does not validate certificate identity or TLS trust. An initial HTTP request to the TLS listener returned HTTP 400 (`Client sent an HTTP request to an HTTPS server`); that protocol-mismatch attempt did not reach the API routes and is not counted as an authentication result.

Restricted mode-0600 raw logs are retained locally (not committed): the successful tracked-helper run is `packaging/build/validation/rc5-r42/audit-alma-multi-auth-negative-script.log`, SHA-256 `23a7f7d9df07726c248650c2cb56716d9776005eb0dd4458ab69b5145bcd4971`; the initial protocol-mismatch capture is `audit-alma-multi-auth-http-mismatch.log`, SHA-256 `d30049c17ce15ba614f6b5e4d443ab33043b88c41b2368633225593964dc6eb8`.
