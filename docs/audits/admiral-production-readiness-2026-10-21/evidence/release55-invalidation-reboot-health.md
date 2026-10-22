# Release 55 invalidation — false availability during fast Fedora reboot

Recorded: 2026-10-22 UTC  
Status: **FAIL — candidate invalidated; no R55 evidence counts toward the matrix.**  
Finding: [#256](https://github.com/admiral-project/admiral/issues/256), related to #237.  
Severity: **MEDIUM**.

## Candidate and environment

- Exact candidate: root `d5654ac776617154e2d63cb745d81c8d2ac9ee22`, `admirald@afcf02f094cf7c572cd0e135a280ebb48c0202d5`, `admiral-fleet@3cb2bf83d9787947d3b3212f6c1f92bf3fa81fda`; six RPM NEVRAs and hashes are in `release55-candidate.md`.
- Fedora Rawhide x86_64 Single-Node guest `adm-r55-fedora-single`, fresh overlay from the verified 2026-10-22 Fedora seed; 2 vCPU / 2 GiB.
- Rocky Linux 10.2 x86_64 Single-Node guest `adm-r55-rocky-single` ran the same-candidate comparison.
- RPM install and supported `admiral-install --single-node` completed on both guests. Raw install and scenario logs remain on the isolated host with mode `0600`.

## Procedure

1. Install all six exact R55 RPMs on a fresh guest.
2. Provision the audit DB-backed workload with its declared `pg_isready` health check and insert a SQL marker.
3. Record the guest's Linux boot ID, issue a full guest reboot, and wait for a changed boot ID plus SSH reconnection.
4. Immediately compare `admiralctl instances show`, rootless Podman container count, PostgreSQL `pg_isready`, HTTP response, and the SQL marker.
5. Continue observing recovery and clean up the disposable workload.

## Result

Fedora boot ID changed from `064b048d-b9c5-4ca5-9501-15979692c2c4` to `c1b20a39-5879-4008-8354-ee796825c7ce`. At `2026-10-22T16:56:12Z`, 45 seconds after the last healthy observation (`16:55:27Z`), Admiral reported `running/healthy/available` while only one rootless container was running and PostgreSQL readiness returned false. This contradicts the expected fail-closed recovery state and caused the reboot probe to fail. By `16:56:37Z`, Fleet had submitted a fresh runtime report and the instance recovered. No data loss was observed.

On Rocky Linux 10.2 with the same candidate, the API stayed unavailable while services recovered. It became available only after all three containers were running and PostgreSQL readiness succeeded; HTTP returned 200 and the SQL marker persisted. This comparison does not erase the Fedora failure.

The expected result is to retain the pre-boot health status/message/timestamp as historical evidence but expose `unavailable` until a health observation from the current host boot confirms all declared services ready.

## Confirmed cause

The R55 source derived runtime staleness only from `last_health_checked_at <= CURRENT_TIMESTAMP - INTERVAL '60 seconds'` in `admirald/internal/database/instances.go`. Restart did not invalidate the old observation. Fedora reconnected before 60 seconds elapsed, exposing the previous healthy observation while the DB service was still starting.

## Fix and regression evidence

The fix binds every node heartbeat and Fleet health report to the Linux `/proc/sys/kernel/random/boot_id`. The database stores `nodes.boot_id` and `customer_apps.last_health_boot_id`; effective availability requires them to match, while preserving the health status/message/timestamp. Schema migration 19 adds these fields. Fix commits: `admirald@a816f47` and `admiral-fleet@74e8b0f`.

`TestInstanceAvailabilityInvalidatesHealthFromPreviousNodeBoot` ran against the isolated PostgreSQL 16 test container. It confirmed the old observation becomes unavailable when the node boot ID changes, the historical health fields and timestamp do not change, and a fresh healthy observation from the new boot restores availability. The full admirald test suite passed against PostgreSQL; Fleet's full Go suite, `go vet ./...` and `go build ./...` also passed locally. Fleet CI [39819815054](https://github.com/admiral-project/admiral-fleet/actions/runs/39819815054) passed. Admirald CI [39820151915](https://github.com/admiral-project/admirald/actions/runs/39820151915) completed successfully on `9b8f129`.

This does not yet prove the correction in an installed RPM. Release 56 must repeat the real host reboot regression on fresh Fedora and Rocky guests and include the affected Multi-Node worker-reboot scenario.

## Protected raw evidence

Raw logs are outside Git under `/var/lib/libvirt/images/admiral-validation/validation/rc5-r55/single/` and mode `0600`.

| Raw log | SHA-256 |
| --- | --- |
| `fedora-host-reboot.log` | `92e521d6a62e85b365354dd728bfc79f6171d280450d50227f9cbd7f15862e6d` |
| `rocky-host-reboot.log` | `28f0fb57bdf487e2a8b72c298792778370276632e6ab9b16b99851baf1dd5b25` |

Other R55 targeted logs and checksums are retained on the isolated host. No secret, private key, database URL, or customer data is committed.
