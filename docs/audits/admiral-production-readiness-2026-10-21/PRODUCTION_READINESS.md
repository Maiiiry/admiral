# Production readiness decision

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Audit began: 2026-10-21 UTC<br>
Latest local RPM set: Admiral RC5 Release 62, built from root commit `df279377c1e558ad5256c6457f3795665f1963de` with component SHAs recorded in `evidence/release62-rocky-single-node-invalidation.md`. The exact packages were installed on a fresh Rocky Linux 10.2 guest. Two host-reboot probes returned stale pre-boot `running/healthy/available` state before fresh workload health and database readiness, invalidating R62 under #256. The local RPM build used `--nodeps`; a clean builder-side dependency-resolved build is still required. Fix `admirald@351a713` passed the full local Go suite, vet/build and CI [39883445112](https://github.com/admiral-project/admirald/actions/runs/39883445112). Root refs and all six RPM release numbers are prepared for R63; no R63 RPMs have been built.<br>
The active matrix is Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10, x86_64 only, in Single-Node and Multi-Node. Current completion is **0/8**; both topology decisions are **NOT VALIDATED**. R62 has targeted Rocky Single-Node diagnostics only, invalidated for matrix credit; no complete cell passed. Fedora, Alma, CentOS and all four Multi-Node cells have no R62 runs. Rocky's EPEL pyOpenSSL 25.0.0 pin remains a visible validation-seed exception.

## Current decision by topology

| Topology | Decision | Basis |
| --- | --- | --- |
| Single-Node | **NOT VALIDATED** | R62 install and scoped Rocky checks ran, but two host reboots reproduced stale pre-boot healthy availability. No full cell passed; Fedora, Alma, CentOS, controlled load/performance and several security/resilience scenarios remain untested. |
| Multi-Node | **NOT VALIDATED** | No R62 three-guest topology ran. All four cells remain NOT TESTED. |

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

The production-readiness question cannot yet be answered: **Single-Node and Multi-Node are NOT VALIDATED** and the matrix remains 0/8. The exact R62 candidate has partial targeted Single-Node diagnostics on Rocky only and is invalidated by #256; no full cell has passed. Admirald's 15-second stale-health fix is pushed and CI-green but not yet packaged into a runtime candidate. Fedora, Alma, CentOS, active-task crash windows, most cross-workload isolation negatives, resource exhaustion, latency, external storage, controlled performance and all Multi-Node full-cell scenarios remain outstanding. No production readiness claim is made.
