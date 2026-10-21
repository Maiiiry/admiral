# Rocky Multi-Node workload placement and worker recovery

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Root source: `748b703662eafdaf3919bad28787d0264f06bf16`; Release 42 x86_64 Admiral RPMs.<br>
Guests: Rocky Linux 10.2 x86_64 hub `.110`, worker1 `.111` (`10.99.0.2`), worker2 `.112` (`10.99.0.3`); 2 vCPU/2 GiB each.<br>
The isolated cluster used an admin-portal hub at `10.99.0.1` and two workers. After the hub WireGuard configuration was manually restored as described in `rocky-multi-hub-reboot.md`, all three nodes reported `active/healthy/available` and two peers had fresh handshakes.

## Placement

`examples/apps/e2e-whoami.yaml` was applied on the hub. Two explicit `admiralctl instances provision --wait --quiet --output json` requests succeeded:

| Instance | Requested node | Operation | Operation interval |
| --- | --- | --- | --- |
| `inst_5616d3d8aca65be1` | `rocky-r42-worker1` | `op_bd5043fdf20b6558` — succeeded | 14:08:37.836–14:08:42.098 UTC |
| `inst_2d94df69692563e7` | `rocky-r42-worker2` | `op_8427c9b8b394cad3` — succeeded | 14:08:44.156–14:08:48.498 UTC |

The hub returned both records as `running/healthy` on the requested nodes. Each worker's rootless Podman showed the corresponding infra, app and database containers `Up`; `pg_isready` reported accepting connections. Quadlet `.pod`, `.volume`, `.container` files were root-owned mode `0644` in the package-managed per-user directory. Raw sanitized-console source log is ignored, mode `0600`, SHA-256 `9cdd4ac1b4125f8e0cc5ea37345978928194d9fddd9f5fe944a315a2aa2c3815`.

## Process crash and worker reboot

On worker1, the app container was terminated with `podman kill --signal SIGKILL`. Its container start timestamp changed from `2026-10-21 14:08:46.208Z` to `14:11:06.836Z`, and Podman showed it `Up 2 seconds` on verification. This is evidence of automatic systemd/Quadlet process recovery for this sample.

On worker2, a table and marker `rocky-worker2-persisted` were created through the running PostgreSQL container using its own secret-provided DB credentials; no credential value was printed. `virsh reboot rc5-r42-rocky-x86-multi-worker2` was requested at `14:12:53Z`. The boot ID changed from `a6192127-d134-44d1-95b4-1a0067db8061` to `4e35ebeb-e4b2-4e19-9a2a-64a3801e27cf`. At the first immediate post-boot check only infra was running and the DB container had not yet appeared; a subsequent check found app, DB and infra `Up`, `pg_isready` accepting connections, and the SQL marker intact. The first check failed because it expected the database container to exist immediately; the follow-up verified eventual recovery and data persistence. No exact convergence duration was captured.

These are scoped placement and worker-recovery samples, not concurrency, node-failure rescheduling, data-backup, or full isolation tests. They do not compensate for the independent hub peer-loading failure in `ADM-F-005`.

Both test instances were subsequently deprovisioned. Each operation returned `succeeded`; both records became `deprovisioned`. On each worker, post-cleanup `podman ps -a`, the test-volume name filter, and the test Quadlet file filter returned zero. The restricted cleanup log is ignored, mode `0600`, SHA-256 `a9af0c7747bd34c3db7e3449b50634cba42d8f56a20b670728de5b704cb3a6dc`.
