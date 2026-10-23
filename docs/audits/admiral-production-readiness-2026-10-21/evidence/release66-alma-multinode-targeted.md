# Release 66 AlmaLinux 10 Multi-Node targeted validation

Audit: `ADM-AUDIT-2026-10-21`  
Candidate: Admiral RC5 Release 66, root `c5365da267eca6f1f5246c60a26c7875f07a5ffa`  
Result: **PARTIAL — targeted scenarios passed; the AlmaLinux Multi-Node matrix cell is not complete. Overall matrix remains 0/8.**

This record covers runtime evidence for selected Release 66 Multi-Node scenarios. It does not claim that the cell or release is validated. The broad concurrency, security, resource-exhaustion, workload update/deprovision, and other resilience checks remain outstanding.

## Candidate and environment

The tested target was AlmaLinux 10.2 x86_64. The three guests were cloned from the updated AlmaLinux seed and used 2 vCPU and 2 GiB RAM each. SELinux was enforcing. The hub was `adm-r66-alma-hub` (`10.77.0.210`, WireGuard `10.99.0.1`); workers were `adm-r66-alma-w1` (`10.77.0.211`, `10.99.0.2`) and `adm-r66-alma-w2` (`10.77.0.212`, `10.99.0.3`). No production host or service was involved.

The exact Release 66 component pins were:

| Component | SHA |
| --- | --- |
| `admirald` | `643d203576037a12eba59d534d51d170acae9b5d` |
| `admiral-fleet` | `0c805d6293bfb11fd4f015f1b0ccff520481e627` |
| `admiralctl` | `49cf2428c064434c65af9a14f96975c1bb2db637` |
| `admiral-flagship` | `b7325bbc71fc474a521496e593b2967e4d555ac1` |
| `admiral-harbor` | `dd39e9a74bf658ecf6fd6e9f8bd30b2ddf82d7db` |

All six Admiral RPMs were built as `0.0.1rc5-66.el10` and installed from the local Release 66 repository. The Admiral RPM SHA-256 values were:

| RPM | SHA-256 |
| --- | --- |
| `admiral-common-0.0.1rc5-66.el10.noarch.rpm` | `eec5d172b43cd41a0fab773c56d8787e1871ed7088f0d076647aa9a0e3440a1e` |
| `admirald-0.0.1rc5-66.el10.x86_64.rpm` | `59d1f280e0103abe369159d1084dee85d0f4addafc682573a2e9beb3546eb560` |
| `admiral-fleet-0.0.1rc5-66.el10.x86_64.rpm` | `8c2bea5d4b02f822fa43984378bc40bb1732254447b311df1df7c87d12f92284` |
| `admiralctl-0.0.1rc5-66.el10.x86_64.rpm` | `df7fe8f357cd0897063ed76b49eb64727bfc72e0f1cd272935899a3fd5a50087` |
| `admiral-flagship-0.0.1rc5-66.el10.noarch.rpm` | `77e9208aca23e12b80b4964c92007870950f063bebba85841780a51c846d0a52` |
| `admiral-harbor-0.0.1rc5-66.el10.noarch.rpm` | `09f0cbb30d57930e4d2bc1644c191e404f34543baa1fee7ce980e25d05195c0b` |

The exact local 14-RPM repository manifest is `packaging/build/repos/el10-rc5-r66-x86_64/SHA256SUMS` in the validation workspace. The private raw logs are ignored by Git and stored mode `0600` under `packaging/build/validation/rc5-r66/`.

## Results

| Test ID | Scenario | Result | Evidence and observation |
| --- | --- | --- | --- |
| `R66-ALMA-MN-BOOT-01` | Install the hub and enroll two workers using the supported installer profiles | **PASS, scoped** | Hub and both worker installers exited 0. The hub listed both workers as `active/healthy/available`; both WireGuard peers handshook. Workers reported `admiral-fleet-0.0.1rc5-66.el10.x86_64`, active Fleet, `admiral-apps` linger enabled, and rootless Podman. |
| `R66-ALMA-MN-E2E-01` | Provision one workload explicitly on each worker | **PASS after convergence, scoped** | Applied `examples/apps/e2e-whoami.yaml` (SHA-256 `8adad770e879a655a676af2e9f389343f93547a39f73f5779dbd7c9c1372d2f4`). W1 operation `op_c39ff6be142c9ca6`, instance `inst_2297cbb651ac17e3`; W2 operation `op_72bdf33b4eb691ce`, instance `inst_979998400ad11b76`. Both ended `running/healthy/available`, with app, PostgreSQL and infra containers up under rootless Podman. Both worker endpoints returned HTTP 200 and `pg_isready` succeeded. |
| `R66-ALMA-MN-COLD-01` | Observe health during cold service startup | **TRANSIENT, self-recovered; tracked by #236** | On W1, a query at `08:30:30Z` saw the instance `failed/unhealthy` with an earlier health observation at `08:29:40Z`; the app unit was active, but PostgreSQL initialization completed at `08:30:19Z`. By `08:30:34Z`, Admiral reported `running/healthy`; the endpoint returned HTTP 200. W2 was observed healthy after its provision completed. This matches the already tracked cold-start convergence behavior in #236; no new issue was opened. |
| `R66-ALMA-MN-IDEMP-01` | Concurrent duplicate provision requests using the same idempotency key | **PASS, scoped** | Two concurrent W1 replays returned the same operation `op_c39ff6be142c9ca6` and instance `inst_2297cbb651ac17e3`. The control plane retained exactly two test instances, one on each worker. |
| `R66-ALMA-MN-DB-01` | Stop central PostgreSQL for 120 seconds while both workers are active | **PASS for issue #264 regression, scoped** | The timer restored PostgreSQL automatically (`Result=success`). The hub logged 182 Fleet authentication responses with `auth_db_error` / HTTP 503; each worker log recorded 91 HTTP 503 responses. The captured logs contain zero HTTP 401 and zero HTTP 429 responses. Both apps returned HTTP 200 throughout sampled outage points. After recovery, `admiralctl nodes list` showed both workers active, healthy and available. |
| `R66-ALMA-MN-RETRY-01` | Direct valid-token Fleet requests during a second short database outage | **PASS for status/header, scoped** | Requests routed through each worker's WireGuard interface received HTTP 503 and `Retry-After: 5`. Fleet tokens were read from the protected guest configuration and piped to curl without printing or recording them. The timer restored PostgreSQL (`Result=success`). |
| `R66-ALMA-MN-HUB-REBOOT-01` | Reboot the hub with two workers and active workloads | **PASS on AlmaLinux Multi-Node, scoped** | `virsh reboot` changed the hub boot ID. After restart, the `wg-quick@wg-admiral`, PostgreSQL and Admirald units were active; the boot configuration and runtime interface each contained two WireGuard peers. Both workers returned `active/healthy/available` without rerunning Ansible. Both app endpoints returned HTTP 200 and both SQL markers remained `pre-outage`. This is Release 66 runtime evidence for the fix tracked by #211; the issue remains open for other matrix cells. |
| `R66-ALMA-MN-WORKER-REBOOT-01` | Reboot W1 with its workload active | **PASS on AlmaLinux Multi-Node, scoped** | The worker boot ID changed. Fleet, rootless Podman, the app/database/infra units and `pg_isready` recovered; the `pre-outage` SQL marker remained. Both workers returned healthy and both endpoints returned HTTP 200. Capture: `alma-multinode-w1-reboot-postcheck.log`, SHA-256 `c79c10682078db5c7cbbac17a66195fb99fd01336f6550a9fe04a7dd3d4c45fc`. |
| `R66-ALMA-MN-PARTITION-01` | Isolate W2 from the hub over WireGuard, then restore connectivity | **PASS for offline detection and rejoin, scoped** | With a timed, W2-only firewall rule, W2 became `offline/degraded/unavailable` after 141 seconds. Removing the rule restored `active/healthy/available` within 23 seconds; both workload endpoints returned HTTP 200. Capture: `alma-multinode-w2-partition.log`, SHA-256 `70aae1aa31ab5333d429c5e23ef5bd7a9f71e00173b2291bd578d3efd1d8ee64`. |
| `R66-ALMA-MN-STALE-01` | Check assigned instance availability while W2 is partitioned (#237) | **PASS for #237 regression, scoped** | During the outage, the instance retained the last `health_status=healthy` observation and `technical_status=running`, but `effective_availability=unavailable` with reason `heartbeat_timeout`. After rejoin it received a fresh health timestamp and became available. Capture: `alma-multinode-w2-instance-offline.log`, SHA-256 `99dcccb99b1601b09ad91636f719a0ae68e4422cd51f6a26e3cce98cc9d3e7e7`. |
| `R66-ALMA-MN-FAILED-SVC-01` | Provision the declared service fixture whose database command exits immediately (#227) | **PASS for #227 regression, scoped** | Provision operation `op_c8d794c0c48ed9c1` ended `failed` with the database readiness error; instance `inst_48394799b20fae2d` was `failed/unavailable`, and the DB unit had failed after retries with no DB container. Deprovision `op_c135f4b40c0ec8a3` succeeded. Post-cleanup inventory found no matching containers, pods, volumes, user units, instance data directory or Quadlet files. Captures include `alma-multinode-failing-db-cleanup.json` (SHA-256 `71799c7dd843b32a013fca16444a0b53b35428ef8aa6d2e446dd879cc3e13441`) and `alma-multinode-failing-db-postcleanup.log` (SHA-256 `f3a9f7a3c7d233ddeabe439facc2db3b7c636adfeed40d5b58cf92295a5f48de`). |
| `R66-ALMA-MN-PODMAN-DELETE-01` | Inject nine targeted Podman deletion errors during deprovision, restore Podman, and retry (#228) | **PASS for #228 regression and retry cleanup, scoped** | On W2, first operation `op_c66ed9a57491139f` returned `failed`; the instance remained `stopped` and unavailable, not deprovisioned. The nine targeted failures left the infra container, pod and DB volume visible. The original Podman binary hash (`a2cbf6699a85b2fc60fc58ee5ce1e78c5c167c755bccd1ce3f2d5b60a122133`) was restored byte-for-byte. Retry `op_6e8932c408957968` succeeded; final container, pod, volume, Quadlet and instance-path inventories were empty. The injected workload was the already-captured W2 `e2e-whoami` instance `inst_979998400ad11b76`; it was intentionally removed by this cleanup test. The reproducible host helper is `scripts/r66/r66-alma-multinode-podman-removal-failure.sh`; private raw files are under `packaging/build/validation/rc5-r66/alma-multinode-podman-removal-failure/`. Key hashes: injected command log `03f0675abe70b5710031689e983066aa38b359b7ebb55dd74545ef1a12f26936`, failed operation `9eb96684de46e9dafbf4c8996fb92427ae41e4649b934ca495991b7852b855`, retry `1cfaf8b142de5aad12cef2cb13b14c4fb9faf6900f9d03969686cbf33c753e62`, final cleanup `63a8cd4541183fb88ea031726cb6470995ee8f590f6b890f2823d06aea0cd0a4`. |
| `R66-ALMA-MN-BACKUP-RESTORE-RETEST-01` | Exact R66 local PostgreSQL backup, mutation, checksum restore and cleanup on W2 | **PASS for this scenario only** | Provision `op_93fcfb9073f1eb4d`, instance `inst_77ff00da4765cdf7`; backup `bk_2ffb8ddc318afcf7`, operation `op_42a054932f58e28e`, 744 bytes, SHA-256 `1c43ee6ee8af10de0bc70363c218676fcb4ef009b917955fb038ebdf669db120`. Restore while running returned HTTP 409. Pause `op_012fcefa431d1211`, checksum-verified restore `op_287beb3df01dd302`, and resume `op_2e8cb4b8d5f864ee` succeeded; direct SQL recovered the original marker and HTTP returned 200 before and after. Backup deletion and deprovision `op_c76e8b613f92f65f` succeeded; containers, pods, volumes, units and matching files were absent. Restricted evidence: `/var/lib/libvirt/images/admiral-validation/evidence/r66-alma-mn-backup-restore-20261023-1326/result`; manifest SHA-256 `5fe90be362ea9e63be1cca4c4b9cbbfea94beec211b62902a8abac3331f5f4b8`. Host transcript SHA-256 `52e122fc4099d9e15241592245bb69b0a2bd4cea356ee780425aa9b66fd98943`. A harmless harness `chmod` diagnostic preceded the test output; the script then ran to exit 0 and all result-file hashes verified. S3 and volume restore remain NOT TESTED. |

## Reproduction outline

1. Install the Release 66 local repository on a fresh seeded AlmaLinux hub and two workers; use the tracked `scripts/install-worker-audit.sh` helper for each worker.
2. Apply `examples/apps/e2e-whoami.yaml` on the hub.
3. Provision with `--app e2e-whoami --tier small --node r66-alma-w1` and then `--node r66-alma-w2`, each with a unique customer and stable idempotency key. Repeat the W1 request twice concurrently with the same key and compare operation and instance IDs.
4. Insert a marker into each workload PostgreSQL database through rootless Podman. On the hub, schedule a transient systemd timer to start PostgreSQL after 120 seconds, stop PostgreSQL, and sample both HTTP endpoints while capturing Admirald and Fleet journals. Confirm HTTP 503 with `Retry-After: 5`, zero 401/429, timer success, fresh worker heartbeats and unchanged SQL markers.
5. Schedule a shorter automatic database restore, send an authenticated Fleet task-claim request from each worker over `wg-admiral`, and inspect only HTTP status and `Retry-After` headers. Do not print the token.
6. Reboot the hub with `virsh reboot`; without rerunning Ansible, check two configured/runtime peers, fresh handshakes, node health, workload HTTP and database markers.
7. Reboot W1 and verify the systemd workload units, rootless Podman, local database readiness, persisted marker and both workers' API-visible health.
8. Apply the W2-only partition helper, record node and instance availability while isolated, remove the rule, and measure rejoin and endpoint recovery.
9. Apply `fixtures/e2e-failing-db.yaml`, verify provision fails on service readiness, then deprovision and check for resources, user units, data directories and Quadlet residue.
10. Run `scripts/r66/r66-alma-multinode-podman-removal-failure.sh` with the isolated R66 hub/worker SSH keys and host-key files. It uses the existing W2 test workload, records the failed deprovision state and Podman inventory, restores the original executable, retries cleanup and records final inventories.

## Evidence integrity and limitations

Raw files are mode `0600` under the ignored validation directory. SHA-256 values:

| Capture | SHA-256 |
| --- | --- |
| `alma-multinode-hub-install.log` | `5fd8388d4154c8322a6cbb0fc690cc184e530455e9c9459364091b61dd94d52a` |
| `alma-multinode-w1-install-retry.log` | `e1ce5804ecc1279bb505abc2a7f3cc51404c757920526697fc634957b4865e36` |
| `alma-multinode-w2-install.log` | `37c8a48cded6089167a662bfa6a9874a979a1ffd665fa065a7e54720d03f5ea1` |
| `alma-multinode-w1-failed-workload.log` | `be4ac22c623baa3bc2db968b19b7769359ccc2e3ee9513574d6328007d898f17` |
| `alma-multinode-provision-w1.json` | `7cea4cbd619bbb9f2d6bad3f15b7d0d521387f43255ca79401f34c75a4b2936a` |
| `alma-multinode-provision-w2.json` | `5ad82a4e0e848bcc97a96a0b3645a7be5e506da95aae7d8ded833f4ec1e41052` |
| `alma-multinode-hub-postgres-outage.log` | `dc8e5f96d3cdc3d4514e8d17375b4716348313d290b434a79d804e5c9f5889a6` |
| `alma-multinode-hub-postgres-admirald.log` | `c16a30afa8249eb3bd126e72c4d9a8e32c47049f95d3d900addd644bcb4828ce` |
| `alma-multinode-w1-fleet-postgres.log` | `461e79e5c99b6cc2ac1abeed78cc761d2df6f3f3a43354f7ddfca9388a8bbf43` |
| `alma-multinode-w2-fleet-postgres.log` | `4d4d1764fef24740d17ddfa8c57c3bfdf489d9d1fd7bda919c736a55522dde39` |
| `alma-multinode-retry-after-w1.log` and `alma-multinode-retry-after-w2.log` | `77db45338fd6dbce83e13e42dc3ef41509f0cfe518e866f9ade24c6f84d50fd7` each |
| `alma-multinode-hub-reboot-postcheck.log` | `fd8e2286e72d58c0d869e2b9a0419ba60cb84ae7a69821ce561322b80f5df0ab` |
| `alma-multinode-w1-reboot-postcheck.log` | `c79c10682078db5c7cbbac17a66195fb99fd01336f6550a9fe04a7dd3d4c45fc` |
| `alma-multinode-w2-partition.log` | `70aae1aa31ab5333d429c5e23ef5bd7a9f71e00173b2291bd578d3efd1d8ee64` |
| `alma-multinode-w2-instance-offline.log` | `99dcccb99b1601b09ad91636f719a0ae68e4422cd51f6a26e3cce98cc9d3e7e7` |
| `alma-multinode-failing-db-cleanup.json` | `71799c7dd843b32a013fca16444a0b53b35428ef8aa6d2e446dd879cc3e13441` |
| `alma-multinode-failing-db-postcleanup.log` | `f3a9f7a3c7d233ddeabe439facc2db3b7c636adfeed40d5b58cf92295a5f48de` |

The first worker bootstrap attempt used an inaccessible local repository port and is retained separately; its retry on the policy-allowed HTTP/80 repository succeeded. One retry-header harness attempt also had a local quoting error; its automatic restore timer remained armed, and the corrected direct probes above passed. An initial hub-reboot capture omitted `sudo` on the diagnostic `wg` queries; the reboot itself completed and the correctly privileged post-check is recorded separately. These are harness errors, not product findings.

No complete release-matrix cell is credited by this targeted run. The #227, #228 and #237 rows are scoped regression results, not a substitute for full Single-Node or Multi-Node coverage. Single-Node AlmaLinux, CentOS Stream Single-Node and Multi-Node, Rocky Linux 10, and Fedora Rawhide remain to be validated on the exact candidate, along with the outstanding test dimensions in #200.
