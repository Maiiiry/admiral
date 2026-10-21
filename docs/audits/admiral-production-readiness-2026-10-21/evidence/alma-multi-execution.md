# AlmaLinux 10.2 x86_64 Multi-Node execution

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Source: root `748b703662eafdaf3919bad28787d0264f06bf16`; candidate submodule SHAs are in `source-manifest.txt`.<br>
Candidate: six Release 42 RPMs, `0.0.1rc5-42.el10`; exact SHA-256 values are in `candidate-rpm-sha256.txt`.<br>
Topology: three isolated libvirt VMs, each 2 vCPU / 2 GiB RAM, SELinux Enforcing. Hub `adm-audit-alma-hub` (`192.168.122.150`, WireGuard `10.99.0.1`); workers `adm-audit-alma-worker1` (`.151`, `10.99.0.2`) and `adm-audit-alma-worker2` (`.152`, `10.99.0.3`). No production host or service was involved.

Private SSH identities and unsanitized installer logs remain outside Git in the ignored local validation directory with mode `0600`. The installer logs are identified by SHA-256 below; they were not copied into the repository.

## Installation and registration

Both workers were installed from the supported `--worker-node` profile through the installed hub. Bootstrap completed successfully on both. Each recap reported `ok=146 changed=51 unreachable=0 failed=0 skipped=216 rescued=0 ignored=0`. Worker2 install helper recorded start `2026-10-21T13:10:07Z`, completion `13:17:40Z`, exit 0 (7m33s wall time, including package/security update and secure setup). Worker1 raw log filesystem mtime was `13:08:57Z`; its helper exited 0. The raw worker logs have mode `0600` and SHA-256:

* Worker1: `3be4871963def0f08d61d6c7cf9651f1b1a5b6deac9438875b5b9eb7641032c6`.
* Worker2: `e69500fa735c0fd75349507d7652b4756f14809071124eceb7a0fc73f9c707b2`.

`admiralctl nodes list --output json` showed the hub portal and both workers `active/healthy`; the workers reported the expected WireGuard addresses and `available_for_provisioning=true`. A hub WireGuard query showed recent handshakes for both worker peers. Fleet was active on both workers; the hub correctly ran Admirald/Harbor/Flagship and did not run Fleet.

## Workload placement and runtime

Applied `examples/apps/e2e-whoami.yaml` to the hub, then issued explicit, waited provisions:

| Test | Instance | Requested worker | Control-plane result | Runtime observation |
| --- | --- | --- | --- | --- |
| ALMA-MN-001 | `inst_51475b49fa4b9b7f` | `adm-audit-alma-worker1` | operation succeeded; instance `running/healthy`, storage `ok` | worker1 rootless Podman showed infra, app (`traefik/whoami:v1.10`) and PostgreSQL 16 containers `Up` |
| ALMA-MN-002 | `inst_ca49a728cc4b0758` | `adm-audit-alma-worker2` | operation succeeded; instance `running/healthy`, storage `ok` | worker2 rootless Podman showed infra, app and PostgreSQL 16 containers `Up` |

The instance records retained the requested worker IDs. `admiral-apps` had `Linger=yes`; per-instance user systemd units for pod, app and database were active. Quadlet files were under `/etc/containers/systemd/users/993/admiral/`, mode `0644`, owner `root:root`. App, pod and DB units declared `Restart=always`; the DB volume was a named persistent volume. DB Quadlets contained `Secret=` references for generated user/password values; secret values were not read or recorded. Runtime Podman inspection showed `Privileged=false`, private PID namespace and `no-new-privileges` for the app container. This is a positive sample, not a complete isolation or secrets-access audit.

## Worker outage and recovery

At `13:20:32Z`, the host suspended worker1 with `virsh suspend adm-audit-alma-worker1`. No packets were selectively filtered; this is a whole-VM pause test, not a network-partition test. At 60 and 90 seconds, the node still appeared active because the configured offline threshold is 2 minutes. At `13:22:57Z` (145 seconds after suspension), Admirald logged `Nodes marked offline by health monitor` for worker1. Its node record became `status=offline`, `health_status=degraded`, `available_for_provisioning=false`, reason `heartbeat_timeout`; worker2 and the hub remained healthy.

During that interval, the bound instance still reported `technical_status=running` and `health_status=healthy`; its `last_health_checked_at` was `13:20:20Z`, before the node pause. This is stale last-known instance state while the node was offline. No automatic migration or replacement instance was observed or expected by this single-hub/spoke architecture. This state-reporting gap is tracked as `ADM-F-002`.

At `13:23:42Z`, the host resumed worker1 with `virsh resume`. All three existing containers were `Up` after recovery; no additional instance IDs appeared. A new worker heartbeat arrived at `13:24:41Z`, 59 seconds after resume, and the node returned to `active/healthy/available_for_provisioning=true`. The instance remained assigned to worker1 and returned to a fresh healthy check. The other worker stayed available throughout.

## Worker guest reboot

Before reboot, worker1 reported boot ID `903a8c1d-f759-4164-aee5-f97dd967b33c`; its DB container mounted the named Quadlet volume `admiral-inst_51475b49fa4b9b7f-db` at `/var/lib/postgresql/data`, and `pg_isready -q` succeeded. `virsh reboot adm-audit-alma-worker1` was requested at `13:33:22Z`. SSH briefly refused connections during boot; after recovery, the boot ID was `f2c731bb-c590-41a2-8172-1657038d52b9`. The same infra/app/DB containers were `Up`, `pg_isready -q` succeeded, and the node reported `active/healthy/available_for_provisioning=true` with a fresh heartbeat at `13:34:10Z`. This confirms Quadlet startup and database process availability after a worker guest reboot. It does not verify a user-data marker across this worker reboot; the Single-Node marker backup/restore and persistence check is documented separately.

## Hub power-cycle and manual lab recovery

**ALMA-MN-006 — FAIL for automatic recovery / HIGH `ADM-F-005` (#211).** After the three AlmaLinux guests had been shut down from the prior run, all three were started from their existing disks. At `17:05:16Z`, the hub's `wg-quick@wg-admiral` service was active, but `/etc/wireguard/wg-admiral.conf` had zero `[Peer]` sections and `wg show wg-admiral peers` returned zero peers; two durable files remained in `/etc/wireguard/peers.d/`. PostgreSQL, Admirald and Harbor were active on the hub. Both workers had booted and their existing workload containers were `Up`, but Admirald reported them `offline/degraded`, unavailable for provisioning, with their last heartbeats from `13:54Z`.

The isolated lab was recovered by appending the two persisted peer fragments to the hub's main config and restarting `wg-quick@wg-admiral`. The action began at `17:05:36Z`; the unit returned active with two runtime peers. By `17:06:25Z`, both peers had handshakes and both workers were `active/healthy/available_for_provisioning=true`; their existing instances retained their IDs. No product configuration was changed in the repository. This is manual recovery, not a PASS for hub recovery. The restricted raw logs are `audit-alma-multi-hub-restart.log` (SHA-256 `db941e6a655fe9f7f9461fc1047b9b675e812bd7a174b5b8c14be221173e2347`) and `audit-alma-multi-hub-recovery.log` (SHA-256 `5b6151bd740c6aa9611164353cf432661ec7297dfb18c51453e964dd139ccc48`), both mode `0600` under the ignored validation directory.

## Local PostgreSQL backup and restore on worker2

**ALMA-MN-007 — PASS for this backup/restore scenario only.** Applied the tracked disposable fixture `fixtures/e2e-backup.yaml` and provisioned customer `audit_alma_multi_backup_20261021` on `adm-audit-alma-worker2`: operation `op_1c38724ac443b1f5`, instance `inst_ff754bda50588b78`. A direct SQL marker `alma-mn-backup-restore-20261021=original` was written to its PostgreSQL database. Backup operation `op_1b11e06ed2495dcb` created local backup `bk_3abbbc41ebbc68b7` (755 bytes, SHA-256 `dbaff136dab804ec87e152212ed88d370d2dc6fc16038d871f634a9b3888ef14`); the artifact was `0600 admiral-apps:admiral-apps`.

After changing the marker to `mutated-after-backup`, restore while running was rejected with HTTP 409, as required. Pause operation `op_937967c075a7f7de` succeeded; restore operation `op_6ead4d75d0814f0e` succeeded with checksum verification; resume operation `op_25b2644e7aef3eda` succeeded. Direct SQL returned `original`. Immediately after resume, the API briefly retained `stopped` with the prior health timestamp; by `17:10:13Z` it reported `running/healthy`. The backup was deleted after explicit confirmation (an initial interactive delete attempt was cancelled and is preserved in the raw log); deprovision `op_e5ce1fff7e424a2b` succeeded. The instance is `deprovisioned`, backup status is `deleted`, and checks found zero matching containers, volumes, Quadlet files or backup archives. Restricted raw log: `audit-alma-multi-backup-restore.log`, SHA-256 `e446a77998f3847b7ecc1d2f5122f221a8a28bd38707fa0ec26cf391592ccf98`, mode `0600`.

This tests local PostgreSQL backup/restore only. S3, volume backup/restore, cross-customer access, external Harbor upload restore and task-interruption recovery remain untested.

## Declared-service failure injection on worker2

**ALMA-MN-008 — FAIL / HIGH `ADM-F-006` (#227).** Applied `fixtures/e2e-failing-db.yaml`, which keeps the public `whoami` app service running while the required PostgreSQL service executes `/bin/false`. Provisioning operation `op_fe3466ba3ea600f1` succeeded on `adm-audit-alma-worker2` and created instance `inst_99638db42b29ac56`.

The control plane still reported `technical_status=running` and `health_status=healthy` at captures `17:15:46Z` and `17:17:07Z`, with a fresh health-check timestamp, even though the generated `admiral-inst_99638db42b29ac56-db.service` was `failed` (`Result=exit-code`, `ExecMainStatus=1`, `NRestarts=5`) from `17:13:40Z`. The DB container was absent; the Podman pod and app/infra containers remained running. This remained divergent for over three minutes after the operation completed; it is a failed required-service state, not merely an early health-check race.

Deprovision operation `op_e31b2d55a055d57e` succeeded. The instance is `deprovisioned`; supported Podman inventory commands returned no matching containers, pod, or volume, and there were no matching Quadlet files, instance data directory, or user units. Restricted raw evidence is `audit-alma-multi-failing-db.log`, SHA-256 `1968c8ad672eadafd3737d203aa9e8f1cc4a750cf8f793935b7e56188f3a9992`, mode `0600`; it includes the correction for an earlier mistyped unit query and failed inventory-command syntax before the successful final cleanup capture.

## Results and limits

* **PASS (scoped scenarios):** supported three-node bootstrap, authenticated WireGuard peer setup, live worker registration, explicit workload placement on both workers, rootless Podman/systemd/Quadlet runtime, worker offline detection and rejoin, and local PostgreSQL backup/restore.
* **FAIL:** hub power-cycle did not load the two durable WireGuard peer fragments; manual lab recovery was required (`ADM-F-005` / #211). A declared failed DB service also left the operation successful and instance healthy (`ADM-F-006` / #227).
* **Observation / finding:** effective instance health is not degraded while its assigned node is offline; only the stale check timestamp exposes that condition (`ADM-F-002`).
* **Expected design limit:** an unavailable worker's workload is not migrated automatically. Recovery requires that worker to return or an operator to perform a separately audited migration/reprovisioning action.
* **NOT TESTED:** hub/database outage, real hub-worker network partition or latency, simultaneous admin requests, task interruption during side effects, node removal, cross-node authorization negatives, and automatic migration (not implemented).
* This AlmaLinux 10.2 execution is scoped evidence for the AlmaLinux x86_64 Multi-Node target cell. It does not substitute for the other three distributions or complete the full Multi-Node scenario catalog.
