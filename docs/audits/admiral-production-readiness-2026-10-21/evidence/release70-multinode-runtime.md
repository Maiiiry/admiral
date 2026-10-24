# Release 70 Multi-Node runtime evidence — Rocky Linux 10 x86_64

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Test ID: `R70-ROCKY-MN-E2E-01`<br>
Candidate: Admiral RC5 `0.0.1rc5-70.el10`<br>
Root source commit: `fb081f3378813a0b5bd800a1573d0b4773052a44`<br>
Result: **PASS — functional Multi-Node release cell**<br>
Execution window: 2026-10-24 04:14–04:47 UTC

## Environment and candidate

The lab used three fresh, isolated libvirt guests cloned as overlays from the updated Rocky Linux 10.2 x86_64 seed identified in [`release70-candidate.md`](release70-candidate.md). Hub: `adm-r70-rocky-hub`; workers: `adm-r70-rocky-w1` and `adm-r70-rocky-w2`. They used separate underlay addresses `10.77.0.10–12` and WireGuard addresses `10.99.0.1–3`. No mocks, `--dev-node`, `--nodeps`, forced RPM installation, or Fedora binaries were used.

The hub installed the six exact Release 70 Admiral RPMs through DNF from the local GPG-checked EL10 repository. Each worker installed the exact `admiral-common-0.0.1rc5-70.el10.noarch` and `admiral-fleet-0.0.1rc5-70.el10.x86_64` packages using the supported secure bootstrap. All three installer recaps had zero failed or unreachable tasks. The installed package set and helper-library versions are recorded in the candidate report and package hash manifest.

At the clean baseline, all three nodes were `active/healthy/available`; the hub had two fresh WireGuard handshakes and each worker had one. SELinux was Enforcing, firewalld was running, IPv4 forwarding was disabled, required services were active, no systemd units had failed, and worker rootless Podman inventories were empty. The post-check completed at `2026-10-24T04:39:40Z`.

## Executed scenarios

| Test ID | Procedure and observed result | Outcome |
|---|---|---|
| `R70-ROCKY-MN-INSTALL-01` | Fresh three-guest bootstrap, exact native EL10 packages, secure hub/worker roles, bootstrap-key revocation, Fleet heartbeats, WireGuard registration and clean service/package post-check. | **PASS** |
| `R70-ROCKY-MN-PLACEMENT-W1-01` | Explicitly provisioned `inst_3201e8d496055905` on W1. Same-key replay returned the original operation and instance. The 1 GiB tier was present in the API snapshot and root-owned `0600` worker metadata; two storage samples reported `1073741824` bytes and `ok`. PostgreSQL marker round-trip and hub-to-workload HTTP 200 passed; deprovision removed matching containers, pods, volumes, units and files. | **PASS** |
| `R70-ROCKY-MN-PLACEMENT-W2-01` | Explicitly provisioned `inst_e21154284ac74a3f` on W2. Same-key replay returned the original operation and instance. The 1 GiB tier was present in the API snapshot and root-owned `0600` worker metadata; two storage samples reported `1073741824` bytes and `ok`. PostgreSQL marker round-trip and hub-to-workload HTTP 200 passed; deprovision left no matching runtime or files. | **PASS** |
| `R70-ROCKY-MN-WORKER-REBOOT-01` | Rebooted W1 with `inst_128563dd612b5539` active. Boot ID changed from `70d7357c-539e-48be-aff4-b7b8ed06e3c3` to `3ec5e6d7-e27b-4213-904d-fe9c57e19d81`. The first observation conservatively reported unavailable while PostgreSQL recovered; the next two consecutive observations reported the node active/healthy, instance running/healthy/available, all three containers present, SQL marker intact and HTTP 200. Deprovision left no matching resources. | **PASS** |
| `R70-ROCKY-MN-WG-PARTITION-01` | Partitioned W2 from the hub by changing only its in-memory WireGuard `AllowedIPs`; W2's API request timed out. Instance availability became `unavailable` for stale runtime observation. After the heartbeat timeout, the node became `offline/degraded` at `04:45:58Z`, about 119 seconds after partition start. Restoring the peer returned W2 to active/healthy/available on the first rejoin poll; the workload returned HTTP 200 and retained its SQL marker. Deprovision left no matching resources. | **PASS** |
| `R70-ROCKY-MN-NODE-REMOVE-01` | With `inst_3ce982ef429a4c63` active and serving HTTP 200, node removal exited 1 with `node has active instances (1 active instance)`; subsequent node/instance snapshots and HTTP 200 confirmed no state change. After successful deprovision and empty runtime inventories, idle W2 removal succeeded and W2 disappeared from the control-plane list. Hub and W1 remained active/healthy. | **PASS** |
| `R70-ROCKY-MN-API-CONFLICT-01` | On W1, one authenticated API `DELETE /api/v1/nodes/adm-r70-rocky-w1` returned HTTP 409 with the active-instance count and `--force` guidance. The CLI surfaced the same conflict once; W1 and its workload remained registered/healthy/available and HTTP stayed 200. Deprovision left no matching resources. | **PASS** |

The first node-removal script attempt stopped at a test-harness text assertion: the CLI correctly rejected removal, but the script expected a different word order. Its exit trap deprovisioned the test instance. The failed capture is retained; the assertion now matches the observed CLI message, and the complete node-removal scenario was rerun successfully. This was not a product failure and did not change the RPM candidate.

## Evidence and reproduction

Executable procedures are in [`../scripts/r70/`](../scripts/r70/). The per-run exact evidence files remain under the ignored local directory `packaging/build/validation/rc5-r70/`; their SHA-256 values are listed in [`release70-runtime-log-sha256.txt`](release70-runtime-log-sha256.txt). The top-level captures include the three install logs, topology post-check, both-worker placement, worker reboot, partition/rejoin, authenticated API conflict, and both the initial harness failure and successful node-removal retry. Per-scenario `SHA256SUMS` files cover the detailed snapshots and timelines.

The result is limited to this functional Rocky Linux 10 x86_64 Multi-Node cell. Same-key replay was sequential, not a concurrent race. This run did not test PostgreSQL outage, hub reboot, broad tenant-isolation negatives, external backup storage, resource exhaustion, or performance. Those remain outside the functional Release 70 gate and are not claimed as validated.
