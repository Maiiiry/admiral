# Release 49 exploratory Single-Node observations

Audit: `ADM-AUDIT-2026-10-21`  
Candidate: root package-preparation commit `6661bb779dd197d24cf565e7e5bb85c99ef809ed`, six coordinated `0.0.1rc5-49` RPMs. Exact source refs, NEVRAs and hashes are in [`release49-candidate.md`](release49-candidate.md).  
Status: **exploratory only; matrix remains 0/8**. A real capacity-policy rejection on Rocky Linux exposed #240 after these guests were installed. Its local fix has not yet been committed, pushed or included in a rebuilt RPM set. Per the release gate, none of this candidate's evidence counts toward the next candidate.

## Environments and install results

The guests were fresh 2-vCPU/2-GiB overlays from the 2026-10-22 updated x86_64 seeds on the isolated libvirt NAT. The host is Rocky Linux 10.2 with 4 vCPU, 8 GiB RAM, 4 GiB swap, KVM and SELinux enforcing. At cleanup, 89 GiB remained free. Unsanitized guest logs are outside Git under `packaging/build/validation/rc5-r49/evidence/`, all mode `0600`; their checksums are listed in [`release49-exploratory-single-node-sha256.txt`](release49-exploratory-single-node-sha256.txt).

| OS | Guest / address | Install result | Baseline |
|---|---|---|---|
| Fedora Rawhide | `adm-r49-fedora-single`, `192.168.122.242` | Six exact R49 RPMs installed; secure setup completed. | Services and Harbor API healthy; SELinux enforcing; rootless Podman. |
| Rocky Linux 10.2 | `adm-r49-rocky-single`, `192.168.122.243` | Six exact R49 RPMs installed with the documented `python3-pyOpenSSL-25.0.0-1.el10_1` seed pin; secure setup completed. | Services and Harbor API healthy; SELinux enforcing; rootless Podman. |
| AlmaLinux 10.2 | `adm-r49-alma-single`, `192.168.122.244` | Six exact `0.0.1rc5-49.el10` packages; Ansible recap `ok=232 changed=97 unreachable=0 failed=0`. | All Admiral services active; Harbor API reachable; SELinux enforcing; rootless Podman. |
| CentOS Stream 10 | `adm-r49-centos-single`, `192.168.122.245` | Six exact `0.0.1rc5-49.el10` packages; Ansible recap `ok=231 changed=97 unreachable=0 failed=0`. | All Admiral services active; Harbor API reachable; SELinux enforcing; rootless Podman. |

The EL10 guests had EPEL, CRB and Admiral COPR enabled. Package transactions resolved from the local R49 repo; the installer’s additional update checks returned `Nothing to do`. The seeds were not subjected to another full OS update. The SSH host keys were enrolled over isolated NAT after correlating guest IPs to MAC leases; subsequent SSH and SCP used `StrictHostKeyChecking=yes`. This is still a first-contact trust limitation tracked in #239, not an out-of-band host-key proof.

## Executed Single-Node scenarios

These are scenario-level results, not full cell passes.

| Test ID | Scenario and observed result | OS coverage / evidence |
|---|---|---|
| R49-SN-INSTALL | Exact local RPM installation, dependency transaction, secure `admiral-install --single-node`, service and API health. | All four OSes; raw install logs and baseline captures listed in the checksum file. |
| R49-SN-PROVISION | Provision `e2e-whoami`, replay the exact request key, confirm the same operation and instance, inspect three rootless containers and request the actual mapped endpoint. API without a token returned HTTP 401. | Fedora and Rocky: `inst_85b752815fd151a6`, `inst_ce71b99207d474cb`; Alma: `op_4edce2505b072a06` / `inst_a724cb985af9c35f`; CentOS: `op_1f6ef37dce6fa301` / `inst_76776fbe91cf1be6`. HTTP 200 on the app endpoint for all four. |
| R49-SN-RESTART | Admiral restart completed; killing the app container caused the systemd Quadlet unit to recover it, with `NRestarts` incremented and HTTP 200 restored. | Fedora and Rocky; Alma and CentOS. The Alma/CentOS corrected logs use the systemd restart counter because Podman’s per-container `RestartCount` resets when systemd recreates the container. |
| R49-SN-BACKUP | PostgreSQL marker backed up, mutated, and restored with checksum verification. Restore while the instance was running was rejected with HTTP 409; pause, restore and resume succeeded, and the original marker returned. | Fedora and Rocky; Alma backup `bk_9126f341a26670b1`, SHA-256 `bbe4d43beb1d758bd9e1341668bc7efab45bb2f72d14e0d6069710753c5d9da6`; CentOS backup `bk_bc936299f1fda215`, SHA-256 `73b1ed328abfe5b7d000acdb098a1d47890ba2735f457cdf091a09dc106ac611`. Local PostgreSQL only. |
| R49-SN-HOST-REBOOT | Guest boot ID changed. The database marker persisted, all three Quadlet containers returned, the API converged to `running/healthy/available`, and the app endpoint returned HTTP 200. Early post-boot observations were `stopped/unavailable`, not falsely healthy. | Fedora and Rocky; Alma and CentOS. Alma/CentOS recovered after roughly 22–26 seconds of health polling. The first port probe assumed 40000; the actual post-reboot mapping was 40001 and the corrected probe passed. |
| R49-SN-ADMIRALD-KILL | `SIGKILL` to `admirald` was recovered by systemd. After a 40-second observation window, the provision-operation count stayed at one, three containers remained, and the SQL marker was intact. | Fedora and Rocky; Alma `inst_8713298f3a3d4b9d`; CentOS `inst_024120327b912371`. |
| R49-SN-FAILED-SERVICE | The fixture’s required DB runs `/bin/false`. Provision operations terminated `failed`; instances were `failed/unhealthy/unavailable`, and cleanup left no containers, pods, volumes or instance paths. | Fedora and Rocky; Alma operation `op_9ed85af345b8e5de`, instance `inst_4735bf12bd88ae33`; CentOS operation `op_1a0c79a54edc4d35`, instance `inst_c74f88fcc313a5d1`. |
| R49-SN-DEPROVISION-FAULT | A guest-local wrapper injected Podman delete failures. Deprovision failed and did not mark the instance deprovisioned while resources remained. Restoring the original Podman binary and retrying succeeded with no containers, volumes or instance data. | Rocky; Alma failed/retry operations `op_3613a479c2a033ec` / `op_26062c08737e4f91`; CentOS `op_87c293fe2bc9c68b` / `op_68558a3a446ec3be`. Original Podman SHA-256 was restored on both EL guests. |
| R49-SN-TERMINAL-TASK | Killing `admirald` after a terminal provision operation did not replay the provision: one provision operation remained, exactly three containers stayed up, and the marker persisted. | Fedora and Rocky; Alma and CentOS. |

## Candidate invalidation and limits

The Rocky concurrent-capacity probe had capacity for one additional 512 MiB workload and launched two requests. One succeeded; the other received a structured HTTP 503 capacity-policy rejection, but `admiralctl` retried it three times. Four failed operations/tasks were recorded for one rejected request. No workload or capacity reservation leaked. This is issue [#240](https://github.com/admiral-project/admiral/issues/240), and it invalidates Release 49 for final validation. The fix is pushed as `admiralctl@5ed381d`; the regression test, full local suites and GitHub CI run [39724553667](https://github.com/admiral-project/admiralctl/actions/runs/39724553667) passed. This does not validate the fix in a deployed RPM. A rebuilt six-RPM candidate and fresh Single-Node/Multi-Node runtime regressions are still required.

Issue [#233](https://github.com/admiral-project/admiral/issues/233) also received a local audit-helper fix. The new cleanup helper rejected an active guest, removed only the two powered-off guest overlays/cloud-init artifacts and their exact DHCP entries, preserved all four shared seeds, and removed a synthetic stale reservation with no domain or disk. It is not an Admiral RPM change.

The run did not exercise any Multi-Node topology, volume backup/restore, external S3, concurrent update/delete of the same instance, network partitions, resource exhaustion, measured performance percentiles, or all cross-workload isolation negatives on every OS. The installed `e2e-backup` fixture used a local PostgreSQL backup and did not prove external object-store behavior. R49 therefore completes **zero of eight** matrix cells. A new exact candidate must rerun each required scenario from fresh overlays.
