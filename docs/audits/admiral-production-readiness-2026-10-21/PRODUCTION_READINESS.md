# Production readiness decision

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Audit began: 2026-10-21 UTC<br>
Latest candidate: six Release 45 RPMs were built locally; exact source pins, NEVRAs, hashes, CI and build limitations are in `evidence/release45-candidate.md`.<br>
Release 45 has not yet been installed in audit guests. Current matrix status is **0/8**; Release 42/43 runtime evidence below is historical only.

## Current decision by topology

| Topology | Decision | Basis |
| --- | --- | --- |
| Single-Node | **NOT VALIDATED** | No Release 45 VM run has started. Prior-candidate defects and scenarios have not been retested on these exact RPMs. |
| Multi-Node | **NOT VALIDATED** | No Release 45 three-guest run has started. Prior-candidate defects and scenarios have not been retested on these exact RPMs. |

Neither topology is READY or CONDITIONALLY READY on the current evidence. Build and unit-test success do not establish runtime readiness. No production system was touched.

## Historical Release 42 decision (superseded)

| Topology | Decision | Basis |
| --- | --- | --- |
| Single-Node | **NOT READY** | Scoped install/lifecycle evidence exists on all four OS targets, but full coverage is incomplete. Two open HIGH findings affect this mode: production config accepts shipped `__REQUIRED__` values for the secrets encryption and Fleet callback keys (`ADM-F-007` / #212), and a failed declared workload service can still produce `succeeded` provisioning and `healthy` instance state (`ADM-F-006` / #227). Repeated provisioning created distinct instances on all four distributions (`ADM-F-001`). Harbor rendered an unsafe percent-encoded script URL on Rocky and Fedora (`ADM-F-004`, MEDIUM). Concurrent update/delete, isolation negatives, stress/fault coverage, controlled performance and full matrix remain outstanding. HTTP/2 network exposure in this mode was not established. |
| Multi-Node | **NOT READY** | AlmaLinux now has a scoped three-node install, placement, worker outage/rejoin, hub peer-loss on power-cycle (`ADM-F-005`), local PostgreSQL backup/restore, failed-service false health (`ADM-F-006`), and false-success deprovision with remaining Podman resources (`ADM-F-008`). Rocky and Fedora placed workloads on both workers and preserved SQL markers across worker reboots; their hubs also lost peers on startup. CentOS Stream has a scoped three-guest install, placement, local PostgreSQL backup/restore and cleanup; it reproduced hub restart peer loss, false healthy state with a failed DB (`ADM-F-006`), duplicate same-customer provisions across workers (`ADM-F-001`), and stale healthy instance state after worker loss (`ADM-F-002` / #208). Five open HIGH findings block readiness: reachable Go HTTP/2 advisories (`ADM-F-003`), hub peer-recovery defect (`ADM-F-005`), failed-service status (`ADM-F-006`), placeholder secret acceptance (`ADM-F-007` / #212), and false-success cleanup with residual resources (`ADM-F-008` / #228). Rocky, AlmaLinux and CentOS Stream outages left assigned instances reporting stale `running/healthy` after workers were marked offline. External S3 and volume backup/restore, database outage, latency injection, task replay/lease behavior, conflicting updates/deletes, full security negatives, performance and complete distribution coverage remain open. |

The NOT READY statuses in this historical table applied to Release 42 runtime evidence. They do not validate or determine Release 45's runtime status. The current-candidate decision is NOT VALIDATED until the required tests run against Release 45.

## Candidate identity and host

Release 45 is locally built and served for fresh guest validation. Its build and package checks do not close findings or count as runtime evidence; each affected scenario must be re-run against these exact packages before changing its status.

The current root and component refs, package hashes, CI and build evidence are recorded in `evidence/release45-candidate.md`. `python3 scripts/validate-release-refs.py` passed, and all five submodule SHAs matched their remote `origin/main` heads immediately before the Release 45 build. The lab host is Rocky Linux 10.2 x86_64, 4 vCPU, 8 GiB RAM, 4 GiB swap and KVM/QEMU 10.1/libvirt 11.10. Guest tests are isolated libvirt VMs. The target is Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 on x86_64 in both topologies (eight cells). CentOS Stream's prior scoped tests remain historical Release 42 evidence and do not validate Release 45.

## What would change this decision

The target matrix remains Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 on x86_64 in both topologies (eight cells). Release 45 must be installed into fresh Single-Node guests and isolated three-guest Multi-Node topologies. Re-run applicable regressions from #207–#212 and #227–#228 before disposition; do not close findings because the code or unit tests changed. Include high-impact isolation, integrity, recovery, concurrency and false-completion scenarios. Performance measurements must include sample counts and percentiles, without invented SLOs. Any newly discovered defect requiring a fix invalidates the current candidate evidence and requires a new coordinated six-RPM Release plus reruns on the new candidate.

## Current answer to the audit question

The Release 45 production-readiness question cannot yet be answered: **Single-Node and Multi-Node are NOT VALIDATED** because no current-candidate runtime test has run. Historical Release 42 evidence found real lifecycle operation and also defects in idempotency, health reporting, Harbor URL handling, WireGuard peer recovery, configuration placeholders, failed-service detection and deprovision cleanup; those observations remain attached to their exact prior candidate. Release 45 includes fixes for some findings, but only runtime regressions can establish whether those defects are resolved. Concurrency, isolation negatives, resource exhaustion, latency, database outage recovery, performance and all eight current-candidate cells remain outstanding.
