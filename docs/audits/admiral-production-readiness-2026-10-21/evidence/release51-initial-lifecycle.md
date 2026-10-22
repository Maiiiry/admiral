# Release 51 initial Single-Node runtime observations

Audit: `ADM-AUDIT-2026-10-21`  
Candidate: Admiral RC5 Release 51, six exact RPMs from package-preparation commit `59e6eeb553ac38d7fa995863202a1180f50c02c5`. Source refs and package hashes are in [`release51-candidate.md`](release51-candidate.md).  
Disposition: **INVALIDATED by issue #245; 0/8 matrix cells passed.** These are scoped candidate observations only, not complete cells.

## Environment and installation

The Rocky Linux 10.2 lab host had 4 vCPU, 8 GiB RAM, 4 GiB swap and KVM/libvirt. Fresh 2-vCPU/2-GiB guests were created from the updated Fedora Rawhide and Rocky Linux 10.2 seeds. The host generated unique SSH host keys and placed pins in per-guest `known_hosts` before first contact. Both connections used `StrictHostKeyChecking=yes`. No full operating-system update was run during this round; the supported installer executed its configured security-update task.

| Test ID | Guest | Procedure and observed result | Status |
| --- | --- | --- | --- |
| R51-FEDORA-SN-INSTALL-001 | `adm-r51-fedora-single`, Fedora Rawhide, `192.168.122.250` | Fresh seed overlay; six exact `0.0.1rc5-51.el10` RPMs installed; secure installer exit 0; SELinux `Enforcing`; all six RPMs present; Admiral services, PostgreSQL, Caddy and firewalld active; `admiralctl status` reported API online/control plane healthy. | PASS — install subset only |
| R51-ROCKY-SN-INSTALL-001 | `adm-r51-rocky-single`, Rocky Linux 10.2, `192.168.122.251` | Fresh seed overlay with the documented EPEL pyOpenSSL pin; six exact `0.0.1rc5-51.el10` RPMs installed; secure installer exit 0; SELinux `Enforcing`; all six RPMs present; Admiral services, PostgreSQL, Caddy and firewalld active; `admiralctl status` reported API online/control plane healthy. | PASS — install subset only |

These PASS rows do not count as matrix passes. The Single-Node scenario catalog was not completed on either guest.

## Fedora lifecycle and availability regression

`examples/apps/e2e-whoami.yaml` was applied to Fedora. Provision operation `op_41317887b69c5ee9`, task `task_8568c9c13e4fcbf0`, created instance `inst_cb3ff3cfb70d10e2` and returned `succeeded` at `05:44:37.170574Z`. Repeating the same customer and idempotency key returned the same operation and instance IDs.

At `05:44:48Z`, the immediate instance query reported `health_status=unhealthy`, `effective_availability=unavailable`, and the database service container as unavailable. At `05:45:18Z`, the instance had converged to `healthy/available`, all three rootless containers were `Up`, and HTTP returned 200. Ten HTTP probes over the following interval returned 200. This is recorded as a cold-database startup observation associated with the existing #227 readiness finding; the sample alone does not establish whether the operation callback preceded database readiness.

Pause operation `op_179ee1c2dc4dd8e0` succeeded at `05:47:19Z`. The instance then had `technical_status=stopped`, while `health_status=healthy` and `effective_availability=available`; a request to the mapped app endpoint failed immediately to connect. Resume operation `op_75f69e18aef4ef00` and restart operations `op_7a28a1fe75fdc701` / `op_26dcd3902478e813` succeeded; after each, the instance returned to `running/healthy/available` and HTTP returned 200.

Deprovision operation `op_c7d558ea106d6fc9` succeeded at `05:48:09.932880Z`. The durable record showed `technical_status=deprovisioned`, `commercial_status=cancelled`, `health_status=healthy`, and `effective_availability=available`. Rootless Podman had no matching containers or volumes, no matching user units remained, and no matching `/var/lib/admiral` paths remained. This reproduced #245. Static inspection confirmed the shared availability SQL ignored `technical_status`.

The correction was pushed to `admirald/main` as `0baf488353386fdb67f995ef3e72cfe6cfc6de07`, adding unavailable lifecycle reasons and regression checks for stopped, storage-paused, deprovisioning and deprovisioned states. Full local tests, `go vet`, `go build`, and component CI [39730492772](https://github.com/admiral-project/admirald/actions/runs/39730492772) passed. #245 remains open with `fix-proposed` pending a rebuilt RPM and fresh runtime regression. R51 is invalidated; its runtime results do not count toward the matrix.

## Restricted raw evidence

Raw files are retained on the lab host under `packaging/build/validation/rc5-r51/evidence/`, mode `0600`; they are excluded from Git. SHA-256 values:

| File | SHA-256 |
| --- | --- |
| `adm-r51-fedora-single-install.log` | `cd0ecdf1aa34235891dd0feec10018fab5dfdb9a7959aaaba687ae59bc5964df` |
| `adm-r51-fedora-single-baseline.txt` | `2ae2bab1de12f2e64ce0ee2aa0673317a725e43fb010645a3d5305b0fce8cf5d` |
| `adm-r51-fedora-single-smoke.txt` | `b111ac71c8813a2aec850900d5d85c4f6ebfbb2df6dce99398ed036dd43be706` |
| `adm-r51-fedora-single-provision.json` | `22de563a749d2137b3bd93cf9fbdc4fea5fd4dab73471b9ed5e2a240883be399` |
| `adm-r51-fedora-single-provision-replay.json` | `3b3445cd9ae29ea4eec20350e822bd9abf9c807d0d5e4e09be1cbd14aab3cead` |
| `adm-r51-fedora-single-provision-convergence.txt` | `4df73f0e6bfdaa1bb5cd16729b9a6de402638bfc53a71b46661dade264f27dc8` |
| `adm-r51-fedora-single-instance-show.txt` | `2dd521ec100862d7f1e86df9fbc372a6e17b9a772503d4b3d9cc11735f3302e3` |
| `adm-r51-fedora-single-podman-ps.txt` | `39930c1c71d8c699aadd948fc7e94a02846587e2e70f84cd17c52e750f1188e7` |
| `adm-r51-fedora-single-lifecycle-operations.txt` | `f6a3325810f21327c3cc9ed537bac53fe0c137301e2a38576b3dcdf74219b621` |
| `adm-r51-fedora-single-deprovision-cleanup.txt` | `8b1cd1190f112d0c2a043584c4115c28e5482e28075d2e88467c5e13087e51a2` |
| `adm-r51-rocky-single-install.log` | `a4dbe066a42b9136dc4ef7022739a3fe6a36fbcd5b83c1df12da0bc5aefcef7b` |
| `adm-r51-rocky-single-baseline.txt` | `f4fc35db914dbe144be11d7aeba6cd342b6a9f5e7dbd5abbcb717122a770be66` |
| `adm-r51-rocky-single-smoke.txt` | `54083104840162164ad58471c025a623008bea3938ed7e10377b71b9b2f93485` |

Both guests were shut down and removed with the audited cleanup helper. The four updated seed images and both R51 repositories were preserved. No Multi-Node test was run.
