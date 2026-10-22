# Production readiness decision

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Audit began: 2026-10-21 UTC<br>
Latest built RPM set: Admiral RC5 Release 51, built from package-preparation commit `59e6eeb553ac38d7fa995863202a1180f50c02c5`. All six RPMs built with passing `%check`, and both local repositories returned exactly the six Release 51 NEVRAs. Fresh Fedora Rawhide and Rocky Linux 10.2 Single-Node guests installed R51. Fedora lifecycle testing found #245: API availability remained `available` while a paused or deprovisioned workload was not serving. R51 is invalidated and its observations contribute no matrix passes. The fix is pushed as `admirald@0baf488` with green CI [39730492772](https://github.com/admiral-project/admirald/actions/runs/39730492772); Release 52 preparation has updated the six RPM Releases and source pins, but root CI and the RPM build remain pending.<br>
The active matrix is four x86_64 distributions (Fedora Rawhide, Rocky Linux 10, AlmaLinux 10, CentOS Stream 10) in Single-Node and Multi-Node. Current completion is **0/8**; both topology decisions are **NOT VALIDATED**. R49–R51 observations do not count toward the corrected candidate. #240, #239, #233, #244 and #245 have source fixes proposed/committed with green component/root CI; #241–#243 remain LOW workflow/maintenance follow-ups. No issue was closed. Rocky's EPEL pyOpenSSL pin remains a visible validation-seed exception.

## Current decision by topology

| Topology | Decision | Basis |
| --- | --- | --- |
| Single-Node | **NOT VALIDATED** | R49 exploratory subsets ran on all four operating systems but were invalidated for final validation by #240; no complete cell passed. |
| Multi-Node | **NOT VALIDATED** | No R49 three-guest runs occurred; all four topology cells remain untested on the next candidate. |

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

The production-readiness question cannot yet be answered: **Single-Node and Multi-Node are NOT VALIDATED** and the matrix remains 0/8. R49 was invalidated by #240; R50 was superseded before VM testing by #244; R51 was invalidated after fresh Fedora/Rocky installs when Fedora's pause/deprovision lifecycle probe reproduced #245. The #245 source fix is pushed and green, and Release 52 is in coordinated package preparation. No R51 or earlier observation counts toward the new candidate. No Multi-Node run has occurred on R51. Concurrency, comprehensive isolation negatives, resource exhaustion, latency, external storage, database outage recovery, controlled performance and all complete-cell scenario sets remain outstanding. No production readiness claim is made.
