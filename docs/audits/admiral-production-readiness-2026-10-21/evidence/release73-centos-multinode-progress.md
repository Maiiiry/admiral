# Release 73 CentOS Stream 10 Multi-Node progress — partial

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Candidate: six coordinated `0.0.1rc5-73` RPMs; source pins and CI are in [`release73-candidate.md`](release73-candidate.md).<br>
Execution date: 2026-10-24 UTC. The audit spans three calendar days, 2026-10-21 through 2026-10-24.<br>
Result: **PARTIAL**. Three real guests are enrolled. Clean install, placement/lifecycle on both workers, one concurrent idempotency race, reboot recovery on both workers, controlled active/idle worker removal with peer/token revocation and re-enrollment, W2 partition/rejoin, hub reboot with an active W1 workload, and persistence of W2 revocation across a hub reboot passed as named scenarios. Multi-Node cell acceptance is not complete.

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

### Controlled worker removal, peer/token revocation, and re-enrollment

`R73-CENTOS-MN-NODE-REMOVE-01` ran on the exact Release 73 EL10 candidate against the real W2. The harness first provisioned `e2e-whoami` on W2 and waited for `running/healthy/available`; its WireGuard endpoint returned HTTP 200. While that workload was active, `admiralctl nodes remove` exited 1 with the active-instance count and `--force` guidance. The node remained active/healthy, the instance remained running/healthy/available, and HTTP stayed 200. Deprovision succeeded and the worker inventory showed no matching containers, pods, volumes, Quadlet/systemd units, or instance files; only then was idle-node removal attempted.

After idle removal, W2 was absent from the control-plane inventory. The hub's live WireGuard allowed IPs and persistent `wg-admiral.conf` both lost `10.99.0.3/32` while retaining W1 `10.99.0.2/32`; W1 remained active/healthy/available. The removed W2's previous Fleet token was sent in memory from the worker to the hub for one authenticated `POST /api/v1/fleet/health` probe; the hub returned HTTP 401. The token was never written to an evidence file or printed. From the removed W2, the tested private UI URL `https://10.99.0.1:5001/` timed out (curl exit 28, HTTP `000`). This proves only the tested endpoint and token behavior; it is not an exhaustive reachability or authorization audit.

The same guest was then re-enrolled with the supported secure worker installer. The helper confirmed the temporary bootstrap key was rejected afterward, and postchecks found the exact R73 common/Fleet RPMs, SELinux Enforcing, active Fleet/firewalld/fail2ban/auditd, a restored hub peer, and active/healthy/available registration. A following placement run on both workers again passed same-key replay, healthy/available state, two storage samples at the declared 1 GiB limit, PostgreSQL marker roundtrip, HTTP 200 over WireGuard and empty deprovision inventories.

| Evidence | Result and retained record |
|---|---|
| Active refusal, idle removal, peer and token revocation, private UI negative | Final corrected run `node-removal-w2-complete-20261024T145955Z`; local protected `SHA256SUMS` verifies every raw capture. Metadata records instance `inst_ec3d23ca2f1b97eb`, endpoint `10.99.0.3:40005`, HTTP 200 before and after rejected removal, old-token HTTP 401, and private UI HTTP `000`. |
| Reproducible removal procedure | [`r73-centos-multinode-node-removal.sh`](scripts/r73-centos-multinode-node-removal.sh), SHA-256 `f445841223df0b94cfaee3b6fdd5415cb06a52ffcbde388432892a2797804aac`. |
| Secure re-enrollment procedure and result | [`install-worker-audit.sh`](../scripts/install-worker-audit.sh); final log `re-enroll-w2-final-20261024T150102Z.log` SHA-256 `5e5f65951dd81c990ea5cd04752d01602289c032940195fe546643128517ace8`, mode `0600`. Recap: `ok=145 changed=13 unreachable=0 failed=0`; the temporary bootstrap key was rejected. Hub postcheck reported W2 active/healthy/available with exact R73 RPMs. |
| Re-enrollment placement and cleanup | Protected run `re-enrollment-placement-20261024T145101Z`; its `SHA256SUMS` digest is `d9b4e526f19f05981acb27335170c784531370ac665823336ae51889d8a145fb`. The initial parent-directory invocation error is preserved in `harness-error.txt` and excluded; the corrected run passed for W1 and W2. |

Two earlier removal-harness attempts are retained and excluded from PASS: the first did not include the token assertion; the second exposed incorrect SSH remote-command quoting before the assertion ran. A corrected standalone probe against the removed node's still-present local token returned HTTP 401. The final corrected integrated run then passed all removal assertions, including token rejection. These were harness defects, not reproduced Admiral failures.

### W2 WireGuard partition and rejoin

`R73-CENTOS-MN-PARTITION-01` changed only the hub-side W2 `AllowedIPs` route to a blackhole address, with a timed systemd restore as a fail-safe. W2 immediately lost access to the hub API (curl exit 28). The instance became unavailable at the second poll (~15 seconds after partition, `runtime_observation_stale`); the node remained active/healthy during its grace period and became offline/degraded at poll 13 (~139 seconds after partition, `heartbeat_timeout`). Restoring the peer returned the node and instance to active/healthy/available on the second poll (~12 seconds). The workload returned HTTP 200, its SQL marker persisted, and deprovision left no matching containers, pods, volumes or files.

- Run: `partition-w2-20261024T150451Z`; instance `inst_8d57b12f6c84b41c`.
- Protected `SHA256SUMS` digest: `a59565d4542f0eae08ff959720f4a0a0476bf2ebf826940189fb47c6e74c85c1`; every listed artifact verified.
- Reproducer: [`r73-centos-multinode-partition.sh`](scripts/r73-centos-multinode-partition.sh), SHA-256 `47e35323b3249d49000ffdf5743d3de1cebd6bb7b78df2bde059ddbccf40f811`.

The initial `running/healthy/unavailable` instance state preceded the node heartbeat timeout and was retained in the timeline; it was not reported as a healthy/available workload.

### Hub reboot with active W1 workload

`R73-CENTOS-MN-HUB-REBOOT-01` rebooted the real hub guest while `e2e-whoami` remained active on W1. The hub boot ID changed. On recovery poll 2 (~60 seconds), `admirald`, PostgreSQL and WireGuard were active; both worker routes and fresh handshakes were present; the hub reported current post-reboot heartbeats and both workers active/healthy/available. The W1 instance returned running/healthy/available, its SQL marker persisted, and HTTP returned 200. Deprovision and final W1 inventory checks were clean.

- Run: `hub-reboot-w1-corrected-20261024T151025Z`; instance `inst_ddad6168c3f75f6e`.
- Protected `SHA256SUMS` digest: `6155f6c25da1474ffc97c99a077c5c5a6f62e12d413f81231243b1b766b3c0d4`; every listed artifact verified.
- Reproducer: [`r73-centos-multinode-hub-reboot.sh`](scripts/r73-centos-multinode-hub-reboot.sh), SHA-256 `db75bfa58dad9289fa06cce3665501913a52c50134754caeed3bcc48b4dcbf36`.

One earlier hub-reboot harness attempt is retained under `hub-reboot-w1-20261024T150803Z` and excluded: it printed an AlmaLinux test ID, then exited with a local command-not-found error after `virsh reboot` had succeeded. The hub became reachable again; manual postchecks captured a changed boot ID, active services, healthy nodes/workload, SQL marker persistence and HTTP 200, then deprovisioned the workload with empty inventories. The script was corrected before a separate complete run. The failure was in the test harness; it did not establish a product failure.

### Revoked W2 peer stays absent across hub reboot

To isolate revocation from the re-enrollment path, W2 was idle-removed a second time after the placement run. `R73-CENTOS-MN-NODE-REMOVE-01` repeated the active-removal refusal with HTTP 200 before and after, then removed the idle node (`node-removal-w2-pre-hub-reboot-20261024T151701Z`, exit 0, final inventory portal + W1). `R73-CENTOS-MN-REMOVED-PEER-HUB-REBOOT-01` then rebooted the real hub. Before the reboot, live and persistent WireGuard state each contained only W1's `10.99.0.2/32`, and the node inventory again held only the portal and W1.

The hub boot ID changed from `5967ae53-c281-44c9-80b6-0af41c16b586` to `6af33376-5c9d-4fd2-bdc6-09052f3506c8`. SSH returned at poll 5. At recovery poll 3 (15:18:43Z, ~62 seconds after the reboot request), `admirald`, PostgreSQL and `wg-quick@wg-admiral` were active, exactly one route and one fresh W1 handshake were present, and the hub and W1 were active/healthy/available with post-reboot heartbeats. W2's `10.99.0.3/32` never appeared in any route sample or in the post-reboot live/persistent configuration, and W2 stayed absent from every node sample. The run exited 0 with `result=PASS-scoped`.

W2 was then re-enrolled a second time. The secure worker installer completed with `ok=145 changed=13 unreachable=0 failed=0`, verified a hub handshake on the first attempt and revoked the bootstrap SSH credential. The hub now lists all three nodes active/healthy/available and again carries `10.99.0.3/32` in live and persistent state. This probe ran without an active workload and does not test every route or hub service.

- Run: `removed-peer-hub-reboot-20261024T151740Z`.
- Prerequisite removal: `node-removal-w2-pre-hub-reboot-20261024T151701Z`; `SHA256SUMS` digest `329345483103a0471f29c2d1fa4154aa47a4e6dd69e6646368a7520014624cbd`, verified.
- Protected `SHA256SUMS` digest: `5d4071083bb6b6ae2a7486df666d44d11e371fad0507f583cc1a1791a627842f`; all 23 listed artifacts verified, directory mode `0700` and captures mode `0600`.
- Final lab postcheck after re-enrollment: `final-postcheck-after-revoked-peer-reboot-20261024T152314Z`; `SHA256SUMS` digest `0252f69645968c9904bd90637b6894809312993d8680e628c0d05c8f55b5079e`, all five captures verified.
- Re-enrollment log: `re-enroll-w2-after-revoked-peer-reboot-20261024T151857Z.log`, SHA-256 `76e6a283eba4de2f44ce9c9b19894e3d47254d4528105efe55d1bbe9d3a0b450`, mode `0600`.
- Reproducer: [`r73-centos-multinode-removed-peer-hub-reboot.sh`](scripts/r73-centos-multinode-removed-peer-hub-reboot.sh), SHA-256 `e72c41922bc87da945432fc25151752df5be810ae7f34db21732d410470f5089`.

### Revocation-helper failure, retention, and successful retry

`R73-CENTOS-MN-PEER-REVOCATION-RETRY-01` used the same exact R73 three-guest CentOS Stream candidate with W2 active/healthy/available and no non-deprovisioned workload assigned to it. A temporary systemd drop-in and failure shim were created only under `/run`; the shim returned a structured helper error. The captured CLI result was HTTP 503 after its three retries, and the service journal recorded four injected helper invocations. After the failure, W2 remained active/healthy/available; its `node_tokens` worker row remained active with the same token-hash fingerprint; and W2's `/32` remained in both live and persistent WireGuard state. The hub and W1 also remained active/healthy/available.

The volatile drop-in and shim were removed, systemd was reloaded, and the packaged helper/socket were restored. A second `admiralctl nodes remove` succeeded. The W2 row and its `node_tokens` row were both absent, and the W2 route was absent from live and persistent state. The supported secure installer then re-enrolled W2: it reported SSH exit 0, rejected the temporary bootstrap key, restored the exact two R73 worker RPMs and WireGuard routes, and the hub again reported all three nodes active/healthy/available. No RPM or product source was modified for the injection.

- Run: `peer-revocation-retry-20261024T153022Z`; test time 15:30:26–15:34:35 UTC; `result=PASS-scoped`.
- Protected `SHA256SUMS` digest: `029bf4f44cb89435bec7a0575f56cda05d32bafc71d51df57b3b5c8217ded4a5`; every listed artifact verified.
- Re-enrollment log SHA-256: `791ea10a81c878a7af114ac0de440cbfed43f1241e9685412507a25e412accf8`, mode `0600`.
- Reproducer: [`r73-centos-multinode-peer-revocation-retry.sh`](scripts/r73-centos-multinode-peer-revocation-retry.sh), SHA-256 `34803fbe0a0f76f0122450bb9ce9d6cb7c5a7186784479135202e63603aa4e20`.

Two earlier harness attempts are retained and excluded from PASS: `peer-revocation-retry-20261024T152906Z` expected an error detail that `admiralctl` does not print (the observed HTTP 503 was correct); `peer-revocation-retry-20261024T152951Z` had an unquoted `grep` pattern. Both traps restored the packaged helper, and W2 stayed enrolled. The corrected complete run above verified the full failure/retention/retry/re-enrollment sequence.

## Test procedures and evidence

The reproducible scripts in this repository are:

- [`r73-centos-multinode-placement.sh`](scripts/r73-centos-multinode-placement.sh), SHA-256 `b46345789b6f5a091f4aebd0b8daf45f97ee77474b4de80b1f5cbb4c47071575`.
- [`r73-centos-multinode-concurrent-idempotency.py`](scripts/r73-centos-multinode-concurrent-idempotency.py), SHA-256 `557d7549c50c96c312a31170c1ecb32f323f7ed0ce8f033e9eaa951cfb9cf02b`.
- [`r73-centos-multinode-worker-reboot.sh`](scripts/r73-centos-multinode-worker-reboot.sh), SHA-256 `520c9470c493a2ffcffa62ee27c08eebdf40268912fafa1a33d52649c18d7dc9`.
- [`r73-centos-multinode-node-removal.sh`](scripts/r73-centos-multinode-node-removal.sh), SHA-256 `f445841223df0b94cfaee3b6fdd5415cb06a52ffcbde388432892a2797804aac`.
- [`r73-centos-multinode-partition.sh`](scripts/r73-centos-multinode-partition.sh), SHA-256 `47e35323b3249d49000ffdf5743d3de1cebd6bb7b78df2bde059ddbccf40f811`.
- [`r73-centos-multinode-hub-reboot.sh`](scripts/r73-centos-multinode-hub-reboot.sh), SHA-256 `db75bfa58dad9289fa06cce3665501913a52c50134754caeed3bcc48b4dcbf36`.
- [`r73-centos-multinode-removed-peer-hub-reboot.sh`](scripts/r73-centos-multinode-removed-peer-hub-reboot.sh), SHA-256 `e72c41922bc87da945432fc25151752df5be810ae7f34db21732d410470f5089`.
- [`r73-centos-multinode-peer-revocation-retry.sh`](scripts/r73-centos-multinode-peer-revocation-retry.sh), SHA-256 `34803fbe0a0f76f0122450bb9ce9d6cb7c5a7186784479135202e63603aa4e20`.

Protected raw install, runtime, and recovery captures are retained on the lab host with mode `0600` under `packaging/build/validation/rc5-r73/runtime/multi/centos/` and `/var/lib/libvirt/images/admiral-validation/validation/rc5-r73/runtime/multi/centos/`. They may contain environment-specific operational data and are not committed. R73 RPM/source payloads did not change during these runs, so these scenarios remain candidate-specific evidence.

## Remaining Multi-Node work

This cell remains **PARTIAL**, not PASS. Required scenarios still include broader communication/authentication checks, failure during an in-flight task, dependency/database outage, conflicting updates/deletes, exhaustive workload isolation, resource exhaustion, and performance measurement. The removal probe covers one private UI path and one prior token; it does not demonstrate that all routes or credentials are revoked. The post-removal hub reboot and helper-failure rollback/retry now pass on CentOS; #272 remains open pending Fedora validation and post-removal reboot checks on Rocky and AlmaLinux. Successful scoped partition recovery, hub/worker reboots, and removal are not a distributed-systems guarantee.

The active R73 matrix remains **4/8 PASS, 3/8 PARTIAL, 1/8 NOT TESTED**: all four Single-Node cells pass; Rocky, AlmaLinux and CentOS Stream Multi-Node remain incomplete; Fedora Rawhide Multi-Node is not tested. Full production readiness remains **NOT VALIDATED**.
