# Production readiness decision

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Audit began: 2026-10-21 UTC<br>
> **Active scope — 2026-10-24:** this document does not certify production readiness. The active task is the functional Release 70 gate on Rocky Linux 10 x86_64, Single-Node and Multi-Node. Release 70 is being prepared; current functional matrix is **0/2**. Earlier release evidence does not transfer.

Production readiness is **NOT VALIDATED**. The functional release gate is narrower than the full production audit and cannot establish production security, fault-tolerance, scalability or performance.

## Current decision by topology

| Topology | Decision | Basis |
| --- | --- | --- |
| Single-Node | **NOT VALIDATED** | Release 70 runtime checklist has not run yet. |
| Multi-Node | **NOT VALIDATED** | Release 70 runtime checklist has not run yet. |

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

Complete every common candidate/evidence gate and every topology-specific check in the [per-cell PASS checklist on issue #200](https://github.com/admiral-project/admiral/issues/200#issuecomment-6378311098) for all eight cells on one unchanged candidate. Reproduce and disposition actionable linked findings. Use fresh isolated guests, native distro RPMs and authenticated secure-mode tests. Measure performance without inventing thresholds. Any required source/RPM fix creates a new candidate and invalidates affected runtime evidence.

## Current answer to the audit question

The production-readiness question cannot yet be answered: **Single-Node and Multi-Node remain NOT VALIDATED**, with matrix completion **0/8**. R68 has been invalidated by #268; its scoped tests are historical. R69 packaging and exact-commit CI are verified, and Single-Node scenarios are underway, but public TLS/isolation and other required checks remain; R69 Multi-Node is untested. No production-readiness claim is made.
