# Release 73 CentOS Stream 10 Multi-Node progress — partial

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Candidate: six coordinated `0.0.1rc5-73` RPMs; source pins and CI are in [`release73-candidate.md`](release73-candidate.md).<br>
Execution date: 2026-10-24 UTC. The audit spans three calendar days, 2026-10-21 through 2026-10-24.<br>
Result: **PARTIAL**. Three real guests are enrolled. Clean install, placement/lifecycle on both workers, one concurrent idempotency race, and reboot recovery on both workers passed as named scenarios. Multi-Node cell acceptance is not complete.

## Candidate, seed, and topology

- CentOS Stream 10 (Coughlan), x86_64. Hub `adm-r73-centos-mn-hub` (`10.77.0.31`, WireGuard `10.99.0.1`); W1 `adm-r73-centos-mn-w1` (`10.77.0.32`, `10.99.0.2`); W2 `adm-r73-centos-mn-w2` (`10.77.0.33`, `10.99.0.3`). Each is a separate 2-vCPU/2-GiB guest.
- Seed `/var/lib/libvirt/images/admiral-validation/seeds/CentOS-Stream-10-seed-20261024-r71.x86_64.qcow2`; SHA-256 `1d8ec7ee74a69ae22d2957440add7e218befa58dd42bd8cb063219860791c15b`.
- Fresh-clone DNF refresh checks on 2026-10-24 returned 0 before installation. A further `dnf --refresh check-update` on W1 at 14:35:54Z also returned 0; raw capture SHA-256 `84e1d7d3397ddc42e29e1f763f034d0b01d5c7cf69e771c62f21928d022d9457`. This last check refreshed repository metadata but did not install or upgrade packages.
- The R73 candidate repo is signed and enabled on each guest. DNF used the native EL10 package set and dependency resolution; no Fedora RPMs, `--nodeps` or vendor override were used.
- At the latest post-test inventory all three VMs were running, and the hub reported the portal and both workers `active/healthy/available`.

## Secure installation and baseline

The hub secure installer completed with Ansible `ok=239 changed=106 unreachable=0 failed=0`. W2 completed the supported worker installation with `ok=152 changed=52 unreachable=0 failed=0`; clean W1 completed with the same recap. Exact installed packages were:

- Hub: six native `0.0.1rc5-73.el10` Admiral RPMs.
- Each worker: `admiral-common-0.0.1rc5-73.el10.noarch` and `admiral-fleet-0.0.1rc5-73.el10.x86_64`.

Both workers had SELinux `Enforcing`; Fleet, firewalld, Fail2ban and auditd were active. The public zone exposed SSH and `51820/udp` only. The package-owned WireGuard peer-revocation socket was present and disabled on spokes as expected. Post-install evidence is mode `0600`: `setup/w1-postinstall.txt` SHA-256 `6c838328d29f91b2e223880da6288a388352a522e201a9c23bc2fe234f2b46f7`, and `setup/w2-postinstall.txt` SHA-256 `4e07f4959431a5a051be7ea70d94999fcdf66ac0980bcfdf8b00864cba707d59` under the ignored `packaging/build/validation/rc5-r73/runtime/multi/centos/` tree.

W1's first install attempt is excluded. It still had `admiral-common-57` from COPR and did not have the signed R73 repository enabled, so the R73 installer encountered a socket that existed in the R73 RPM but not in the stale installed package. After recreating W1 from the seed and configuring the candidate repo, the clean secure install passed. This was a lab setup mismatch, not a reproduced Admiral defect. The failed attempt and diagnosis were retained; bootstrap credentials were removed after installation.

## Executed Multi-Node scenarios

### W1 and W2 workload placement and cleanup

`r73-centos-multinode-placement.sh` provisioned the real `e2e-whoami` app explicitly to each worker in turn. Both operations succeeded; replaying each same idempotency key returned the original operation and instance. The workload returned HTTP 200 over the WireGuard address, the reported storage tier was 1 GiB/`ok`, and deprovision left no matching containers, pods, volumes, units or files.

- W1 instance `inst_3b7db5eafdbda2f9`, operation `op_2fc95f537fafa2ec`, endpoint `10.99.0.2:40000`.
- W2 instance `inst_b9c4b88660b0a022`, operation `op_de2bf08986b511da`, endpoint `10.99.0.3:40000`.
- Raw placement log SHA-256 `f6cd34a1912ed4d608bcf72fc95342e03133cd729c2cfa0a47d1d1a85832ff85`; wrapper SHA-256 `b9b6a6e02eb30bf52ad0f1f8a3af3b5a76ef2d44c62f670b03d4ad8ac5b2ff53`.

### Three-client same-key concurrency

`r73-centos-multinode-concurrent-idempotency.py` released three clients simultaneously with the same customer/key. All responses converged on one operation `op_a275aa9561cc6585`, one task `task_c495ae340930a30c`, and one instance `inst_1b82c88bf8cb5f4a` on W1. The instance reached succeeded/healthy state, its HTTP probe returned 200, and cleanup completed. The raw response manifest is SHA-256 `80e6015a120d2fc35418641fc8d76d115901821572e45505ed33853340d0e531`; wrapper log SHA-256 `e68e995b46e6fd873905f2fd5e25b6d864f3701d8ba1806c664ee810c6898a69`.

### Worker reboot with active workload

`r73-centos-multinode-worker-reboot.sh` was run once on W1 and once on W2. Each run provisioned an active workload, wrote a PostgreSQL marker, rebooted the real libvirt guest, waited for two consecutive healthy/available samples, verified HTTP and SQL persistence, then deprovisioned and checked for leftover resources.

| Worker | Boot ID before → after | Recovery observations after reboot | Evidence |
|---|---|---|---|
| W1, reboot requested 14:33:27Z | `5f319bba-312d-4cd9-9da0-03db4b553b9a` → `61122908-335b-4bbd-beff-ab72bd406765` | At 14:34:32: no containers, HTTP 000, unavailable; 14:34:39: instance stopped/unavailable with 3 containers and PostgreSQL ready, HTTP 200; 14:34:45 and 14:34:51: running/healthy/available, marker present, HTTP 200. | Run `worker-reboot-w1-20261024T1438Z`; `SHA256SUMS` SHA-256 `33a0c42fa03e9bb88c41ced0bb7c9f5677b095008c21d3b1fd8bed19fb4ed86e`. |
| W2, reboot requested 14:38:27Z | `689bbee7-206f-418a-8699-b2676537e6e6` → `13248664-dc61-42ae-863e-93bd7ff10576` | At 14:40:02: no containers, HTTP 000, unavailable; 14:40:11: instance stopped/unavailable with 3 containers and PostgreSQL ready, HTTP 200; 14:40:17 and 14:40:22: running/healthy/available, marker present, HTTP 200. | Run `worker-reboot-w2-20261024T143801Z`; `SHA256SUMS` SHA-256 `89142b73d7aa9af89834057e65e67c331ef892e5f9e58e4409b87d5d3b97f61a`. |

The observed temporary `stopped/unavailable` state while runtime was restoring was retained; neither run treated it as a false healthy report. The SQL marker was present after both reboots. Both deprovision operations succeeded and final inventories were empty (`containers=none`, `pods=none`, `volumes=none`, `files=none`). Raw manifests are under the protected run directories named in the table.

## Test procedures and evidence

The reproducible scripts in this repository are:

- [`r73-centos-multinode-placement.sh`](scripts/r73-centos-multinode-placement.sh), SHA-256 `b46345789b6f5a091f4aebd0b8daf45f97ee77474b4de80b1f5cbb4c47071575`.
- [`r73-centos-multinode-concurrent-idempotency.py`](scripts/r73-centos-multinode-concurrent-idempotency.py), SHA-256 `557d7549c50c96c312a31170c1ecb32f323f7ed0ce8f033e9eaa951cfb9cf02b`.
- [`r73-centos-multinode-worker-reboot.sh`](scripts/r73-centos-multinode-worker-reboot.sh), SHA-256 `520c9470c493a2ffcffa62ee27c08eebdf40268912fafa1a33d52649c18d7dc9`.

Protected raw install, runtime, and recovery captures are retained on the lab host with mode `0600` under `packaging/build/validation/rc5-r73/runtime/multi/centos/` and `/var/lib/libvirt/images/admiral-validation/validation/rc5-r73/runtime/multi/centos/`. They may contain environment-specific operational data and are not committed. R73 RPM/source payloads did not change during these runs, so these scenarios remain candidate-specific evidence.

## Remaining Multi-Node work

This cell remains **PARTIAL**, not PASS. Required scenarios still include worker network partition/rejoin, controlled active/idle node removal and peer/token revocation, hub reboot with active workloads, re-enrollment, broader communication/authentication checks, failure during an in-flight task, dependency/database outage, failure-helper rollback/retry, conflicting updates/deletes, exhaustive workload isolation, resource exhaustion, and performance measurement. A successful worker reboot is one scoped resilience result, not a distributed-systems guarantee. #272 remains open pending its full release-gate checks.

The active R73 matrix remains **4/8 PASS, 3/8 PARTIAL, 1/8 NOT TESTED**: all four Single-Node cells pass; Rocky, AlmaLinux and CentOS Stream Multi-Node remain incomplete; Fedora Rawhide Multi-Node is not tested. Full production readiness remains **NOT VALIDATED**.
