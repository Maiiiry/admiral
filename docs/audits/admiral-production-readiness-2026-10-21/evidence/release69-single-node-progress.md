# RC5 Release 69 Rocky Linux Single-Node functional result

Audit: `ADM-AUDIT-2026-10-21`
Active target: Rocky Linux 10.2 x86_64 Single-Node only.
Candidate: Admiral RC5 Release 69 (`0.0.1rc5-69`), package source commit `bc1cd97acdafba043eca17180fdf2961049a46ad`; see [`release69-candidate.md`](release69-candidate.md).
Test window: 2026-10-24 UTC.

## Cell result

**Rocky Linux 10 x86_64 Single-Node: PASS — functional release scope.** This decision covers the functional checklist on issue #200 only. It is not a production-security, isolation-completeness, performance, or scalability certification. The Multi-Node cell is evaluated separately and remains NOT TESTED on R69.

The guest was a fresh overlay from the updated Rocky seed with a documented EPEL pyOpenSSL 25.0.0 seed pin. Normal DNF installed the exact six signed Release 69 EL10 Admiral RPMs with dependency resolution; no force or dependency bypass was used. The supported secure Single-Node installer completed. The exact RPM manifest and signatures are recorded in [`release69-candidate.md`](release69-candidate.md).

| Functional check | Result | Evidence |
|---|---|---|
| Install and initialize exact R69 packages | PASS | `rocky-single-install.log`, `rocky-single-postinstall.log` |
| Local API/portal service health and rootless Podman/systemd workload baseline | PASS | `rocky-single-postinstall.log` |
| Provision workload; running/healthy/available, PostgreSQL ready, HTTP 200 and SQL marker | PASS | `rocky-single-lifecycle.log` |
| Same-key replay and concurrent same-key provision do not duplicate the instance | PASS | `rocky-single-lifecycle.log`, `rocky-r69-single-concurrent-idempotency.sh.log` |
| Resize small→medium→small; retain SQL marker, health and HTTP 200 after each change | PASS | `rocky-single-resize-functional-retry.log` |
| Pause/resume, stop/start/restart the instance; restart/stop/start `admirald` and confirm service recovery | PASS | `rocky-single-control-plane-lifecycle.log` |
| Concurrent resize/delete reaches the expected terminal deprovisioned state | PASS | `rocky-r69-single-concurrent-update-delete.sh.log` |
| Declared failing PostgreSQL service is reported failed/unavailable and cleaned up | PASS | `rocky-r69-single-failed-service.sh.log` |
| PostgreSQL stop/recovery preserves marker and availability converges | PASS | `rocky-r69-single-db-service-outage.sh.log` |
| Process/Quadlet and rootless user-systemd recovery | PASS | `rocky-r69-single-process-recovery.sh.log`, `rocky-r69-single-user-systemd-restart.sh.log` |
| Local backup/restore preserves SQL data, returns HTTP 200 and cleans backup | PASS | `rocky-r69-single-backup-restore.sh.log` |
| Guest reboot changes boot ID; services/workload recover, SQL marker persists, HTTP 200 | PASS | `rocky-single-host-reboot.log` |
| Deprovision removes test workload resources | PASS | lifecycle, failure, recovery, backup/restore, resize and reboot logs |

## Reproduction and evidence

Scenario scripts are under [`scripts/r69/`](../scripts/r69/). In particular, [`r69-single-resize-functional.sh`](../scripts/r69/r69-single-resize-functional.sh) verifies both resize directions while checking SQL and HTTP continuity. Raw logs are preserved mode `0600` in the ignored local validation directory `packaging/build/validation/rc5-r69/`. Their SHA-256 values are in [`release69-rocky-single-node-log-sha256.txt`](release69-rocky-single-node-log-sha256.txt).

An initial resize harness attempt ended when its parser did not account for the CLI's confirmation prompt before JSON. The operation itself had succeeded and the cleanup completed. The parser was corrected to locate the JSON object, then the full small→medium→small run passed with a retained SQL marker and HTTP 200 at both sizes. The failed harness capture is retained and its hash is included in the log manifest.

## Exclusions

This functional cell result does not validate public DNS/certificate deployment, direct cross-workload DB-IP isolation, external S3/volume backups, exhaustive security controls, resource exhaustion, stress or performance percentiles. Those are outside the Rocky functional release gate in issue #200. No production-readiness claim is made.
