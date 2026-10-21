# Performance report

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Current Release 46 status: **NOT TESTED — package build and fresh Single-Node installs are complete on all four target distributions, but no controlled workload sample has run.** Matrix: 0/8. Release 45 operation timings were functional checks only, and that candidate was invalidated by #229; they provide no Release 46 performance evidence.

This audit defines no product SLO. It will record the measured baseline and the limiting resource for each workload. Results must identify the exact candidate, guest OS, VM sizing, app definition, concurrency, database mode, image-cache state, and host load. Cold image pulls must be reported separately from warm container creation.

## Required measurements

For provision, update, pause/resume, backup, restore and deprovision, record operation request-to-terminal latency and separate API request latency where applicable. For repeated samples, report count, p50, p95 and p99, plus failures/timeouts. Record host and guest CPU, RSS, swap, memory pressure, disk free/IO, PostgreSQL activity, process count, file descriptors and Podman/systemd unit state. Multi-Node measurements must include hub and each worker, placement, WireGuard traffic, and one-worker versus two-worker behavior.

## Current evidence

Release 46 functional probes now include one provision-to-terminal operation duration on each Single-Node target: Rocky Linux 10.2 37.6s, AlmaLinux 10.2 138.1s, CentOS Stream 10 94.9s, and Fedora Rawhide 46 11.3s. These were not controlled performance samples: workload image-cache state was not held constant, the AlmaLinux and CentOS runs showed database startup delays during cold image/service startup, and only one sample exists per OS. Deprovision samples were 8.7s, 11.9s, 9.9s and 9.6s respectively. They provide a functional timing baseline only. No repeatable sample distribution, latency percentiles or concurrent load profile was captured for this audit. Therefore no p50/p95/p99 values are available and none are inferred.

One operational timing is captured but is not a workload benchmark: the secure worker2 installer on an AlmaLinux 10.2 2-vCPU/2-GiB VM ran from `13:10:07Z` to `13:17:40Z` (7m33s), including security updates and secure setup. The installer output shows the DNF security-update task was a distinct part of this duration. This single onboarding sample cannot be generalized to release performance or used as a percentile.

| OS / topology | Candidate / guest resources | Samples | p50 / p95 / p99 | Bottleneck assessment | Status |
| --- | --- | ---: | --- | --- | --- |
| Fedora Rawhide x86_64 Single-Node | Release 46 functional probe; one provision sample 11.3s and one deprovision sample 9.6s; warm/cold image state not controlled | 1 functional run | — | — | NOT TESTED (performance) |
| Rocky Linux 10 x86_64 Single-Node | Release 46 functional probe; one provision sample 37.6s and one deprovision sample 8.7s; warm/cold image state not controlled | 1 functional run | — | — | NOT TESTED (performance) |
| AlmaLinux 10 x86_64 Single-Node | Release 46 functional probe; one provision sample 138.1s and one deprovision sample 11.9s; DB startup delayed during image/service startup | 1 functional run | — | — | NOT TESTED (performance) |
| CentOS Stream 10 x86_64 Single-Node | Release 46 functional probe; one provision sample 94.9s and one deprovision sample 9.9s; DB startup delayed during image/service startup | 1 functional run | — | — | NOT TESTED (performance) |
| Fedora Rawhide x86_64 Multi-Node | Three-node functional checks; no controlled sample set | — | — | — | NOT TESTED (performance) |
| Rocky Linux 10 x86_64 Multi-Node | Three-node functional checks; no controlled sample set | — | — | — | NOT TESTED (performance) |
| AlmaLinux 10 x86_64 Multi-Node | Three-node functional checks; no controlled sample set | — | — | — | NOT TESTED (performance) |
| CentOS Stream 10 x86_64 Multi-Node | Release 42 runtime install, placement on both workers and cleanup subset; no controlled performance sample set | — | — | — | NOT TESTED (performance); runtime evidence is partial |

## Measurement procedure

The reproducible harness will timestamp operation submissions and terminal states, retain raw samples as CSV, and sample `/proc`, `systemd`, Podman, disk and PostgreSQL metrics at a fixed interval. It will use disposable app instances and clean up only those audit instances. Stress levels will rise gradually and stop before host pressure threatens other work. Host limits (4 vCPU, 8 GiB RAM plus 4 GiB swap) will be reported separately from product behavior. Three simultaneous 2-GiB VMs used approximately 6 GiB of assigned guest memory; at peak the host had around 1 GiB available and 1.3 GiB swap used, so no additional VMs or high-load runs were started during this topology test.

No scalability or production-throughput conclusion is available yet.
