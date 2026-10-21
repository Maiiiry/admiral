# Production readiness decision

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Audit began: 2026-10-21 UTC<br>
Latest candidate: six coordinated Release 46 RPMs were built from root package-preparation commit `7223561646b60d3c24e8bfb257d544a5eb6dea04` and installed on fresh Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 Single-Node guests.<br>
Named targeted probes passed on all four Single-Node guests; no full cell has passed and current matrix status remains **0/8**. Release 45 remains invalidated by HIGH finding `ADM-F-009` / #229. Historical Release 42/43/45 results do not count for this candidate.

## Current decision by topology

| Topology | Decision | Basis |
| --- | --- | --- |
| Single-Node | **NOT VALIDATED** | Release 46 was installed on all four target distributions and named install/lifecycle probes passed. Persistence, isolation, concurrency, backup/restore, broad failure and performance coverage is incomplete across all four OS cells. |
| Multi-Node | **NOT VALIDATED** | No Release 46 three-guest scenario has run. The shared control-plane queue fix still needs a fresh Multi-Node regression, followed by the complete four-OS scenario set. |

Neither topology is READY or CONDITIONALLY READY on the current evidence. Build and unit-test success do not establish runtime readiness. No production system was touched.

## Historical Release 42 decision (superseded)

| Topology | Decision | Basis |
| --- | --- | --- |
| Single-Node | **NOT READY** | Scoped install/lifecycle evidence exists on all four OS targets, but full coverage is incomplete. Two open HIGH findings affect this mode: production config accepts shipped `__REQUIRED__` values for the secrets encryption and Fleet callback keys (`ADM-F-007` / #212), and a failed declared workload service can still produce `succeeded` provisioning and `healthy` instance state (`ADM-F-006` / #227). Repeated provisioning created distinct instances on all four distributions (`ADM-F-001`). Harbor rendered an unsafe percent-encoded script URL on Rocky and Fedora (`ADM-F-004`, MEDIUM). Concurrent update/delete, isolation negatives, stress/fault coverage, controlled performance and full matrix remain outstanding. HTTP/2 network exposure in this mode was not established. |
| Multi-Node | **NOT READY** | AlmaLinux now has a scoped three-node install, placement, worker outage/rejoin, hub peer-loss on power-cycle (`ADM-F-005`), local PostgreSQL backup/restore, failed-service false health (`ADM-F-006`), and false-success deprovision with remaining Podman resources (`ADM-F-008`). Rocky and Fedora placed workloads on both workers and preserved SQL markers across worker reboots; their hubs also lost peers on startup. CentOS Stream has a scoped three-guest install, placement, local PostgreSQL backup/restore and cleanup; it reproduced hub restart peer loss, false healthy state with a failed DB (`ADM-F-006`), duplicate same-customer provisions across workers (`ADM-F-001`), and stale healthy instance state after worker loss (`ADM-F-002` / #208). Five open HIGH findings block readiness: reachable Go HTTP/2 advisories (`ADM-F-003`), hub peer-recovery defect (`ADM-F-005`), failed-service status (`ADM-F-006`), placeholder secret acceptance (`ADM-F-007` / #212), and false-success cleanup with residual resources (`ADM-F-008` / #228). Rocky, AlmaLinux and CentOS Stream outages left assigned instances reporting stale `running/healthy` after workers were marked offline. External S3 and volume backup/restore, database outage, latency injection, task replay/lease behavior, conflicting updates/deletes, full security negatives, performance and complete distribution coverage remain open. |

The NOT READY statuses in this historical table applied to Release 42 runtime evidence. They do not validate or determine Release 46's runtime status. Release 45's limited executions are candidate-specific, and #229 invalidated them for the active candidate.

## Candidate identity and host

Release 46 source pins and all six RPM Release fields are prepared on `main` at package-preparation commit `7223561646b60d3c24e8bfb257d544a5eb6dea04`. The component fix is `admirald@e2b4fcee8fcd63d3c66b9f659156874d2a1bbb09`; component CI passed at [run 39685965525](https://github.com/admiral-project/admirald/actions/runs/39685965525), and root build/package CI passed at [run 39686130018](https://github.com/admiral-project/admiral/actions/runs/39686130018). The six Release 46 RPMs were built, published to the isolated local repository, and installed on fresh Single-Node guests for all four target distributions.

Before the Release 46 build, `python3 scripts/validate-release-refs.py` passed after fetching all five component submodules and confirming their pins equal `origin/main`. The six exact Release 46 NEVRAs and SHA-256 values are recorded in `evidence/release46-candidate.md` and `evidence/release46-rpm-sha256.txt`. Fresh Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 Single-Node guests have installed the candidate and completed named targeted probes. No Release 46 Multi-Node scenario has run. The lab host is Rocky Linux 10.2 x86_64, 4 vCPU, 8 GiB RAM, 4 GiB swap and KVM/QEMU 10.1/libvirt 11.10. Guest tests use isolated libvirt VMs. The target is Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 x86_64 in Single-Node and Multi-Node (eight cells).

## What would change this decision

The target matrix remains Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 on x86_64 in both topologies (eight cells). Complete every required Single-Node scenario on fresh guests and every Multi-Node scenario on isolated three-guest topologies. Re-run applicable regressions from #207–#212 and #227–#229 before disposition; do not close findings because the code or unit tests changed. Include high-impact isolation, integrity, recovery, concurrency and false-completion scenarios. Performance measurements must include sample counts and percentiles, without invented SLOs. Any newly discovered defect requiring a fix invalidates the current candidate evidence and requires a new coordinated six-RPM Release plus reruns on the new candidate.

## Current answer to the audit question

The Release 46 production-readiness question cannot yet be answered: **Single-Node and Multi-Node are NOT VALIDATED** and the matrix remains 0/8. Fresh Release 46 Single-Node guests for all four target distributions passed named installation and workload lifecycle probes, including provision, effective-port HTTP, explicit-key replay, deprovision and cleanup where recorded. Fedora also passed targeted failed-service and stale-task-after-reboot regressions. These are scenario-level results, not full-cell passes. No Release 46 Multi-Node scenario has run. Concurrency, comprehensive isolation negatives, resource exhaustion, latency, external storage, database outage recovery, controlled performance, and all full-cell scenario sets remain outstanding. No production readiness claim is made.
