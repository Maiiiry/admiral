# Single-Node report

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Current status: **NOT VALIDATED — R61 is invalidated; matrix 0/8.** Exact local Release 61 RPMs were installed on a fresh Rocky Linux 10.2 Single-Node overlay. The install subset passed, but three API samples reported `running/healthy/available` while `user@991.service` was `deactivating` or `inactive`; issue #259 tracks the failure. R61 results are retained as diagnostics only. No full cell passed. Fleet fix `0c805d6` is pushed with green CI; R62 is awaiting coordinated RPM build and fresh-guest revalidation. Fedora Rawhide, AlmaLinux 10 and CentOS Stream have no R61 guest run; all four Multi-Node cells remain NOT TESTED. Exact candidate identity and raw hashes are in `evidence/release61-rocky-single-node-invalidation.md`.<br>
Full dependency closure, lifecycle, persistence, isolation, recovery, concurrency, resource cleanup and performance checks remain required for all four cells.

## Release 61 targeted Rocky Linux 10.2 evidence — invalidated

On the fresh `adm-r61-rocky-single` overlay, the exact six Release 61 RPMs installed and the secure installer completed with zero failed tasks. The high-frequency user-manager restart probe failed: the API returned `running/healthy/available` three times while the rootless manager was deactivating/inactive. The manager later returned, and the workload recovered, but the false-health assertion aborted before SQL marker persistence verification. Cleanup deprovisioned the instance and left no matching Podman resources. This is a **FAIL** that invalidates R61 under #259; it is targeted diagnostic evidence only, not a matrix pass. Candidate pins, package checksums, event times and raw-evidence hash: `evidence/release61-rocky-single-node-invalidation.md`.

## Release 60 targeted Rocky Linux 10.2 evidence — invalidated

On the fresh `adm-r60-rocky-single` overlay, the exact six Release 60 RPMs installed and the secure installer completed with zero failed tasks. The targeted PostgreSQL service outage test transitioned the API to unavailable after four seconds and recovered with the SQL marker intact. A later rootless `user@991.service` restart exposed `running/healthy/available` while the pod was activating, the DB container was absent and HTTP was `000`; this is a **FAIL** that invalidates R60 under #259. The runtime case is partial single-node diagnostic evidence only, not a matrix pass. Candidate pins, RPM checksums, event times and raw-log hashes: `evidence/release60-rocky-single-node-invalidation.md`.

## Release 56 targeted Single-Node results — partial, not cell passes

All runs below use root candidate `042e578efe0470124f47c905ddf493aa335d56d0` and fresh R56 guest overlays. Raw runtime logs remain mode 0600 on the lab host; their SHA-256 values are in `evidence/release56-runtime-log-sha256.txt`.

| Test ID | OS / topology | Procedure and observed result | Status | Evidence |
|---|---|---|---|---|
| `R56-FEDORA-SN-INSTALL` | Fedora Rawhide x86_64 / Single-Node | Installed the exact six R56 RPMs and ran the secure installer; recap `ok=238 changed=99 unreachable=0 failed=0`, elapsed 685 seconds. The seed already had Flask 3.1.3 and Mistune 3.4.0, so this did not prove clean dependency closure. | PASS (install/setup subset only) | Protected `fedora-install.log`; manifest above |
| `R56-ROCKY-SN-INSTALL` | Rocky Linux 10 x86_64 / Single-Node | Installed the exact six R56 RPMs and ran the secure installer; recap `ok=232 changed=97 unreachable=0 failed=0`, elapsed 682 seconds. The seed already had Flask 3.1.3 and Mistune 3.4.0, so this did not prove clean dependency closure. | PASS (install/setup subset only) | Protected `rocky-install.log`; manifest above |
| `R56-FEDORA-SN-REBOOT` | Fedora Rawhide x86_64 / Single-Node | Confirmed changed boot ID; after reboot, availability returned at poll 7 only after all three containers and PostgreSQL were ready. HTTP 200, SQL marker `r56-reboot-persisted`, and deprovision cleanup passed. | PASS (targeted #256 regression only) | Protected `fedora-reboot.log`; manifest above |
| `R56-ROCKY-SN-REBOOT` | Rocky Linux 10 x86_64 / Single-Node | Confirmed changed boot ID; the service remained unavailable until poll 6, when all three containers and PostgreSQL were ready. HTTP 200, SQL marker `r56-reboot-persisted`, and cleanup passed. | PASS (targeted #256 regression only) | Protected `rocky-reboot.log`; manifest above |
| `R56-FEDORA-DEPS` / `R56-ROCKY-DEPS` | Fedora Rawhide / Rocky Linux 10 x86_64 | Queried configured distribution repositories and Admiral COPR with private candidate repo disabled. Fedora had Flask 3.1.3 but Mistune 3.2.1; Rocky had Flask 3.1.2 and Mistune no newer than 3.2.1. Harbor requires Flask >=3.1.3 and Mistune >=3.3.0. | FAIL (clean dependency gate; #201, #257) | Protected `*-dependency-query.txt`; checksums above |
| `R56-ALMA-SN` / `R56-CENTOS-SN` | AlmaLinux 10 / CentOS Stream 10 x86_64 | No Release 56 guest run yet. | NOT TESTED | — |

The Fedora installer applied 17 OS package actions, including a new kernel; Rocky upgraded `crun`. This is recorded under the existing seed-update follow-up #235. These host updates did not change the Release 56 RPM identities, but the successful installer transaction cannot substitute for the failed clean dependency gate. No Single-Node cell is complete.

## Historical Release 53 exact-candidate probes — partial results

| Test ID | OS / configuration | Observed | Result | Evidence |
| --- | --- | --- | --- | --- |
| `R53-FEDORA-SN-INSTALL` | Fedora Linux 46 Rawhide x86_64, 2 vCPU / 2 GiB | Exact six R53 RPMs; installer recap `ok=238 changed=99 failed=0`; primary services active; rootless Podman and SELinux enforcing | PASS (install subset only) | `evidence/release53-initial-single-node-execution.md` |
| `R53-FEDORA-SN-246` | Same guest | Resize small→medium→small, HTTP 200, 512/768-MiB cgroup limits, SQL marker persisted through resize and reactivation, deprovision clean | PASS (targeted #246 regression only) | Same evidence file |
| `R53-ROCKY-SN-INSTALL` | Rocky Linux 10.2 x86_64, 2 vCPU / 2 GiB | Exact six R53 RPMs; installer recap `ok=232 changed=97 failed=0`; primary services active; rootless Podman and SELinux enforcing | PASS (install subset only) | Same evidence file |
| `R53-ROCKY-SN-246` | Same guest | Resize and reactivation completed; HTTP 200, cgroup limits matched, SQL marker persisted, deprovision clean | PASS (targeted #246 regression only) | Same evidence file |
| `R53-FEDORA-SN-IDEMP` / `R53-ROCKY-SN-IDEMP` | Same guests | Three simultaneous requests with one idempotency key returned one operation and instance each; one runtime set remained; cleanup passed | PASS (same-key provision replay only) | `evidence/release53-initial-single-node-execution.md` |
| `R53-FEDORA-SN-BACKUP` / `R53-ROCKY-SN-BACKUP` | Same guests | Local PostgreSQL marker survived checksum-verified backup/restore; restore while running returned HTTP 409; test backup and instance removed | PASS (local database path only) | Same evidence file |
| `R53-FEDORA-SN-FAILDB` / `R53-ROCKY-SN-FAILDB` | Same guests | Declared DB failure reached terminal failed operation; API reported failed/unhealthy/unavailable; no DB unit/container; cleanup passed | PASS (targeted required-service failure) | Same evidence file |
| `R53-FEDORA-SN-RECOVERY` / `R53-ROCKY-SN-RECOVERY` | Same guests | Container kill recovered through systemd; `admirald` and Fleet SIGKILL recovered; one provision operation remained; HTTP 200; deprovision cleaned runtime | PASS (no active task during daemon kills) | Same evidence file; raw-log hashes in restricted evidence |
| `R53-FEDORA-SN-REBOOT` / `R53-ROCKY-SN-REBOOT` | Same guests | Boot ID changed; services, workload and PostgreSQL recovered; SQL marker and HTTP 200 verified; API stayed unavailable until fresh health reports arrived (Fedora poll 6, Rocky poll 7); cleanup passed | PASS (targeted reboot recovery only; not a full cell) | Same evidence file; boot-ID log hashes recorded there |
| `R53-FEDORA-SN-ISO` / `R53-ROCKY-SN-ISO` | Same guests | Distinct PID/network namespaces, non-privileged containers, `NoNewPrivs=1`, no Podman socket mount and cleanup verified | PARTIAL — direct cross-workload TCP denial not tested because no DB target IP was exposed | Same evidence file |
| `R53-ALMA-SN-*` / `R53-CENTOS-SN-*` | Fresh AlmaLinux 10.2 and CentOS Stream 10 guests | Install, #246 resize/reactivation, same-key concurrent provision, local DB backup/restore, failed-service injection, process recovery and guest reboot passed; isolation sample partial | PASS for named scenarios only; no full cell | `evidence/release53-followup-single-node-execution.md` |

All four OS cells remain incomplete. After real guest reboots, the API on each OS reported unavailable during recovery and returned healthy/available after a fresh health report; SQL marker and HTTP probes then passed. The stale VM DHCP lease and reboot-harness race have fixes on root main in open issues #247 and #248; issue #249 tracks the runbook's root CLI context and is documented locally. Still required: full update/delete and lifecycle coverage, retries after timeout, conflicting update/delete, Podman/systemd daemon failures, pressure tests, comprehensive isolation negatives, clean repository dependency proof, and controlled performance measurement.

## Historical Release 47 diagnostic execution — invalidated, not cell passes

| Scenario | Environment | Observed | Result | Evidence |
| --- | --- | --- | --- | --- |
| Fresh secure install and service health | Fedora Rawhide 46 x86_64, 2 vCPU / 2 GiB, exact R47 RPMs | Installer recap `ok=238 changed=99 failed=0`; all six R47 RPMs present; API online/control plane healthy; no failed system units | PASS (install subset only; candidate invalidated) | `evidence/release47-invalidated-single-node.md` |
| Provision, same-key replay and HTTP | Same Fedora guest | Operation `op_f75f4ee644e1fc89` succeeded in 43.54s; replay returned the same operation/instance; HTTP 200 in 17ms | PASS (targeted subset only; no cleanup check) | Same evidence file; restricted output hashes therein |
| Host reboot with SQL marker | Same Fedora guest | Initial snapshot reported stale `running/healthy/available` while only infra existed; later `stopped` while containers had returned; recovered to healthy at ~63s after first reconnect. Marker persisted and HTTP returned 200. | FAIL — MEDIUM #237; invalidates R47 | Same evidence file and restricted logs |
| Fresh secure install and service health | Rocky Linux 10.2 x86_64, 2 vCPU / 2 GiB, exact R47 RPMs | Installer recap `ok=232 changed=97 failed=0`; all six R47 RPMs present; API online/control plane healthy; pyOpenSSL 25.0.0-1.el10_1 present | PASS (install subset only; candidate invalidated) | `evidence/release47-invalidated-single-node.md` |
| Provision and host reboot with SQL marker | Same Rocky guest | Provision succeeded in 30.06s; first post-reboot snapshot reported stale `running/healthy/available` with infra Up, app Created and DB absent; later all containers/marker returned, HTTP 200 and health converged. | FAIL — MEDIUM #237; invalidates R47 | Same evidence file and restricted logs |

Neither diagnostic run completed deprovision/cleanup, backup/restore, negative isolation, concurrent update/delete, Podman/systemd failure injection, pressure, or the full scenario catalog. R49 must run all relevant checks; no Single-Node cell is counted as passed.

## Historical Release 46 targeted execution — not full cell passes

| Test | Environment | Observed | Result | Evidence |
| --- | --- | --- | --- | --- |
| Failed provision, deprovision and reboot replay regression | Fedora Rawhide 46 x86_64, fresh Release 46 guest | Provision operation failed on the deliberately broken DB service; deprovision succeeded; the queue task was cancelled at attempt 2/5; after host reboot and a 2m46s delayed check, the task remained cancelled and no resources returned | PASS (targeted #229 scenario only; Multi-Node check remains open) | `evidence/release46-initial-single-node-execution.md` |
| Basic workload lifecycle, replay and cleanup | AlmaLinux 10.2 x86_64, fresh Release 46 guest | Installer recap `ok=229 changed=97 failed=0`; provision reached succeeded/running/healthy, loopback HTTP returned 200; repeating the same key returned the same operation and instance; deprovision succeeded and left no containers, volumes, Quadlets or units | PASS (targeted lifecycle only) | `evidence/release46-followup-single-node-execution.md` |
| Basic workload lifecycle, replay and cleanup | CentOS Stream 10 x86_64, fresh Release 46 guest | Installer recap `ok=228 changed=97 failed=0`; provision reached succeeded/running/healthy, loopback HTTP returned 200; repeating the same key returned the same operation and instance; deprovision succeeded and left no containers, volumes, Quadlets or units | PASS (targeted lifecycle only) | `evidence/release46-followup-single-node-execution.md` |
| Basic workload lifecycle, replay and cleanup | Fedora Rawhide 46 x86_64, fresh Release 46 guest | Provision reached succeeded/running/healthy; Podman mapped app TCP/80 to 127.0.0.1:40001 and the effective endpoint returned HTTP 200; replay returned the same operation and instance; deprovision removed all matching runtime resources | PASS (targeted lifecycle only) | `evidence/release46-followup-single-node-execution.md` |

These Release 46 probes do not cover the complete Single-Node scenario catalog; no OS cell is counted as passed. Rocky Linux 10 is included in the active Release 47 matrix; its Release 46 lifecycle probe and EPEL dependency investigation are historical only, and the current validation seed pins the documented pyOpenSSL package. The follow-up probes observed transient `unhealthy`/`technical_status=failed` while the database image/container was still starting on AlmaLinux and CentOS Stream; after startup, both operations reached `succeeded` and the instance became healthy. This is recorded as a cold-start observation, not a failed final provision result. On Fedora, an initial probe to an assumed fixed port 40000 was refused; Podman showed the actual mapping was 40001, which returned HTTP 200. The wrong-port request was a test-target error, not a product failure.

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

Release 58 is the active local candidate. Exact RPMs have been installed on fresh Rocky, Alma and CentOS Single-Node guests. Named scenario results, including reboot, PostgreSQL outage, user-systemd manager recovery, idempotency, resize, local backup/restore and Podman removal error retry, are in `evidence/release58-el10-single-node-execution.md`; these remain partial and no cell passed. Complete all required Single-Node scenarios on each OS, including cross-tenant isolation negatives, concurrent independent operations, external storage where configured, resource/fault coverage and progressive load. Then run every three-guest Multi-Node scenario on Fedora, Rocky, Alma and CentOS before making a release-readiness decision.
