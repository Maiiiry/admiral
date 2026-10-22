# Production readiness decision

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Audit began: 2026-10-21 UTC<br>
Latest built RPM set: Admiral RC5 Release 55, built from root candidate source `d5654ac776617154e2d63cb745d81c8d2ac9ee22`. All six package checks passed. Fresh Fedora Rawhide and Rocky Linux 10 Single-Node probes were partial; Fedora reboot exposed false healthy/available state while PostgreSQL was not ready. R55 is **INVALIDATED** by #256; evidence and exact package hashes are in `evidence/release55-candidate.md` and `evidence/release55-invalidation-reboot-health.md`. A boot-ID fix is pushed as `admirald@a816f47` and `admiral-fleet@74e8b0f`; DB-backed regression and local full suites passed. Fleet CI [39819815054](https://github.com/admiral-project/admiral-fleet/actions/runs/39819815054) is green; admirald CI [39820151915](https://github.com/admiral-project/admirald/actions/runs/39820151915) passed on `9b8f129`. Release 56 has not been prepared or built. No R55 observation counts toward a matrix cell.<br>
The active matrix is Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10, x86_64 only, in Single-Node and Multi-Node. Current completion is **0/8**; both topology decisions are **NOT VALIDATED**. All four Release 56 Single-Node cells and all four Multi-Node cells are NOT TESTED. No issue was closed. Rocky's EPEL pyOpenSSL 25.0.0 pin remains a visible validation-seed exception.

## Current decision by topology

| Topology | Decision | Basis |
| --- | --- | --- |
| Single-Node | **NOT VALIDATED** | R55 ran scoped install, lifecycle, backup/restore, isolation and recovery probes on Fedora and Rocky, but the candidate is invalidated by #256 and none counts as a cell. All four Release 56 cells are NOT TESTED. Full lifecycle, safety, recovery, load and performance coverage remain. |
| Multi-Node | **NOT VALIDATED** | No R55 or R56 three-guest topology ran. All four Release 56 cells remain NOT TESTED. |

Neither topology is READY or CONDITIONALLY READY on the current evidence. Build and unit-test success do not establish runtime readiness. No production system was touched.

## Historical Release 42 decision (superseded)

| Topology | Decision | Basis |
| --- | --- | --- |
| Single-Node | **NOT READY** | Scoped install/lifecycle evidence exists on all four OS targets, but full coverage is incomplete. Two open HIGH findings affect this mode: production config accepts shipped `__REQUIRED__` values for the secrets encryption and Fleet callback keys (`ADM-F-007` / #212), and a failed declared workload service can still produce `succeeded` provisioning and `healthy` instance state (`ADM-F-006` / #227). Repeated provisioning created distinct instances on all four distributions (`ADM-F-001`). Harbor rendered an unsafe percent-encoded script URL on Rocky and Fedora (`ADM-F-004`, MEDIUM). Concurrent update/delete, isolation negatives, stress/fault coverage, controlled performance and full matrix remain outstanding. HTTP/2 network exposure in this mode was not established. |
| Multi-Node | **NOT READY** | AlmaLinux now has a scoped three-node install, placement, worker outage/rejoin, hub peer-loss on power-cycle (`ADM-F-005`), local PostgreSQL backup/restore, failed-service false health (`ADM-F-006`), and false-success deprovision with remaining Podman resources (`ADM-F-008`). Rocky and Fedora placed workloads on both workers and preserved SQL markers across worker reboots; their hubs also lost peers on startup. CentOS Stream has a scoped three-guest install, placement, local PostgreSQL backup/restore and cleanup; it reproduced hub restart peer loss, false healthy state with a failed DB (`ADM-F-006`), duplicate same-customer provisions across workers (`ADM-F-001`), and stale healthy instance state after worker loss (`ADM-F-002` / #208). Five open HIGH findings block readiness: reachable Go HTTP/2 advisories (`ADM-F-003`), hub peer-recovery defect (`ADM-F-005`), failed-service status (`ADM-F-006`), placeholder secret acceptance (`ADM-F-007` / #212), and false-success cleanup with residual resources (`ADM-F-008` / #228). Rocky, AlmaLinux and CentOS Stream outages left assigned instances reporting stale `running/healthy` after workers were marked offline. External S3 and volume backup/restore, database outage, latency injection, task replay/lease behavior, conflicting updates/deletes, full security negatives, performance and complete distribution coverage remain open. |

The NOT READY statuses in this historical table applied to Release 42 runtime evidence. They do not validate or determine the next candidate status. Release 45–47 observations are candidate-specific and do not carry forward.

## Candidate identity and host

Release 46 is historical. Its source pins and six RPMs were built at package-preparation commit `7223561646b60d3c24e8bfb257d544a5eb6dea04`; its targeted guest observations are retained below and in `evidence/`, but do not count for the rebuilt candidate. Rocky Linux 10 is back in the active scope; its Release 46 dependency-resolution failure and workaround remain historical evidence only.

The Release 46 reference check, exact NEVRAs, hashes and targeted observations are recorded in `evidence/release46-candidate.md` and `evidence/release46-rpm-sha256.txt`. The lab host is Rocky Linux 10.2 x86_64, 4 vCPU, 8 GiB RAM, 4 GiB swap and KVM/QEMU 10.1/libvirt 11.10. Guest tests use isolated libvirt VMs. The active target is Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 x86_64 in Single-Node and Multi-Node (eight cells).

## What would change this decision

The target matrix is Fedora Rawhide, Rocky Linux 10, Alma Linux 10 and CentOS Stream 10 on x86_64 in both topologies (eight cells). Complete every required Single-Node scenario on fresh guests and every Multi-Node scenario on isolated three-guest topologies. Re-run applicable regressions from #207–#212, #227–#230 and #234–#244 before disposition; do not close findings because the code or unit tests changed. Include high-impact isolation, integrity, recovery, concurrency and false-completion scenarios. Performance measurements must include sample counts and percentiles, without invented SLOs. Any newly discovered defect requiring a fix invalidates the current candidate evidence and requires a new coordinated six-RPM Release plus reruns on the new candidate.

## Current answer to the audit question

The production-readiness question cannot yet be answered: **Single-Node and Multi-Node are NOT VALIDATED** and the matrix remains 0/8. Release 55 was built and invalidated by #256 after real Fedora Single-Node reboot testing found a transient false-availability window. The source fix is pushed but has not been packaged or validated. No complete cell has passed on the latest candidate. Cross-workload isolation negatives, conflicting update/delete, active-task crash windows, resource exhaustion, latency, external storage, database outage recovery, controlled performance and all Multi-Node full-cell scenarios remain outstanding. No production readiness claim is made.
