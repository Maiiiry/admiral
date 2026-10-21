# Single-Node report

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Current Release 46 status: **NOT VALIDATED — fresh Single-Node guests for the three in-scope distributions completed installation and targeted probes, but required Single-Node coverage is incomplete.** Current matrix: 0/6.<br>
Current source root: `7223561646b60d3c24e8bfb257d544a5eb6dea04`; component fix: `admirald@e2b4fcee8fcd63d3c66b9f659156874d2a1bbb09`.<br>
Release 45 had scoped Fedora Rawhide and Rocky Linux 10 Single-Node executions but was invalidated by stale task replay after a reboot (`ADM-F-009` / #229). Those results are exact-candidate history only; no Release 45 result validates Release 46. See `evidence/fedora-r45-stale-task-replay.md`.

## Release 46 targeted execution — not full cell passes

| Test | Environment | Observed | Result | Evidence |
| --- | --- | --- | --- | --- |
| Failed provision, deprovision and reboot replay regression | Fedora Rawhide 46 x86_64, fresh Release 46 guest | Provision operation failed on the deliberately broken DB service; deprovision succeeded; the queue task was cancelled at attempt 2/5; after host reboot and a 2m46s delayed check, the task remained cancelled and no resources returned | PASS (targeted #229 scenario only; Multi-Node check remains open) | `evidence/release46-initial-single-node-execution.md` |
| Basic workload lifecycle, replay and cleanup | AlmaLinux 10.2 x86_64, fresh Release 46 guest | Installer recap `ok=229 changed=97 failed=0`; provision reached succeeded/running/healthy, loopback HTTP returned 200; repeating the same key returned the same operation and instance; deprovision succeeded and left no containers, volumes, Quadlets or units | PASS (targeted lifecycle only) | `evidence/release46-followup-single-node-execution.md` |
| Basic workload lifecycle, replay and cleanup | CentOS Stream 10 x86_64, fresh Release 46 guest | Installer recap `ok=228 changed=97 failed=0`; provision reached succeeded/running/healthy, loopback HTTP returned 200; repeating the same key returned the same operation and instance; deprovision succeeded and left no containers, volumes, Quadlets or units | PASS (targeted lifecycle only) | `evidence/release46-followup-single-node-execution.md` |
| Basic workload lifecycle, replay and cleanup | Fedora Rawhide 46 x86_64, fresh Release 46 guest | Provision reached succeeded/running/healthy; Podman mapped app TCP/80 to 127.0.0.1:40001 and the effective endpoint returned HTTP 200; replay returned the same operation and instance; deprovision removed all matching runtime resources | PASS (targeted lifecycle only) | `evidence/release46-followup-single-node-execution.md` |

These probes do not cover the complete Single-Node scenario catalog; no OS cell is counted as passed. The prior Rocky Release 46 lifecycle probe is excluded from the current matrix because the fresh-install EPEL dependency chain could not be resolved on Rocky 10.2 without a compatibility workaround; see `evidence/release46-rocky-excluded-dependency-block.md`. The follow-up probes observed transient `unhealthy`/`technical_status=failed` while the database image/container was still starting on AlmaLinux and CentOS Stream; after startup, both operations reached `succeeded` and the instance became healthy. This is recorded as a cold-start observation, not a failed final provision result. On Fedora, an initial probe to an assumed fixed port 40000 was refused; Podman showed the actual mapping was 40001, which returned HTTP 200. The wrong-port request was a test-target error, not a product failure.

## Release 45 execution record — invalidated, not a cell pass

| Test | Environment | Observed | Result on Release 45 | Evidence |
| --- | --- | --- | --- | --- |
| Clean install and packaged service start | Fedora Rawhide 46, Rocky Linux 10.2 x86_64 | Six exact Release 45 packages installed; installer completed without failed Ansible tasks; core services and CLI health checks passed | PASS (installation subset only; invalidated candidate) | `packaging/build/validation/rc5-r45/*install*` |
| Provision request idempotency | Fedora Rawhide and Rocky Linux 10 Single-Node | Concurrent duplicate submissions and a sequential replay returned the same operation, instance and task IDs | PASS (targeted #207 regression only; invalidated candidate) | `packaging/build/validation/rc5-r45/fedora-r45-single-idempotency-repeat.txt`, `rocky-r45-single-idempotency-repeat.txt` |
| Required DB service failure | Fedora Rawhide and Rocky Linux 10 Single-Node | `/bin/false` fixture reached failed/unhealthy state; cleanup removed generated runtime resources | PASS (targeted #227 regression only; invalidated candidate) | `packaging/build/validation/rc5-r45/fedora-r45-single-failing-db-*`, `rocky-r45-single-failing-db-*` |
| Deprovision after Podman deletion errors | Fedora Rawhide Single-Node | Operation failed with details while resources remained; restoring Podman and retrying removed them | PASS (targeted #228 regression only; invalidated candidate) | `packaging/build/validation/rc5-r45/fedora-r45-single-podman-*` |
| Local database backup and restore | Fedora Rawhide Single-Node | Checksum-verified restore recovered the SQL marker; backup and instance were removed | PASS (local backend subset; object storage not tested; invalidated candidate) | `packaging/build/validation/rc5-r45/fedora-r45-single-backup-*` |
| Failed provision, successful deprovision, then host reboot | Fedora Rawhide Single-Node | Same failed provision task was reclaimed after restart and recreated Quadlets and partial workload resources although the operation was failed and deprovision had succeeded | **FAIL — HIGH `ADM-F-009` / #229** | `evidence/fedora-r45-stale-task-replay.md` |

The Release 45 rows are evidence that these named probes ran. They do not form a complete cell and are all excluded from Release 46 completion under the candidate invalidation rule.

## Environment

The lab host is Rocky Linux 10.2 x86_64, 4 vCPU, 8 GiB RAM, 4 GiB swap and KVM/QEMU available. Guests use isolated libvirt networks and are not production systems. Release 42 RPM hashes are in `evidence/candidate-rpm-sha256.txt`. Rocky Linux 10 and Fedora Rawhide Single-Node lifecycle evidence exists from the earlier RC42 run in ignored `packaging/build/validation/rc5-r42/` logs; it is scoped to those specific runs and does not establish a full production-readiness PASS.

## Executed evidence available before this audit

For Rocky Linux 10 x86_64 and Fedora Rawhide x86_64, the prior RC42 run recorded clean installation, service/package checks, app provisioning, WordPress/MariaDB operation, pause/resume or restart behavior, database and volume backups, restore checks using data markers, and deprovision cleanup. These remain scoped prior-RC subsets, not full audit passes. During this audit AlmaLinux 10.2 and CentOS Stream 10 x86_64 guests completed secure Single-Node installs and scoped runtime tests; neither target cell is complete.

The previous RC tests did not cover the full audit's concurrency, negative tenant isolation, resource exhaustion, or Podman/systemd fault-injection scenarios. CentOS Stream adds a guest reboot and controlled failed-service test, but those do not substitute for the remaining audit scenarios.

## Audit execution status

| Scenario | Expected | Observed | Status | Evidence |
| --- | --- | --- | --- | --- |
| Rocky 10 x86_64 clean install and lifecycle subset | Installed services operate; WordPress/MariaDB can be created, backed up, restored and removed | Prior candidate logs record these steps and data-marker checks | PASS (prior RC subset) | Ignored RC42 logs listed above; SHA of selected logs pending |
| Fedora Rawhide x86_64 clean install and lifecycle subset | Same behavior on Rawhide | Prior candidate logs record the lifecycle and restore checks | PASS (prior RC subset) | Ignored RC42 logs listed above; SHA of selected logs pending |
| Rocky/Fedora x86_64 live service and provision replay probes | Services recover; repeated identical provision does not duplicate a workload; cleanup leaves no resources | Both guests returned healthy after `admirald`/Fleet restarts; each identical provision pair created two IDs; all deprovisioned and rootless containers removed | FAIL (`ADM-F-001`); service checks PASS | `evidence/target-single-probes.md` |
| Rocky/Fedora x86_64 Harbor Markdown output | Rendered app description cannot emit executable script URL | Installed helper emitted a `javascript%3A` href on both systems with Mistune 3.2.1 | FAIL (`ADM-F-004`, medium); no browser execution | `evidence/target-single-probes.md`, `evidence/python-dependency-scan.md` |
| AlmaLinux 10.2 x86_64 | Same secure single-node flow | Fresh install, lifecycle, backup/restore, guest reboot, app kill/restart, API auth negatives and repeat-install checks executed | PARTIAL; scoped scenarios passed, idempotency FAIL | `evidence/alma-single-execution.md`; raw install log remains mode 0600 in ignored local validation directory |
| CentOS Stream 10 x86_64 | Same secure single-node flow | Fresh Release 42 install, app provision, service lifecycle, guest reboot with SQL marker, duplicate provision, and controlled DB process failure | PARTIAL — duplicate request FAIL (`ADM-F-001`); success/healthy state with DB failed FAIL (`ADM-F-006`) | `evidence/centos-single-execution.md` |
| Podman/systemd restart and host reboot | Persistent workload returns to expected state and operation state remains consistent | Forced restart and stop/start passed on CentOS Stream. Guest reboot recovered all services and preserved the SQL marker, but API state converged after 91 seconds. | PARTIAL; convergence lag recorded | `evidence/centos-single-execution.md` |
| Concurrent create/update/delete | No duplicate resources, lost updates or false terminal state | Not executed | NOT TESTED | — |
| Secrets, config and cross-workload isolation | A workload cannot read another's data/secrets or host control socket | No live negative tests yet | NOT TESTED | — |
| Injected Podman/systemd errors during deployment/removal | Operation reports failure or cleanup is verified before success | Not executed by this audit | NOT TESTED | — |

## Observed risks and limits

* The candidate uses a central database and service stack on the same host in Single-Node; that host is a single failure domain.
* Workloads are rootless and use per-instance resources, but cross-workload negative tests remain pending.
* Prior Release 42 requests without an idempotency key created a second successful instance ID on all four distributions; see `ADM-F-001`. In the fresh Release 46 targeted probes, replaying the same explicit idempotency key on AlmaLinux, CentOS Stream and Fedora returned the original operation and instance IDs. This does not yet cover concurrent duplicates or cross-node submissions.
* Cold image startup on the AlmaLinux and CentOS Stream Release 46 guests produced a temporary unhealthy/failed instance observation while the provision operation was still queued and the DB container was not yet available. The operation later succeeded after the DB unit started, and the instance converged to running/healthy. Record this again under slow-pull/load scenarios before deciding whether it needs a product finding; do not treat the intermediate snapshot as the final operation result.
* On Fedora Rawhide, the first HTTP probe used port 40000 by assumption and was refused. Podman's observed mapping was 80/tcp to `127.0.0.1:40001`; the mapped endpoint returned HTTP 200. This was an incorrect probe target, not a candidate failure.
* On Rocky and Fedora, Harbor's installed Markdown renderer preserves a percent-encoded `javascript:` URL in application descriptions; see `ADM-F-004`. The public page renders catalog text, but editing the description is admin-protected and the browser interaction was not executed.
* The first install wrapper returned 127 even though the Ansible play and services completed; a repeat install returned 0. The installer outcome is observable, but the wrapper's first-run exit discrepancy remains unexplained.
* Package-owned fixed directories and modes were correct on this guest; the Ansible role did not create those fixed directories. `admiral-commons` owns that setup, consistent with the packaging requirement.
* AlmaLinux reboot showed an approximately 36-second transient where API state read `stopped` while containers were already running. CentOS Stream reboot recovered the workload and SQL marker, but its first post-boot probe found only the infra container; instance status converged from `stopped` to `healthy` 91 seconds after the stopped report. These are observed intervals from one boot per guest, not timing guarantees.
* A controlled CentOS Stream failure probe returned provision `succeeded` and later instance `healthy` while its declared PostgreSQL unit was failed and no database container existed; see HIGH finding `ADM-F-006` / issue #227. Fleet health observes pod state rather than every declared service.
* A focused config-loader test confirmed production configuration accepts the shipped `__REQUIRED__` values for `secrets_key` and `fleet_callback_key`; see HIGH finding `ADM-F-007` / issue #212. The broader config parser was not tested against every placeholder key or through a full manual install.
* Release-candidate evidence tests functionality; sustained load, concurrent create/update/delete, public ingress, disk/memory exhaustion, and every configured app shape remain untested.

## Required next executions

Continue with complete Single-Node scenario sets on each fresh Release 46 guest, then create a fresh three-guest Multi-Node topology for each distribution. Run concurrent create/update/delete, public ingress where a disposable DNS/TLS target exists, Podman/systemd failure injection, secret and cross-workload isolation negatives, persistence/backup-restore, and a progressive load baseline. Revalidate `ADM-F-001`, `ADM-F-006` and applicable queue regressions after any fix. Record raw command timings and runtime/database state. Do not change the source candidate mid-matrix without rebuilding and resetting affected cells.
