# Production readiness decision

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Audit began: 2026-10-21 UTC<br>
> **Current candidate state — 2026-10-24:** R68 (`0.0.1rc5-68`, source `4077c4ddb9d233682961d36c3570c63e70eb6405`) is **invalidated for matrix credit** after the CentOS Stream 10 Multi-Node storage report briefly showed `0/unknown` against a declared `1G` tier (#268). The issue remains open. Its source fix is now in `admiral-fleet@029bb53da6c2bef7d567213a5fd6ab106d56d68c`; component CI [40052142923](https://github.com/admiral-project/admiral-fleet/actions/runs/40052142923) succeeded. A coordinated R69 build is pending; no R69 RPMs or runtime tests exist yet. R68 evidence and exact package identity remain in [`release68-candidate.md`](evidence/release68-candidate.md) and [`release68-centos-multinode-storage-observation.md`](evidence/release68-centos-multinode-storage-observation.md). No R68 result transfers to R69.

The release gate remains four x86_64 OSes × two topologies = **eight cells**. Completion is **0/8**: no cell has completed its full catalog, and R68 is invalidated. Single-Node and Multi-Node are both **NOT VALIDATED** for production. R68, R67 and R66 runs remain candidate-specific historical evidence and earn no R69 matrix credit. ARM64 remains Tier 2 and non-blocking.

## Current decision by topology

| Topology | Decision | Basis |
| --- | --- | --- |
| Single-Node | **NOT VALIDATED** | No R69 runtime tests have run. R68 has scoped runs on all four target OSes, including install, workload lifecycle and selected recovery/security/performance probes; these are invalidated for R69. Full isolation, secrets lifecycle, fault injection, resource exhaustion, backup/restore coverage and measured performance remain incomplete. See [historical R68 evidence](evidence/release68-single-node-progress.md). |
| Multi-Node | **NOT VALIDATED** | No R69 runtime tests have run. R68 scoped AlmaLinux and CentOS Stream three-guest results are historical only after #268 invalidated R68. Active-task compensation, partition recovery, consistency under failure, comprehensive isolation, stress and performance remain outstanding. See the R68 reports for candidate-bound historical evidence. |

Neither topology is READY or CONDITIONALLY READY on current evidence. Exact-commit CI and scoped scenarios do not substitute for a complete matrix cell. No production system was touched.

## Historical Release 42 decision (superseded)

| Topology | Decision | Basis |
| --- | --- | --- |
| Single-Node | **NOT READY** | Scoped install/lifecycle evidence exists on all four OS targets, but full coverage is incomplete. Two open HIGH findings affect this mode: production config accepts shipped `__REQUIRED__` values for the secrets encryption and Fleet callback keys (`ADM-F-007` / #212), and a failed declared workload service can still produce `succeeded` provisioning and `healthy` instance state (`ADM-F-006` / #227). Repeated provisioning created distinct instances on all four distributions (`ADM-F-001`). Harbor rendered an unsafe percent-encoded script URL on Rocky and Fedora (`ADM-F-004`, MEDIUM). Concurrent update/delete, isolation negatives, stress/fault coverage, controlled performance and full matrix remain outstanding. HTTP/2 network exposure in this mode was not established. |
| Multi-Node | **NOT READY** | AlmaLinux now has a scoped three-node install, placement, worker outage/rejoin, hub peer-loss on power-cycle (`ADM-F-005`), local PostgreSQL backup/restore, failed-service false health (`ADM-F-006`), and false-success deprovision with remaining Podman resources (`ADM-F-008`). Rocky and Fedora placed workloads on both workers and preserved SQL markers across worker reboots; their hubs also lost peers on startup. CentOS Stream has a scoped three-guest install, placement, local PostgreSQL backup/restore and cleanup; it reproduced hub restart peer loss, false healthy state with a failed DB (`ADM-F-006`), duplicate same-customer provisions across workers (`ADM-F-001`), and stale healthy instance state after worker loss (`ADM-F-002` / #208). Five open HIGH findings block readiness: reachable Go HTTP/2 advisories (`ADM-F-003`), hub peer-recovery defect (`ADM-F-005`), failed-service status (`ADM-F-006`), placeholder secret acceptance (`ADM-F-007` / #212), and false-success cleanup with residual resources (`ADM-F-008` / #228). Rocky, AlmaLinux and CentOS Stream outages left assigned instances reporting stale `running/healthy` after workers were marked offline. External S3 and volume backup/restore, database outage, latency injection, task replay/lease behavior, conflicting updates/deletes, full security negatives, performance and complete distribution coverage remain open. |

The NOT READY statuses in this historical table applied to Release 42 runtime evidence. They do not validate or determine the next candidate status. Release 45–47 observations are candidate-specific and do not carry forward.

## Historical Release 46 candidate identity and host

Release 46 is historical. Its source pins and six RPMs were built at package-preparation commit `7223561646b60d3c24e8bfb257d544a5eb6dea04`; its targeted guest observations are retained below and in `evidence/`, but do not count for the rebuilt candidate. Rocky Linux 10 is back in the active scope; its Release 46 dependency-resolution failure and workaround remain historical evidence only.

The Release 46 reference check, exact NEVRAs, hashes and targeted observations are recorded in `evidence/release46-candidate.md` and `evidence/release46-rpm-sha256.txt`. The lab host is Rocky Linux 10.2 x86_64, 4 vCPU, 8 GiB RAM, 4 GiB swap and KVM/QEMU 10.1/libvirt 11.10. Guest tests use isolated libvirt VMs. The active target is Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 x86_64 in Single-Node and Multi-Node (eight cells).

## What would change this decision

Complete every common candidate/evidence gate and every topology-specific check in the [per-cell PASS checklist on issue #200](https://github.com/admiral-project/admiral/issues/200#issuecomment-6374384636) for all eight cells on one unchanged candidate. Reproduce and disposition actionable linked findings, including cross-OS regression for #267. Use fresh isolated guests, native distro RPMs and authenticated secure-mode tests. Measure performance without inventing thresholds. Any required source/RPM fix creates a new candidate and invalidates affected runtime evidence.

## Current answer to the audit question

The production-readiness question cannot yet be answered: **Single-Node and Multi-Node remain NOT VALIDATED**, with matrix completion **0/8**. R68 has been invalidated by #268; its scoped tests are retained only as historical evidence. R69 packaging and fresh-guest runtime validation are pending. No production-readiness claim is made.
