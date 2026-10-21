# Performance report

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Current Release 46 status: **NOT TESTED — package build and fresh Single-Node installs are complete on Fedora and Rocky, but no controlled workload sample has run.** Matrix: 0/8. Release 45 operation timings were functional checks only, and that candidate was invalidated by #229; they provide no Release 46 performance evidence.

This audit defines no product SLO. It will record the measured baseline and the limiting resource for each workload. Results must identify the exact candidate, guest OS, VM sizing, app definition, concurrency, database mode, image-cache state, and host load. Cold image pulls must be reported separately from warm container creation.

## Required measurements

For provision, update, pause/resume, backup, restore and deprovision, record operation request-to-terminal latency and separate API request latency where applicable. For repeated samples, report count, p50, p95 and p99, plus failures/timeouts. Record host and guest CPU, RSS, swap, memory pressure, disk free/IO, PostgreSQL activity, process count, file descriptors and Podman/systemd unit state. Multi-Node measurements must include hub and each worker, placement, WireGuard traffic, and one-worker versus two-worker behavior.

## Current evidence

Prior RC42 logs record individual operation progress and backup sizes for Rocky Linux 10 and Fedora Rawhide. AlmaLinux and CentOS Stream logs include installer and lifecycle timings. These are functional evidence, not a controlled performance dataset: no repeatable sample count, latency percentiles or concurrent load profile was captured for this audit. Therefore no p50/p95/p99 values are available and none are inferred.

One operational timing is captured but is not a workload benchmark: the secure worker2 installer on an AlmaLinux 10.2 2-vCPU/2-GiB VM ran from `13:10:07Z` to `13:17:40Z` (7m33s), including security updates and secure setup. The installer output shows the DNF security-update task was a distinct part of this duration. This single onboarding sample cannot be generalized to release performance or used as a percentile.

| OS / topology | Candidate / guest resources | Samples | p50 / p95 / p99 | Bottleneck assessment | Status |
| --- | --- | ---: | --- | --- | --- |
| Fedora Rawhide x86_64 Single-Node | Prior RC/live functional checks; no controlled sample set | — | — | — | NOT TESTED (performance) |
| Rocky Linux 10 x86_64 Single-Node | Prior RC/live functional checks; no controlled sample set | — | — | — | NOT TESTED (performance) |
| AlmaLinux 10 x86_64 Single-Node | Installer and lifecycle checks; no controlled sample set | — | — | — | NOT TESTED (performance) |
| CentOS Stream 10 x86_64 Single-Node | Release 42 scoped install/lifecycle/reboot probes; no controlled sample set | — | — | — | NOT TESTED (performance) |
| Fedora Rawhide x86_64 Multi-Node | Three-node functional checks; no controlled sample set | — | — | — | NOT TESTED (performance) |
| Rocky Linux 10 x86_64 Multi-Node | Three-node functional checks; no controlled sample set | — | — | — | NOT TESTED (performance) |
| AlmaLinux 10 x86_64 Multi-Node | Three-node functional checks; no controlled sample set | — | — | — | NOT TESTED (performance) |
| CentOS Stream 10 x86_64 Multi-Node | Release 42 runtime install, placement on both workers and cleanup subset; no controlled performance sample set | — | — | — | NOT TESTED (performance); runtime evidence is partial |

## Measurement procedure

The reproducible harness will timestamp operation submissions and terminal states, retain raw samples as CSV, and sample `/proc`, `systemd`, Podman, disk and PostgreSQL metrics at a fixed interval. It will use disposable app instances and clean up only those audit instances. Stress levels will rise gradually and stop before host pressure threatens other work. Host limits (4 vCPU, 8 GiB RAM plus 4 GiB swap) will be reported separately from product behavior. Three simultaneous 2-GiB VMs used approximately 6 GiB of assigned guest memory; at peak the host had around 1 GiB available and 1.3 GiB swap used, so no additional VMs or high-load runs were started during this topology test.

No scalability or production-throughput conclusion is available yet.
