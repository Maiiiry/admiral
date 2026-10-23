# R67 Fedora Multi-Node placement recheck

**Result: PASS for the two named placement/lifecycle scenarios; not a complete Multi-Node cell.**

Date: 2026-10-23 UTC<br>
Candidate source root commit: `833d15aa4f8e96be30d28dad169b9d06a4d9894d`<br>
Candidate packages: six Fedora-native `0.0.1rc5-67.fc46` Admiral RPMs<br>
Topology: isolated Fedora Rawhide x86_64 hub plus two Fedora Rawhide x86_64 workers; each guest 2 vCPU/2 GiB; test network underlay `10.77.0.0/24`, WireGuard overlay `10.99.0.0/24`.<br>
Matrix status: **0/8**. This evidence does not complete a release cell.

## Distro-native RPM boundary

The Fedora hub and workers were installed from the Fedora R67 repository using normal DNF dependency resolution. The hub carried all six exact `.fc46` RPMs; each worker carried exact `.fc46` `admiral-common` and `admiral-fleet`. The final post-check found no `.el10` RPM on any of the three Fedora guests. No EL10 binary was copied into the Fedora repository, installed, force-installed, or used as Fedora runtime evidence. The separately built `.el10` packages remained in the EL10 repository. The Fedora and EL10 build provenance, manifests and repository metadata are in [`release67-candidate.md`](release67-candidate.md).

## Retained initial failure and harness correction

The 17:51 UTC attempt is retained as **FAIL — validation timing assertion**, not counted as a pass. Provision operation `op_9dd1dd408821475e` for instance `inst_cfb5a843d92f4b13` returned terminal `succeeded`; the helper immediately queried the instance and observed `technical_status=running`, `health_status=stopped`, `effective_availability=unavailable`, reason `runtime_not_healthy`, and message `rootless systemd manager active; awaiting fresh workload health`. It did not report the instance available prematurely. The helper then deprovisioned the disposable instance; the API showed `deprovisioned` and no test resources remained. This attempt ended before checking runtime health, HTTP or SQL and establishes no product pass or defect.

The cause was confirmed in the audit helper: it asserted `healthy/available` on the first instance query even though `admiralctl instances provision --wait` waits for terminal operation state, not asynchronous workload health convergence. The helper now checks that the requested worker remains assigned and polls the API for up to five minutes, requiring both `health_status=healthy` and `effective_availability=available` before performing runtime assertions. This is a harness correction, not a product source change. The failed run remains available as a mode-0600 local log.

## Corrected recheck procedure and results

The reproducible procedure is [`scripts/r67/r67-fedora-multinode-placement.sh`](../scripts/r67/r67-fedora-multinode-placement.sh). It requires the isolated hub and both active workers, applies the repository `e2e-whoami` definition, explicitly places one disposable instance on each worker, replays the same idempotency key, waits for API health convergence, checks worker runtime/SQL and hub-to-worker HTTP, then deprovisions and verifies cleanup.

| Test ID | Worker / instance | Observed result | Status |
| --- | --- | --- | --- |
| `R67-FEDORA-MN-RECHECK-W1-01` | `adm-r67-fedora-mn-w1` / `inst_4c65f588940042e6` | Provision operation `op_acd4cc6eb5f98282` returned `succeeded`; same-key replay returned the same operation and instance. Health converged on poll 1 to `running/healthy/available`. PostgreSQL was ready on poll 2; SQL marker `r67-fedora-inst_4c65f588940042e6` was inserted/read back. Hub request to `10.99.0.2:40002` returned HTTP 200. Deprovision `op_e4062f2f8bf96024` succeeded; containers, pods, volumes, user units and files matching the instance were absent. | **PASS, scoped** |
| `R67-FEDORA-MN-RECHECK-W2-01` | `adm-r67-fedora-mn-w2` / `inst_f7601ec3bf372d7e` | Provision operation `op_64d9797bdec7fce4` returned `succeeded`; same-key replay returned the same operation and instance. Health converged on poll 1 to `running/healthy/available`. PostgreSQL was ready on poll 2; SQL marker `r67-fedora-inst_f7601ec3bf372d7e` was inserted/read back. Hub request to `10.99.0.3:40001` returned HTTP 200. Deprovision `op_adb9b11d18c008cc` succeeded; containers, pods, volumes, user units and files matching the instance were absent. | **PASS, scoped** |

The post-check at 17:53 UTC found the hub and both workers `active/healthy/available` with fresh heartbeat and metrics timestamps, all six exact `.fc46` packages on the hub, and the expected `.fc46` common/Fleet packages on each worker. `podman ps -a` was empty on both workers. No `.el10` package was present.

## Evidence and reproduction

Raw guest logs remain local, ignored and mode `0600`. The corrected helper's output was scanned for credential assignments, tokens, private keys and database URLs; none were found. The runtime uses only synthetic customer IDs and SQL marker values.

| Evidence | SHA-256 |
| --- | --- |
| Failed first timing assertion, `packaging/build/validation/rc5-r67/fedora-mn-placement-20261023-03.log` | `108d47d6ca71a4033d8fbccce980b0177ab7d66798edc5ffcad8040686ac7015` |
| Corrected W1/W2 recheck, `packaging/build/validation/rc5-r67/fedora-mn-placement-20261023-04.log` | `9b83652a32c7bb5933b3a131f80b5982da51e4be21138776d8742b32a079f7d2` |
| Successful read-only cluster/package/resource post-check, `packaging/build/validation/rc5-r67/fedora-mn-postcheck-rerun-02.log` | `3d3241b1a887fff5e413388a39334cf36f25ca47601116272ed540bf17aef7db` |
| Corrected placement helper | `e490cd56a750af661b715701cb75971d7e45e42e4c453d7d70496596be130c16` |

An initial read-only post-check command is also retained, SHA-256 `ff546905b9916ed579f9de9ac6af93c00d5cee11669c0a39d932b836413ff0bb`. It stopped because `runuser` inherited the validator's non-readable working directory; the command was rerun from `/tmp` and passed. No Admiral state was changed by that failed post-check.

## Scope limits

These results prove only fresh bootstrap plus the named two-worker placement and cleanup scenarios for Fedora R67. They do not test node loss, hub/worker restart, network partition, concurrent conflicting updates, auth-negative behavior between nodes, external backup, isolation attacks, resource exhaustion, or performance. Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 Multi-Node remain **NOT TESTED on R67**. The four Fedora/EL10 RPM build environments do not themselves prove runtime behavior on the other distributions.
