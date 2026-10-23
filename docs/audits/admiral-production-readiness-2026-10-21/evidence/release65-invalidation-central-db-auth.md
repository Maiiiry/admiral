# Release 65 invalidation — central PostgreSQL outage blocks valid Fleet workers

Audit: `ADM-AUDIT-2026-10-21`  
Candidate: Admiral RC5 Release 65, root `967920fb122f09521444c9f6e27d3db0c836becc`, `admirald` `351a713dec3a3672a22707c1e15a7f77f827e1c5`  
Result: **FAIL — candidate invalidated; matrix remains 0/8.**  
Issue: [#264](https://github.com/admiral-project/admiral/issues/264), linked to tracker [#200](https://github.com/admiral-project/admiral/issues/200).

## Environment and procedure

On three isolated AlmaLinux 10.2 x86_64 guests (hub plus workers W1 and W2), the exact R65 EL10 RPMs were installed. A workload was placed on W1 and its HTTP endpoint and SQL marker were checked. The hub's PostgreSQL service was stopped for 120 seconds; a temporary systemd timer restored it. Fleet workers continued normal token-authenticated task-claim and health requests. PostgreSQL and the Admiral service were monitored through outage and recovery. The workload was deprovisioned and cleanup checked after the run.

## Expected

A transient database lookup failure is a retryable dependency error. It must not count as an invalid credential or block valid Fleet worker IPs. Once PostgreSQL returns, task claims, heartbeats and health reports should recover without waiting for the five-minute invalid-auth limiter window.

## Observed

While the central database was down, `admiralctl nodes list` timed out after six seconds. The workload containers remained running; the app continued returning HTTP 200 and the SQL marker remained readable. Admirald returned **42 HTTP 401 `auth_db_error` responses** to valid Fleet tokens from `06:54:52Z` to `06:56:58Z` (W1: 27; W2: 15). The per-IP limiter then returned **332 HTTP 429 `ip_temporarily_blocked` responses** from `06:55:11Z` to `06:59:44Z`.

PostgreSQL was restored at `06:56:52Z`, but worker API requests stayed blocked until the five-minute auth-failure window expired. The W1 instance remained `running/healthy/unavailable` with stale health until fresh health reporting resumed at `07:00:06Z`. Both workers then reported fresh heartbeats and health. The SQL marker remained intact, the app returned HTTP 200, deprovision succeeded, and cleanup found no leftover workload resources. No manual service restart was required.

## Cause and fix

Cause confirmed in the R65 source: `admirald/internal/api/node_auth.go` treated every `GetNodeTokenByIdentifier` database error as invalid authentication, incrementing the per-IP failure limiter and returning 401. The limiter threshold is 10 failures in five minutes (`admirald/internal/api/api.go`).

The source fix is pushed to `admirald/main` as `643d203576037a12eba59d534d51d170acae9b5d`: database lookup failures now return retryable HTTP 503 with `Retry-After: 5` and do not consume the invalid-credential budget. A regression test repeatedly injects database errors beyond the limiter threshold and asserts every response remains 503. Focused and full Go test suites and `go vet ./...` passed locally. GitHub CI run [39915433860](https://github.com/admiral-project/admirald/actions/runs/39915433860) was still in progress when this evidence was first recorded; the fix has not yet been packaged or runtime-validated.

## Evidence integrity

Raw logs are mode `0600` and ignored under `packaging/build/validation/rc5-r65/`. SHA-256 values:

| Capture | SHA-256 |
| --- | --- |
| `alma-multinode-hub-postgres-outage.log` | `095378b959005563983bcf0849fcaa35a1d012db39fd99ce1d142aeac0ddc1cc` |
| `alma-multinode-hub-postgres-marker-during-outage.log` | `7184ae618f738ffafe59a33f799087e8d011d8305f96a37f706d6a13de741c28` |
| `alma-multinode-hub-postgres-auth-summary.log` | `29d934d5d610b4fba558b6f3444894047cb4da5ebb84e117376d2af9731510c3` |
| `alma-multinode-hub-postgres-admirald-errors.log` | `ca32914a146a7a9a846548574a07d2769ed1b684d28ecb51ec01ea16fd735351` |
| `alma-multinode-hub-postgres-w1-fleet.log` | `a6895b23e453de521d9375469f71b2058a692d9f6aa06af2bc8f5311f9c03162` |
| `alma-multinode-hub-postgres-recovery.log` | `c1c3cc99b6f231a5566e95526018f97703cd5c90982c721150a1411e84bcf6a5` |
| `alma-multinode-hub-postgres-final-verification.log` | `2329cd402788f1d664b44556784842b61d70243a0c865d292fcf04d7d9afd0bb` |
| `alma-multinode-hub-postgres-marker-after-recovery.log` | `23bb188c609fca63bfbd3236066ddc9cc4caceb5d61a387d5bba181c8d5a895e` |
| `alma-multinode-hub-postgres-deprovision.json` | `4855617eb1727ff161610e6c0cdb500c2a4c77555e17a1254d18a40baf256e92` |
| `alma-multinode-hub-postgres-cleanup.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

The central-database outage regression must be repeated on the exact next candidate before matrix work resumes. R65's earlier scenario results remain diagnostic evidence only and receive no matrix credit.
