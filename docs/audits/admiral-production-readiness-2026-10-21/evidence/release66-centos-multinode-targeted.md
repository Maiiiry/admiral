# Release 66 CentOS Stream 10 Multi-Node targeted validation

Audit: `ADM-AUDIT-2026-10-21`  
Candidate: Admiral RC5 Release 66, root package-preparation commit `c5365da267eca6f1f5246c60a26c7875f07a5ffa`  
Result: **PARTIAL — named scenarios passed; the CentOS Stream Multi-Node cell is incomplete. Overall matrix remains 0/8.**

This evidence covers selected runtime scenarios on an isolated, three-guest CentOS Stream 10 x86_64 topology. Passing targeted regressions does not complete the cell or establish broad production readiness.

## Candidate and lab

The guests were created from the updated CentOS Stream 10 R66 seed (`2cbea69dd6f99334decc0c89441f54d7d78f1e6370e2ecd7771e9cc51096bf68`) with 2 vCPU and 2 GiB RAM each. SELinux was enforcing. The hub ran `admirald`, central PostgreSQL, Harbor and WireGuard; W1 and W2 ran Fleet and rootless Podman. Underlay addresses were `10.77.0.10` (hub), `.11` (W1) and `.12` (W2); WireGuard addresses were `10.99.0.1`, `.2` and `.3`. No production infrastructure or customer data was used.

All six Admiral packages were the exact EL10 candidate NEVRAs `0.0.1rc5-66.el10`. Relevant component pins:

| Component | SHA |
| --- | --- |
| `admirald` | `643d203576037a12eba59d534d51d170acae9b5d` |
| `admiral-fleet` | `0c805d6293bfb11fd4f015f1b0ccff520481e627` |
| `admiralctl` | `49cf2428c064434c65af9a14f96975c1bb2db637` |
| `admiral-flagship` | `b7325bbc71fc474a521496e593b2967e4d555ac1` |
| `admiral-harbor` | `dd39e9a74bf658ecf6fd6e9f8bd30b2ddf82d7db` |

The hub installer recap was `ok=238 changed=105 unreachable=0 failed=0`; W1 and W2 each reported `ok=154 changed=54 unreachable=0 failed=0`. Temporary worker bootstrap credentials were revoked after installation. The protected installer logs include exact package inventories and timing.

## Results

| Test ID | Scenario | Observed result | Status |
| --- | --- | --- | --- |
| `R66-CENTOS-MN-BOOT-01` | Install hub and enroll two workers using secure installer paths | All three installer runs exited 0. Both workers reported active/healthy/available with current heartbeats; the two WireGuard peers handshook. | **PASS, scoped** |
| `R66-CENTOS-MN-PLACEMENT-01` | Explicitly place an `e2e-whoami` workload on W1 and W2, check DB readiness, HTTP, idempotent replay and removal | W1 operation `op_8e05397e9a23b019`, instance `inst_3f80432a64074fe8`; W2 operation `op_32c48193400d1c3c`, instance `inst_4ca6bfd4d2e8d9fc`. Each replay with its same idempotency key returned the original operation and instance. Both worker DBs passed `pg_isready`, each SQL marker was inserted, and the hub reached each app over WireGuard with HTTP 200. Deprovision succeeded and each worker had zero matching containers, pods, volumes, user units and files. | **PASS, scoped** |
| `R66-CENTOS-MN-FAILED-SVC-01` | Provision fixture whose declared DB service exits immediately (#227) | Operation `op_bcd0ed32d4dc92fa` terminated `failed`; it did not report a healthy/available workload. No DB container remained. Deprovision `op_636e76811cf015ae` succeeded and post-cleanup inventory was empty. | **PASS for #227 regression, scoped** |
| `R66-CENTOS-MN-HUB-REBOOT-01` | Reboot the hub after worker onboarding with an active W1 workload (#211) | The hub boot ID changed. Its persistent and runtime WireGuard configuration each had two peers and two fresh handshakes; both workers returned active/healthy/available without rerunning Ansible. A first post-boot workload sample was conservatively `running/healthy/unavailable`; the next health sample about five seconds later was `running/healthy/available`. The workload returned HTTP 200 over WireGuard and its SQL marker remained after reboot. Deprovision succeeded. | **PASS for recovery and data marker, scoped; transient availability convergence recorded** |
| `R66-CENTOS-MN-PODMAN-DELETE-01` | Inject Podman removal failures during deprovision, restore Podman and retry (#228) | On W2, instance `inst_e153116caeef9eff` first returned operation `op_e9e49f8d2818a3c4` with status `failed`, while an infra container, pod and DB volume remained visible. `/usr/bin/podman` was restored byte-for-byte (SHA-256 `4b08fd95b6a5399146eabaa4b63ed9676d82197de9f13215ebefcf9c0f82cd2d`). Retry `op_6d0c1737f3641935` succeeded; API state was `deprovisioned` and final container, pod, volume, unit and instance-path inventories were empty. The injection-only audit log was removed after its contents were captured locally. | **PASS for #228 regression and retry cleanup, scoped** |
| `R66-CENTOS-MN-IDEMP-RACE-01` | Submit two identical provision requests concurrently with the same idempotency key (#207) | Two independent CLI processes targeted W1 and both exited 0. Both returned operation `op_5f5f49264c9cb684` and instance `inst_c7c4c62605d81ef7`; only one workload was present on W1 (infra/app/DB containers, one pod and one volume). Deprovision `op_87ff37aa23816f5d` succeeded and final inventories were empty. | **PASS for same-key concurrent replay, scoped** |
| `R66-CENTOS-MN-DB-OUTAGE-01` | Stop central PostgreSQL for 60 seconds while a W1 workload is serving (#264) | During the outage, the app stayed HTTP 200. Hub logs recorded 78 Fleet `503` responses and zero `401`/`429`; after PostgreSQL returned both workers converged to active/healthy/available. The instance returned running/available, its SQL marker remained, HTTP stayed 200 and deprovision succeeded with empty inventory. | **PASS for #264 recovery behavior, scoped** |
| `R66-CENTOS-MN-WORKER-REBOOT-01` | Reboot W2 while it owns an active workload; verify boot ID, API/runtime convergence, HTTP, SQL persistence and cleanup | Instance `inst_cccd37bd501c7b29` provisioned with operation `op_6f75f10664188d01`. W2 boot ID changed from `0f540841-c92d-42a4-a141-491ebfeb16e4` to `d1adad74-b1a7-47fb-802d-47731251f4e1`. It took about 69 seconds from reboot request to two consecutive healthy samples. At poll 1 the node was active/healthy but the instance unavailable and runtime unreachable; at poll 2 the containers, DB, SQL marker and HTTP 200 were back while instance status was briefly stopped/unavailable; by poll 3 it was running/healthy/available. Deprovision `op_66146ac17d6125d5` succeeded and final inventory was empty. | **PASS for worker reboot recovery and persistence, scoped; transient status convergence recorded** |

The #207 test checks duplicate requests with the exact same idempotency key and body. It does not cover conflicting concurrent updates/deletes, client timeout after commit, cross-customer replay, or queue/task replay after worker failure. Issues #207 and #228 are not closed by this report; #228 remains open with `fix-proposed` pending the wider matrix review.

## Reproduction

1. Start three clean overlays from the checksum-verified CentOS Stream 10 R66 seed. Install the hub with the supported admin-portal profile and enroll both workers with the supported worker profile. Check RPM NEVRAs and node/WireGuard health.
2. Apply `examples/apps/e2e-whoami.yaml`. Provision separately to `centos-r66-w1` and `centos-r66-w2` using unique customer IDs and stable idempotency keys. Replay each command and compare operation/instance IDs. Check DB readiness and insert a per-instance SQL marker; request each HTTP endpoint from the hub over WireGuard; deprovision and inspect worker Podman/systemd/filesystem inventories.
3. On W2, provision a disposable workload, then run the tracked `scripts/r66/r66-alma-multinode-podman-removal-failure.sh` with the R66 CentOS hub and W2 host-key files, instance ID, output directory, and optional hub/worker IPs. Its defaults preserve the AlmaLinux addresses; the final two arguments select the CentOS hub and W2. Confirm failure with resources remaining, byte-identical Podman restoration, successful retry and empty inventories.
4. For concurrent idempotency, start two independent `admiralctl instances provision` CLI processes at the same time from the hub with the same app, tier, customer, idempotency key and target node. Compare JSON operation and instance IDs; inspect the selected worker's Podman inventory; deprovision and verify zero resources.
5. Provision a W1 workload with a SQL marker, record the hub boot ID and worker state, run `virsh reboot adm-r66-centos-hub`, and wait for SSH. Check changed boot ID, two configured/runtime peers, fresh handshakes, worker states, app HTTP and the SQL marker before deprovisioning.
6. Run `scripts/r66/r66-centos-multinode-db-outage.sh SSH_KEY HUB_KNOWN_HOSTS WORKER_KNOWN_HOSTS HUB_IP WORKER_IP centos-r66-w1 /absolute/evidence/output`. It provisions a disposable W1 workload, writes a SQL marker, verifies HTTP, schedules central PostgreSQL restoration after 60 seconds, samples the outage, checks Fleet response codes and both workers' recovery, then deprovisions and records a mode-0600 SHA-256 manifest. Use only the isolated audit guests and a fresh absolute output directory.
7. Run `scripts/r66/r66-centos-multinode-worker-reboot.sh SSH_KEY HUB_KNOWN_HOSTS WORKER_KNOWN_HOSTS HUB_IP WORKER_IP centos-r66-w2 adm-r66-centos-w2 /absolute/evidence/output`. It provisions a disposable W2 workload with a SQL marker, reboots that guest using libvirt, records boot ID/API/runtime/HTTP samples through recovery, requires two consecutive healthy samples, then deprovisions and verifies empty resource inventories. Use a fresh absolute output directory.

## Evidence integrity and limits

Raw logs and command outputs are retained mode `0600` in the ignored local directory `packaging/build/validation/rc5-r66/`. The files are not committed because they include machine-specific data. SHA-256 references:

| Capture | SHA-256 |
| --- | --- |
| `centos-multinode-hub-install.log` | `f5e007e1cbeb22cf3e53f5ba8fcee37ef4cb4180f83659935258bb78449116d0` |
| `centos-multinode-w1-install.log` | `ccbb81fc607f42c0f93c33b0ec808958fb291f049277c9ec467c2a740ea1db04` |
| `centos-multinode-w2-install.log` | `24eb369396741b3ce78127a1a7e3549d3b3f5741c24a08f57a4162612b16832d` |
| `centos-multinode-placement-recheck.log` | `d8e68626048739a9b61bcde9fb5a8a27332328dcb984a05d7e3c7d4ef87160fa` |
| `centos-multinode-failed-service.log` | `145381f054da4225e4dc2c77fffefd7d54545c7dc2ef19cfdd96fd1089e7616a` |
| `centos-multinode-hub-reboot-recheck.log` | `c434f6e624b9d7f5f725fa49c421b1d6000d87f245d9ac35bfa19793cfe16505` |
| Podman failure evidence manifest `centos-multinode-podman-removal-failure/SHA256SUMS` | `af526dca064e31ea724a65d38af5c0768406227f41ec34e0f8692ab125c102a4` |
| Injected Podman command log | `62facee34ca49df811771aa89cac55d420fb67645ce7eccab242f27c12cd8059` |
| Concurrent idempotency evidence manifest `centos-multinode-idempotency-race/SHA256SUMS` | `0db50b4e40f0d9c0a7796bb21bbe6f8826d06337a5400ba3a4ff5085d7f6fcfd` |
| Each concurrent request JSON | `ef6652d50be6c52fba972365b00890a83928215db72ad2a149a36d3c614410da` |
| Concurrent result summary | `b03b29d66fc880d90ff44fa466f368f806b10e2c4c217474f3b1587ecb737ffa` |
| Central PostgreSQL outage evidence manifest `centos-multinode-db-outage/SHA256SUMS` | `0f018e6c398fd9e52dbc0c0a9014e5d0f3aa06ed14c1f7c788b705e24ee55c54` |
| Central PostgreSQL outage Admirald journal | `93a633373f9fc6ebe6175c63b77cbf2598d3df1be71b7264e88f623ca83dd0f3` |
| Central PostgreSQL outage timeline | `bd27ffd39ba9cbbe1910a96481a2d221f76062886fefd8d11341dbb3f56bf997` |
| Worker-reboot evidence manifest `centos-multinode-worker-reboot/SHA256SUMS` | `4aec731f63c34a776582a2cbe2c2ccbc80aa91873c48e86fd4dd2567458c8e8e` |

A corrected hub-reboot run passed after an earlier SQL quoting error in the harness; the failed attempt and its captured runtime observations are preserved separately. An initial placement probe incorrectly assumed a loopback-bound app port; the corrected probe reached the actual WireGuard-bound endpoint from the hub. Neither was classified as a product defect. This run did not test public DNS/TLS, task interruption/replay, network latency, controlled memory/disk exhaustion, comprehensive authorization/isolation negatives, conflicting updates/deletes, or performance. The Multi-Node cell remains incomplete.
