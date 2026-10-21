# Resilience and failure-injection report

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Status: **NOT VALIDATED — selected real failures passed, many scenarios pending**

No production infrastructure has been modified. Failure injection is restricted to disposable libvirt guests on the lab host. All exact command lines, timing, state snapshots and recovery actions must be captured under `evidence/` before a scenario is reported PASS or FAIL.

## Failure scenarios

| ID | Injection | Expected evidence | Current status |
| --- | --- | --- | --- |
| R-01 | Kill `admirald` during no task / active task | service restart, operation state, queue state, resource count | NOT TESTED |
| R-02 | Kill `admiral-fleet` after claim and during side effect | lease expiry, retry count, duplicate behavior, outbox/callback state | NOT TESTED |
| R-03 | Stop/restart Podman or user systemd | task result must reflect actual resource state; recovery and orphan inventory | NOT TESTED |
| R-04 | Reboot a Single-Node guest | PostgreSQL, Caddy, Admiral services and workloads recover in dependency order | PASS on AlmaLinux 10.2 x86_64 with ~36s instance-state lag; CentOS Stream 10 workload and SQL marker recovered, but its API health state converged after a 91s stopped-state window. See `alma-single-execution.md` and `centos-single-execution.md`. |
| R-05 | Reboot a worker guest | heartbeat loss/rejoin and workload persistence | PASS on AlmaLinux 10.2 x86_64 (service/volume recovery; no marker) and Fedora Rawhide x86_64 (boot ID changed, same containers returned, PostgreSQL accepted connections, SQL marker survived and node heartbeat recovered); Rocky Linux 10 x86_64 also preserved its SQL marker |
| R-06 | Block hub-worker traffic with an isolated firewall rule | no unauthorized execution; leases and callbacks recover safely | FAIL (state reporting): Rocky hub firewall drop marked worker offline after 133s while its instance still reported stale `running/healthy`; after rule removal node rejoined in 10s and the instance deprovisioned cleanly. No in-flight lease/callback was tested; see `evidence/rocky-multi-partition.md` and `ADM-F-002`. |
| R-07 | Add controlled network latency/loss | bounded timeouts and stable state after restoration | NOT TESTED |
| R-08 | Interrupt task/result callback delivery | persistent outbox flushes; no callback state corruption | NOT TESTED |
| R-09 | Stop PostgreSQL or queue DB independently | fail-safe API/task behavior; no false success; recovery after DB returns | NOT TESTED |
| R-10 | Exhaust guest memory within cgroup bounds | OOM containment, service/workload status and recovery | NOT TESTED |
| R-11 | Fill a disposable filesystem to controlled threshold | explicit storage failure, no corrupt backup/restore and no false completion | NOT TESTED |
| R-12 | Inject Podman/systemd errors in provision/update/remove | operation status matches actual runtime; orphaned resources identified | NOT TESTED |
| R-13 | Recover worker with stale local resources | reconciler converges without deleting unrelated resources | NOT TESTED |
| R-14 | Suspend and resume one worker VM | node becomes unavailable after heartbeat timeout; rejoin retains same workload without duplicate effects | PASS on AlmaLinux 10.2 x86_64 with stale instance health state `ADM-F-002`; see `alma-multi-execution.md` |
| R-15 | Power-cycle/start the Rocky and Fedora Multi-Node hubs after worker onboarding | Durable WireGuard peers load and both workers rejoin without manual configuration | FAIL on both targets: hub started with zero runtime peers although two durable fragments existed; both workers went offline. Manual config reconstruction restored handshakes; see `rocky-multi-hub-reboot.md`, `fedora-multi-hub-reboot.md` and `ADM-F-005` |
| R-16 | Partition Rocky worker1 from the hub at the underlay ingress | Node becomes unavailable, workload state is not misrepresented, and rejoin/cleanup converge after restoring traffic | FAIL (state reporting): node detection and rejoin worked, but instance remained `running/healthy` with stale timestamp while worker was offline; cleanup succeeded. No in-flight task/callback was present; see `rocky-multi-partition.md` and `ADM-F-002`. |
| R-17 | Fail one declared service while keeping its app/pod running | Provisioning and health reflect that the complete declared workload is not ready | FAIL on CentOS Stream 10 Single-Node: a PostgreSQL unit running `/bin/false` was failed/absent while the operation returned `succeeded` and instance health later reported `healthy`; see `centos-single-execution.md` and `ADM-F-006`. |

## Recovery guarantees visible in implementation

The queue stores durable work in PostgreSQL, claims with a lease, retries with bounded attempts/backoff, and can dead-letter after exhausting attempts. Fleet uses a local outbox for callbacks it could not deliver, and its agent performs health/reconciliation functions. The main control plane and database are not replicated in the supported topology. These mechanisms suggest recovery paths but do not prove safe behavior at every side-effect boundary. At-least-once delivery is the correct assumption.

## Observed worker outage and recovery

The hub marked a suspended worker offline 145 seconds after the VM pause (2-minute heartbeat threshold plus monitor polling). It set node health to degraded and disabled provisioning. The worker's instance still showed `running/healthy` with a pre-outage health timestamp; see `ADM-F-002`. After VM resume, the rootless app, database and infra containers remained `Up`; the node returned to active/healthy after 59 seconds. A separate Rocky Linux 10 test dropped worker1 packets at the hub's underlay ingress: the node became offline after 133 seconds, the assigned instance again remained `running/healthy` with a stale timestamp, and the node rejoined ten seconds after rule removal. The audit did not interrupt an in-flight task or callback and did not test latency. No workload migration occurred.

The AlmaLinux Single-Node guest reboot returned after approximately 28 seconds. System services and workloads came back and database marker `42` survived. Instance state briefly showed `stopped` while Podman containers were already running, then converged within about 36 seconds. A separate `SIGKILL` of the app container was recovered by the generated systemd unit (`Restart=always`) within 3 seconds. The CentOS Stream Single-Node guest also rebooted with a SQL marker in its PostgreSQL volume. The first post-boot probe found only the pod infra container and API state `stopped`; the workload containers later returned, the marker persisted, and the API reached `running/healthy` 91 seconds after the stopped report. A separate deterministic service-failure probe showed that the healthy pod-level signal can hide a failed declared database service (`ADM-F-006`).

## Current conclusion

Real evidence now exists for Single-Node reboot and process recovery plus Multi-Node worker loss/rejoin and a controlled packet partition. The partition exposed stale instance health (`ADM-F-002`). The failed-service test exposed successful/healthy reporting while a declared database unit was failed (`ADM-F-006`). Both Rocky and Fedora hubs started without loading durable WireGuard peer fragments (`ADM-F-005`); manual reconstruction restored the lab clusters. Rocky and Fedora worker reboots preserved SQL markers. There is still no resilience evidence for Admirald/Fleet process termination during task side effects, Podman/systemd daemon failure, network latency, control-plane database outage/restore, memory/disk exhaustion, or interrupted deploy/callback. Single-Node and Multi-Node resilience remain **NOT VALIDATED**.
