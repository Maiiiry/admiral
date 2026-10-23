# Production readiness decision

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Audit began: 2026-10-21 UTC<br>
Latest candidate: RC5 Release 65, built from root commit `967920fb122f09521444c9f6e27d3db0c836becc`, is **INVALIDATED** by HIGH issue [#264](https://github.com/admiral-project/admiral/issues/264). During a real central PostgreSQL outage in the three-guest AlmaLinux Multi-Node setup, valid worker tokens consumed the invalid-auth limiter, then received HTTP 429 after PostgreSQL recovered. The root R65 CI run [39895176300](https://github.com/admiral-project/admiral/actions/runs/39895176300) was green, but it does not change this runtime result. A source fix is pushed at `admirald@643d203576037a12eba59d534d51d170acae9b5d`; focused/full tests and vet pass locally, while component CI run [39915433860](https://github.com/admiral-project/admirald/actions/runs/39915433860) is pending. R66 is not built; all six RPMs must be rebuilt and the outage regression rerun before release validation resumes. See [`release65-invalidation-central-db-auth.md`](evidence/release65-invalidation-central-db-auth.md).<br>
The active matrix is Fedora Rawhide, Rocky Linux 10, Alma Linux 10 and CentOS Stream 10, x86_64 only, in Single-Node and Multi-Node. Current completion is **0/8**. Single-Node is **NOT VALIDATED**; Multi-Node is **NOT READY on the tested R65 path** due to the open HIGH finding. All R65 results are candidate-specific diagnostics and carry no matrix credit. Direct cross-workload PostgreSQL-IP reachability, controlled performance/stress and multiple fault categories remain untested. Rocky's EPEL pyOpenSSL 25.0.0 pin remains a visible validation-seed exception.

## Current decision by topology

| Topology | Decision | Basis |
| --- | --- | --- |
| Single-Node | **NOT VALIDATED** | No full cell completed. The shared Fleet token-auth code has a confirmed HIGH failure in Multi-Node under database outage; its Single-Node runtime case was not separately executed. R65 evidence is invalidated. |
| Multi-Node | **NOT READY** | R65 reproduced HIGH issue #264 on three real AlmaLinux guests: database lookup errors caused valid workers to be temporarily IP-blocked after recovery. R66 fix and exact-candidate runtime revalidation are pending. |

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
