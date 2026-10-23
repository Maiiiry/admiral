# Release 65 AlmaLinux 10 Multi-Node progress

**Candidate status: INVALIDATED by HIGH issue #264; contributes 0/8.** The central PostgreSQL outage regression failed after the positive named scenarios below. All previous R65 results are retained as diagnostics only. See [`release65-invalidation-central-db-auth.md`](release65-invalidation-central-db-auth.md).

Audit: `ADM-AUDIT-2026-10-21`  
Scenario run: `ALMA-R65-MN-WG-PARTITION-W2`  
Candidate root: `967920fb122f09521444c9f6e27d3db0c836becc`  
Runtime: AlmaLinux 10.2 x86_64; one 2-GiB admin/portal hub and two 2-GiB workers; three isolated guests. Six Admiral R65 EL10 RPMs were installed on the hub and `admiral-fleet-0.0.1rc5-65.el10` on both workers.

## Current candidate coverage

The R65 hub and both workers installed successfully. The hub registered both workers as active/healthy with WireGuard handshakes. Two concurrent, explicitly targeted `e2e-whoami` provisions on separate workers completed and returned HTTP 200 through the overlay. A repeated idempotency key replayed the same operation and instance on its original worker; reuse for a different target worker returned HTTP 409. These named scenarios do not complete the matrix cell.

Additional R65 Alma Multi-Node scenarios completed:

* Suspending and resuming W2 made its workload unavailable during the outage and restored the same instance after rejoin; a SQL marker persisted.
* Rebooting the hub restored its WireGuard peers and worker heartbeats automatically. A worker SQL marker persisted.
* Unauthenticated and synthetic-invalid-token worker requests to selected Fleet and admin endpoints returned HTTP 401; the tested node and operation records did not change.
* A required DB service failure ended as a failed operation and an unhealthy/unavailable instance; deprovision left no matching runtime resources.
* Injected Podman removal errors caused the deprovision operation to fail while resources remained. After restoring the original Podman binary, retry succeeded and cleanup verification found no matching containers, volume, Quadlet or instance data path.
* Local PostgreSQL backup/restore on W2 preserved a SQL marker. Backup `bk_657225abdda46cf4` completed with SHA-256 `24ce2cff59292f36a64451fb16f381c5344c94e4b425aea4d3bd3cbbaf3193eb`; restore while running returned HTTP 409, and the paused restore operation `op_d75b10068a9dc9a4` succeeded with checksum verification. After resume, direct SQL returned `before-backup` and the app returned HTTP 200. The backup record was deleted and deprovision succeeded; cleanup found no matching containers, volume, Quadlet, instance data or archive.

These are scenario results for this candidate only. They do not close GitHub issues or complete the AlmaLinux Multi-Node cell.

## Controlled WireGuard partition and recovery

At `2026-10-23 06:41:35 UTC`, a disposable instance `inst_734b3768ec404df0` was running on W2. The test changed only the hub's runtime WireGuard `AllowedIPs` entry for W2 from `10.99.0.3/32` to `10.99.0.254/32`, which prevented overlay traffic from reaching the hub. A transient systemd timer was armed to restore the peer after 180 seconds; no persistent WireGuard configuration was changed. A prior firewalld rich-rule attempt did not stop the traffic, so that setup attempt received no test credit and its rule was removed.

From W2, the unauthenticated HTTPS probe to the hub timed out while partitioned. The hub's first sampled instance state was `running/healthy/unavailable`; the last healthy observation timestamp remained intact. W2 was marked `offline/degraded` at `06:43:27 UTC`, about 112 seconds after the partition began. W1 continued to send fresh heartbeats and remained `active/healthy`. No automatic workload migration was observed or expected from this architecture.

The runtime `AllowedIPs` entry was restored at about `06:44 UTC`; the worker-to-hub API probe then returned HTTP 401, which confirms connectivity while remaining unauthenticated. W2 reported a fresh heartbeat and `active/healthy` by `06:44:24 UTC`; the instance returned to `running/healthy/available`. Direct SQL returned the pre-partition marker `before-partition`, and the application returned HTTP 200 through the hub overlay. Deprovision completed as operation `op_34a6241193451a4d`. Follow-up checks found no matching containers, volumes, Quadlet files or instance data paths. The automatic restore timer was stopped after the manual restoration and no timer remained active.

**Scenario result: PASS for partition detection and recovery on the R65 AlmaLinux Multi-Node candidate.** This is not a full-cell PASS. No task was in flight; task lease expiry, side-effect replay, callback recovery, automatic migration, latency injection and cross-worker database access remain untested. The central PostgreSQL outage was tested separately and **FAILED** as issue #264; see the invalidation record. This does not prove absence of other defects or justify closing an issue.

The backup/restore result is also scenario-scoped only. The first SQL marker mutation attempt failed because of shell quoting; the failed command is preserved in `alma-multinode-backup-marker-after-mutation.log`, then a SQL-stdin retry succeeded. The restore polling capture repeated read-only status queries after the operation had already reached `succeeded` at poll 3; it was stopped without issuing another operation. Neither harness error changed Admiral state beyond the recorded test actions.

## Evidence files

The network-partition procedure is reproducible with [`scripts/r65/r65-wg-partition.sh`](../scripts/r65/r65-wg-partition.sh); it requires a disposable running instance on W2 and the lab SSH host-key pins. Restricted raw logs are retained with mode `0600` under the ignored local directory `packaging/build/validation/rc5-r65/`. Their SHA-256 hashes are listed in `release65-local-log-sha256.txt`. The partition/recovery captures are `alma-multinode-wg-partition.log`, `alma-multinode-wg-rejoin.log`, `alma-multinode-partition-recovery.log`, `alma-multinode-partition-deprovision.log` and `alma-multinode-partition-cleanup.log`. Backup/restore captures use the `alma-multinode-backup-*` prefix. The first failed firewall setup is retained in `alma-multinode-network-partition.log` and explicitly excluded from results.

The overall release matrix remains **0/8**. R65 is invalidated; AlmaLinux 10 Multi-Node has partial diagnostic evidence, including the #264 failure. The other three Multi-Node cells have not run on R65.
