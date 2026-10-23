# Findings

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Release 58 is the latest locally built candidate, pinned to root commit `321e968` and the five component SHAs recorded in `evidence/release58-candidate.md`. Its exact local RPM set has partial targeted Single-Node diagnostic evidence on Rocky 10.2, AlmaLinux 10.2 and CentOS Stream 10; no full cell has passed and matrix remains 0/8. One intermittent stale `healthy/available` observation during user-systemd manager restart invalidated R58 for release validation and was tracked in new issue #259 (`needs-work`). Release 58 has not been published or built in COPR, and the Admiral RPM build skipped `%check`. Issue #212 is closed upstream and its installed-binary placeholder rejection passed on all three R58 guests. Issues #227, #228, #246 and #256 remain open pending broader candidate/matrix evidence despite passing named Single-Node regressions. No issue was closed in this validation checkpoint.

Severity follows the audit criteria. Open findings remain open until a fix is revalidated in the affected topologies; a source change or passing component test alone does not close a live-system finding. Historical finding ADM-F-007 / #212 is resolved upstream and is explicitly marked below.

## ADM-F-001 — Repeating provision can create an unintended second instance ([#207](https://github.com/admiral-project/admiral/issues/207))

* **Severity:** MEDIUM.
* **Component:** `admirald` instance API and `admiralctl` provision command.
* **Environment:** Confirmed sequentially on AlmaLinux 10.2, Rocky Linux 10.2, Fedora Rawhide and CentOS Stream 10 x86_64 Single-Node; confirmed concurrently on Fedora Rawhide and CentOS Stream x86_64 Multi-Node. The instance creation path is shared by both topologies.
* **Reproduction:** Apply `examples/apps/e2e-whoami.yaml`; run `admiralctl instances provision --app e2e-whoami --tier small --customer audit_alma_20261021 --wait --quiet --output json` twice with the same arguments, or submit concurrent requests for the same app/customer. Compare returned instance IDs and Podman resources. Fedora Multi-Node requests to one worker both succeeded with separate IDs and six containers. In CentOS Stream Multi-Node, requests for the same app/customer began 22.9 ms apart while targeting separate workers; both succeeded with instance IDs `inst_de21f056551792b1` and `inst_42609b8fb15431a0`. The CentOS Stream Single-Node repeat created `inst_2367aa6459d1a295` with operation `op_4ce681ce8ab3ce84`. All duplicate test instances were deprovisioned and their container, volume and Quadlet state was verified clean.
* **Expected:** An explicit replay of an operation after an ambiguous timeout can return the original operation/result, or require a stable idempotency token that prevents duplicate billable resources.
* **Observed:** Two distinct successful instances were created. The request path generates a new `inst_*` ID; no `Idempotency-Key` contract or replay lookup exists. The CLI invocation is treated as a new request each time.
* **Evidence:** `evidence/alma-single-execution.md` test `ALMA-SN-005`; `evidence/fedora-multi-concurrent-provision.md`; `evidence/centos-single-execution.md` test `CS-SN-005`; and direct cross-worker reproduction `evidence/centos-multi-execution.md`. Restricted raw logs are ignored and mode `0600`; no credentials are committed.
* **Root cause:** Confirmed design gap: provision requests have no caller-stable idempotency identity. This is not evidence that every repeated invocation is accidental; it means ambiguous client retries cannot be distinguished from intentional additional instances.
* **Recommendation:** Add a documented idempotency token/replay contract for provision requests and persist its terminal response. Keep intentional additional instances possible with a new token.
* **Regression test:** Send the same token/body concurrently and after a simulated client timeout; assert one instance, one capacity reservation, one task side effect and the same returned operation. Repeat with a new token and assert a second intentional instance is allowed.

## ADM-F-002 — Instance API health remains last-known healthy while its worker is offline ([#208](https://github.com/admiral-project/admiral/issues/208))

* **Severity:** MEDIUM.
* **Component:** `admirald` node health monitor and instance status API/UI consumers.
* **Environment:** Confirmed on AlmaLinux 10.2, Rocky Linux 10.2 and CentOS Stream 10 x86_64 three-node Multi-Node labs. AlmaLinux and CentOS used whole-VM suspension; Rocky also used a hub ingress packet filter.
* **Reproduction:** Provision an instance on a worker. Suspend it with `virsh suspend <worker-domain>` or, on the isolated Rocky lab hub, drop packets with `nft add rule inet admiral_audit_partition input iifname enp2s0 ip saddr 10.77.0.11 drop`. Wait for the hub to mark it offline, then query `admiralctl nodes list` and `admiralctl instances list/show` before restoring traffic or resuming.
* **Expected:** Consumers can distinguish a currently available/healthy instance from the last state observed before its worker became unreachable.
* **Observed:** In AlmaLinux at `13:22:57Z`, Rocky during a real packet filter, and CentOS Stream at `16:43:47Z`, the node became `offline/degraded` and unavailable for provisioning while the assigned instance still reported `technical_status=running` and `health_status=healthy`. The health timestamp predated each outage. CentOS was suspended at `16:41:59Z`; the stale instance state persisted after the node transition and until worker recovery. No effective degraded/unavailable instance state is exposed.
* **Evidence:** `evidence/alma-multi-execution.md` records the Alma VM pause/rejoin; `evidence/rocky-multi-partition.md` records the actual packet drop and recovery; `evidence/centos-multi-execution.md` records the CentOS suspension, stale status, rejoin and cleanup. Restricted raw logs are retained locally with hashes in those evidence notes.
* **Root cause:** Confirmed state propagation gap: the offline monitor updates the node record; it does not change or annotate instances assigned to that node.
* **Recommendation:** Expose an effective instance availability/health state derived from node reachability while preserving the last runtime observation as a separate field. Restore current state after heartbeat and health checks return.
* **Regression test:** In an integration environment, provision on one worker, remove worker heartbeats beyond the threshold, and assert its instances are presented as unavailable/degraded with a last-known timestamp; restore the worker and verify the same instances converge without duplication or migration claims.

## ADM-F-003 — Reachable Go HTTP/2 denial-of-service advisories in the control plane build ([#209](https://github.com/admiral-project/admiral/issues/209))

**Release 45 historical status:** all three built Go binaries reported Go 1.26.10, and `admirald` reported `golang.org/x/text v0.41.0`; the current `govulncheck` scan and runtime regression were not run. Release 45 was invalidated by #229. Release 46 package inspection, a current scan and runtime regression remain pending; keep #209 open.

* **Severity:** HIGH.
* **Component:** `admirald` control-plane HTTP server; the same Go 1.26.7 standard library is present in `admiral-fleet` and `admiralctl` candidate binaries.
* **Environment:** Multi-Node hub confirmed; Single-Node network reachability is not established by this test.
* **Reproduction:** Install the Release 42 candidate. Run `govulncheck v1.9.0` in `admirald`; it reports 11 reachable advisories, including `GO-2026-6617` and `GO-2026-6603`. Verify installed `/usr/bin/admirald` build metadata with `go version -m`: Go `1.26.7`, source VCS revision `748b703662eafdaf3919bad28787d0264f06bf16`. From an enrolled worker, run `curl --http2 -k -sS -o /dev/null -w 'http_version=%{http_version} status=%{http_code}
' https://10.99.0.1:8080/api/v1/status`.
* **Expected:** The candidate uses patched standard-library and direct-module versions, and unauthenticated peer traffic cannot reach a known vulnerable HTTP/2 parser.
* **Observed:** Scanner traces identify 10 reachable Go standard-library advisories (fixed in Go 1.26.9 or 1.26.10) and one reachable `golang.org/x/text@v0.40.0` advisory (fixed in v0.41.0). The runtime request negotiated HTTP/2 and reached the application 401 handler from a worker peer. `GO-2026-6617` documents a malicious HTTP/2 client causing server crash via concurrent HPACK encoder updates; the tested candidate is below the fixed Go version. The CVE-triggering frame sequence was not sent and an actual Admirald crash was not induced.
* **Evidence:** `evidence/go-dependency-scan.md`; raw scanner logs remain ignored and mode `0600`. Primary advisory reports: [GO-2026-6617](https://pkg.go.dev/vuln/GO-2026-6617), [GO-2026-6603](https://pkg.go.dev/vuln/GO-2026-6603), [GO-2026-6629](https://pkg.go.dev/vuln/GO-2026-6629), [GO-2026-6809](https://pkg.go.dev/vuln/GO-2026-6809).
* **Root cause:** Confirmed stale build toolchain (`go1.26.7`) and direct dependency (`x/text v0.40.0`) in the candidate. Runtime exposure to the HTTP/2 listener is confirmed from the Multi-Node WireGuard peer network; application 401 occurs after TLS/HTTP/2 parsing.
* **Recommendation:** Rebuild with a supported patched Go toolchain at least `1.26.10` and update `golang.org/x/text` to at least `v0.41.0`; scan all Go binaries again and increment `Release` for all six RPMs. Until then, treat the Multi-Node control plane as vulnerable to denial of service from an enrolled/compromised worker. The audit did not apply a product fix.
* **Regression test:** Assert deployed build metadata reports the patched toolchain; run `govulncheck` on all three Go modules and require zero reachable findings; exercise the upstream HTTP/2 regression test against a disposable candidate hub and verify the service stays available. Re-run placement, outage/rejoin and authorization tests after the RPM rebuild.

## ADM-F-004 — Harbor Markdown renderer preserves percent-encoded JavaScript URLs ([#210](https://github.com/admiral-project/admiral/issues/210))

**Release 45 historical status:** sanitizer fix was included and Harbor's 347-test package check passed; Release 45 was invalidated by #229. Release 46 Harbor RPMs are now installed on fresh Fedora Rawhide and Rocky guests, but the deployed percent-encoded URL regression has not yet been exercised; keep #210 open pending that exact-RPM runtime probe.

* **Severity:** MEDIUM.
* **Component:** `admiral-harbor` app detail template and RPM-provided Mistune dependency.
* **Environment:** Confirmed on Rocky Linux 10.2 x86_64 and Fedora Rawhide x86_64 Release 42 guests; affects the Harbor renderer in either topology when the app catalog is served.
* **Reproduction:** On a target guest, load `/usr/lib/admiral/harbor/app/markdown.py` and call `render_markdown("[probe](javascript%3Aalert%281%29)")`.
* **Expected:** The link is removed or rendered with a safe inert URL.
* **Observed:** Both guests use Mistune 3.2.1 and return `<a href="javascript%3Aalert%281%29">probe</a>`. The `app_detail.html` template renders `app.description_md` through this helper. The browser click was not executed; the admin-only content edit path means an attacker must first cause malicious Markdown to be stored in the catalog.
* **Evidence:** `evidence/target-single-probes.md`, `evidence/python-dependency-scan.md`; [upstream Mistune advisory](https://github.com/lepture/mistune/security/advisories/GHSA-8c25-4j27-2rv3).
* **Root cause:** Confirmed dependency behavior: Mistune 3.2.1 does not decode/check this percent-encoded scheme before emitting the link. HTML escaping does not sanitize URL schemes.
* **Recommendation:** Upgrade the packaged dependency to a release containing Mistune 3.3.0's URL-scheme fix or add a tested allowlist sanitizer before rendering. Rebuild the Harbor RPM and preserve the required coordinated Release increment for all six RPMs.
* **Regression test:** Exercise the deployed helper and the public app-detail route with `[probe](javascript%3Aalert%281%29)`; assert the output has no executable URL. Also test normal HTTPS links and escaped HTML, and verify ordinary customers cannot write the catalog description.

## ADM-F-005 — Hub restart does not restore durable WireGuard peer fragments ([#211](https://github.com/admiral-project/admiral/issues/211))

* **Severity:** HIGH.
* **Component:** Multi-Node hub WireGuard configuration and worker connectivity.
* **Environment:** Reproduced on Rocky Linux 10.2 x86_64, Fedora Rawhide x86_64, AlmaLinux 10.2 x86_64, and CentOS Stream 10 x86_64 Release 42 three-guest topologies after hub/guest shutdown and restart.
* **Reproduction:** Install a hub and two workers. Power-cycle the hub guest. Inspect `/etc/wireguard/wg-admiral.conf`, `wg show wg-admiral peers`, worker Fleet heartbeat logs and `admiralctl nodes list`.
* **Expected:** Durable peers are present after startup and workers return to active/healthy without operator reconstruction of the configuration.
* **Observed:** The hub's main config and runtime interface had zero peers while two mode-0600 peer fragments existed under `/etc/wireguard/peers.d/`. The workers were marked offline/degraded. On AlmaLinux, their existing workload containers were already `Up` locally while the API marked both nodes offline. Manually rebuilding the main config from the fragments and restarting WireGuard restored both handshakes and node health. No app workload was present in the Rocky/Fedora/CentOS restart samples; Alma provides the additional active-local-workload observation.
* **Evidence:** `evidence/rocky-multi-hub-reboot.md`, `evidence/fedora-multi-hub-reboot.md`, `evidence/centos-multi-execution.md`, and `evidence/alma-multi-execution.md`; Alma raw outage/recovery log hashes are `db941e6a655fe9f7f9461fc1047b9b675e812bd7a174b5b8c14be221173e2347` and `5b6151bd740c6aa9611164353cf432661ec7297dfb18c51453e964dd139ccc48`.
* **Root cause:** Confirmed mismatch between onboarding persistence and boot loading. The worker installer uses `wg set` and stores peer fragments; `wg-quick@wg-admiral` reads only `/etc/wireguard/wg-admiral.conf`, and no boot-time reconciler loads the fragments. The general Ansible WireGuard role collects them only when that role is run.
* **Recommendation:** Make the peer-fragment directory part of the boot configuration path or rebuild/reload the hub config as part of worker onboarding and hub boot. Preserve a clear failure signal if durable peers cannot be loaded.
* **Regression test:** Install a fresh three-node cluster, verify both peers/heartbeats, power-cycle the hub, and require two runtime peers plus fresh worker heartbeats and healthy assigned workloads without running Ansible or editing files.

## ADM-F-006 — Failed declared service can still yield successful and healthy instance ([#227](https://github.com/admiral-project/admiral/issues/227))

* **Severity:** HIGH.
* **Component:** `admiral-fleet` provision executor and health reporter; `admirald` instance status.
* **Environment:** Confirmed on CentOS Stream 10 x86_64 Single-Node and Multi-Node, and independently reproduced on an AlmaLinux 10.2 x86_64 Multi-Node worker using the Release 42 candidate. In injected-failure runs, the DB unit failed and was absent while the app remained running and the instance stayed healthy. Source paths are shared by Multi-Node workers.
* **Reproduction:** Apply `fixtures/e2e-failing-db.yaml`, which declares a working public `whoami` service and a PostgreSQL service running `/bin/false`. Provision with `admiralctl instances provision --app e2e-failing-db-audit --tier small --customer <unique-audit-customer> --wait --quiet --output json`. Compare the operation, instance list, rootless pod/container inventory and per-instance user systemd units.
* **Expected:** Provisioning returns a failed or explicitly degraded terminal result if a declared required service cannot start; instance health remains non-healthy until every required service is ready.
* **Observed:** On Release 42, Single-Node operation `op_da461edb27124112` returned `succeeded` at `15:21:32Z`; instance `inst_faeab2b3907b4c5f` reported running/healthy at `15:22:15Z` while its DB unit had failed and no PostgreSQL container existed. In CentOS Multi-Node, operation `op_b72dc14ab054552a` succeeded on worker 2 at `16:25:19.750Z`; instance `inst_8be56687bf0356e4` reported running/healthy at `16:25:24Z` while its DB unit was failed with exit status 1 and no DB container existed. On AlmaLinux Multi-Node, operation `op_fe3466ba3ea600f1` succeeded on worker2; for more than three minutes, instance `inst_99638db42b29ac56` stayed running/healthy while its DB unit was failed with exit status 1 after five restarts and no DB container existed. In all cases app/infra remained up. On Release 46 Fedora Single-Node, the same failure fixture produced failed operation `op_583b233f733b8794` and `technical_status=failed` while the DB container was absent and app/infra remained up; this is a passing targeted #227 regression for that mode only. Test instances were deprovisioned and matching resources were removed.
* **Evidence:** `evidence/centos-single-execution.md` test `CS-SN-006`; direct Multi-Node runs `evidence/centos-multi-execution.md` and `evidence/alma-multi-execution.md` test `ALMA-MN-008`; current Release 46 Fedora Single-Node result and restricted log hashes in `evidence/release46-initial-single-node-execution.md` and `evidence/release46-single-probe-log-sha256.txt`; deterministic fixture `fixtures/e2e-failing-db.yaml`; restricted raw Multi-Node log hashes `cafbc88dbb608323d8c4bcb5d37985e4d13fad14caf1ee45d6cfb6d4d0279f9d` (CentOS) and `1968c8ad672eadafd3737d203aa9e8f1cc4a750cf8f793935b7e56188f3a9992` (Alma), and Single-Node hashes in `evidence/centos-single-log-sha256.txt`.
* **Root cause:** Confirmed in code and runtime. `executor_provision.go` starts the generated pod unit and checks published service ports; a database without a published port or setup dependency has no equivalent readiness gate. `agent/health.go` marks an instance healthy based on pod status `Running` without checking declared service unit/container states.
* **Recommendation:** Gate successful provisioning on readiness of every required declared service and derive health from each required service, reporting actionable partial/failure state when one does not start.
* **Regression test:** Use the fixture above; require provision to fail/degrade and the instance never to report healthy while the database unit/container is failed or absent. Correct the command and verify recovery, then repeat on Single-Node and Multi-Node workers.

## ADM-F-007 — Production config accepts shipped placeholder secret keys ([#212](https://github.com/admiral-project/admiral/issues/212))

**Historical finding — resolved upstream.** Commit `9afa764` fixed placeholder validation and GitHub issue #212 is closed. The installed Release 58 daemon rejected the shipped placeholder configuration on Rocky, Alma and CentOS with an explicit startup error; raw logs are listed in `evidence/release58-el10-single-node-execution.md`. The original reproduction below is retained as audit history, not as a current R58 failure. Broader validation of every secret-bearing field and all topologies remains part of the security audit.

* **Severity:** HIGH.
* **Component:** `admirald` configuration loader and packaged `admirald.ini` defaults.
* **Environment:** Confirmed by focused config-parser execution against Release 42 source; affects any production/manual setup that leaves a shipped placeholder unchanged. No live cryptographic attack or callback forgery was attempted.
* **Reproduction:** Load a production INI with otherwise valid required fields and readable TLS files while leaving `secrets_key=__REQUIRED__` and `fleet_callback_key=__REQUIRED__`. The test source and command are in `evidence/config-placeholder-probe.md`.
* **Expected:** Production configuration rejects `__REQUIRED__` for every secret-bearing key before the control plane starts.
* **Observed:** The production `load(path)` call returned no error and preserved both literal values. Source review shows `SecretsKey` initializes the AES-GCM secret manager and `FleetCallbackKey` is used as the callback HMAC key. Any installation retaining these defaults therefore shares known key material.
* **Evidence:** `evidence/config-placeholder-probe.md`; source references `admirald/internal/config/config.go` and `packaging/config/admirald.ini`. This is a focused config-loader test, not a full deployed process test.
* **Root cause:** Confirmed validation gap: the required-key rejection loop checks `__REQUIRED__` for six keys, but `secrets_key` and `fleet_callback_key` are checked only for emptiness.
* **Recommendation:** Reject empty and placeholder values for every production secret, including the encryption and callback keys; validate key format/length where the consumer has requirements.
* **Regression test:** Use a table-driven production config test that injects `__REQUIRED__` into each secret-bearing field and expects failure; also verify the shipped default INI cannot start `admirald` until every mandatory secret is replaced.

## ADM-F-008 — Deprovision can report success while Podman resources remain ([#228](https://github.com/admiral-project/admiral/issues/228))

* **Severity:** HIGH.
* **Component:** `admiral-fleet` systemd/Podman deprovision executor and control-plane instance state.
* **Environment:** Reproduced on AlmaLinux 10.2 x86_64, Release 42, in a disposable Multi-Node worker. No production or customer data was involved.
* **Reproduction:** Provision `fixtures/e2e-backup.yaml` on a worker. Temporarily wrap Podman so only `rm`, `pod rm` and `volume rm` calls containing that instance ID return an injected error; delegate every other command to the original binary. Run deprovision and compare the operation result, instance API, rootless Podman inventory, Quadlet files and instance data directory. Reproduction helpers are in `scripts/inject-podman-removal-failure.sh` and `scripts/restore-podman-after-injection.sh`.
* **Expected:** Deprovision returns failure or retryable partial status while any managed pod, container or volume remains; cleanup metadata remains available until the operation can converge.
* **Observed:** Operation `op_92cd8fd2cccfebf4` returned `succeeded` for `inst_a82c243d5af4164b` after nine targeted Podman deletion errors. The infra container, exited pod and PostgreSQL volume remained; Quadlet files and the instance data directory had already been removed. The API showed the instance `stopped`, not `deprovisioned`. Manual Podman cleanup removed the remaining resources; afterward inventories were empty. Existing worker2 workloads remained `Up` and the original Podman binary SHA-256 was restored unchanged.
* **Evidence:** `evidence/alma-multi-execution.md`, test `ALMA-MN-009`; fixture `fixtures/e2e-backup.yaml`; restricted mode-0600 raw log SHA-256 `a2ab920d928769d91639e2ab736175b751b7dfbd2c7644894a8a19dee973a2b3`.
* **Root cause:** Confirmed in `admiral-fleet/internal/executor/executor_deprovision.go`: errors from systemd stop/disable and Podman pod/container/volume removal are logged and ignored. After removing Quadlet files and instance data, the executor unconditionally sets `result.Success = true`.
* **Recommendation:** Aggregate managed-resource cleanup failures into the task result and preserve operation and instance metadata for retries. Only mark an instance deprovisioned after the worker confirms its managed Podman resources are absent.
* **Regression test:** Inject each systemd, pod, container, volume and secret removal failure independently. Require a non-success result while any resource remains; restore the dependency, retry cleanup, then verify zero resources and an instance state of `deprovisioned`. Run in Single-Node and Multi-Node.

## ADM-F-009 — Terminal provision task can replay after deprovision and reboot ([#229](https://github.com/admiral-project/admiral/issues/229))

* **Severity:** HIGH.
* **Component:** `admirald` task-claim/callback handlers and the durable Fleet queue.
* **Environment:** Confirmed on Fedora Rawhide 46 x86_64, Single-Node, exact Release 45 candidate. The task queue and handlers are shared by both topologies; Multi-Node runtime reproduction remains required.
* **Reproduction:** Provision `fixtures/e2e-failing-db.yaml` with its DB command set to `/bin/false`. After its provision operation becomes failed, deprovision the instance and verify that containers, pod, volume, Quadlets and instance data are absent. Reboot the guest and inspect Fleet's claim log, generated files and durable queue row.
* **Expected:** A failed, cancelled, succeeded, missing, or superseded operation task is settled before dispatch. A successfully deprovisioned instance remains absent after worker/host recovery.
* **Observed:** Failed operation `op_4128a116f0708f74` / task `task_23ff82be44eb6dc4` was deprovisioned successfully by `op_32c6c26865d7a4fd`. After reboot Fleet reclaimed the same task, re-rendered Quadlets and recreated partial rootless workload resources. At 22:17:59Z the queue row remained leased at attempt 5/5 despite the terminal operation records. The fixture failure cleaned the partial resources on that attempt; raw evidence was preserved before lab-only queue containment.
* **Evidence:** `evidence/fedora-r45-stale-task-replay.md` records the Release 45 failure. `evidence/release46-initial-single-node-execution.md` records the passing Release 46 Fedora Single-Node reproduction and reboot regression; restricted raw logs and their hashes remain mode 0600 under ignored `packaging/build/validation/rc5-r46/`. No credential values are committed.
* **Root cause:** Confirmed in Release 45 source: `HandleTaskClaim` returned a claimed queue payload without checking operation terminal state, operation/task identity or node assignment. The terminal callback branch returned HTTP success without settling the queue row. A lease retry could therefore execute stale work after an operation had already failed or been deprovisioned.
* **Recommendation:** Validate operation status and identity before returning any task to Fleet; cancel stale queue commands, and settle late callbacks without mutating terminal operation state. This minimum source fix is pushed in `admirald@e2b4fcee8fcd63d3c66b9f659156874d2a1bbb09`; the targeted Single-Node regression passed on Release 46, with Multi-Node runtime evidence still required.
* **Regression test:** On a fresh Release 46 Fedora Rawhide guest, force provision failure, deprovision to zero resources, reboot, then verify the stale task remains cancelled and absent. This Single-Node test passed at attempt 2/5; API claim tests and the same queue-path check in a three-guest Multi-Node environment remain required before closing #229.

## ADM-F-010 — Effective availability can remain stale after host reboot ([#237](https://github.com/admiral-project/admiral/issues/237))

* **Severity:** MEDIUM.
* **Component:** `admirald` instance API availability derivation and consumers of `effective_availability`.
* **Environment:** Reproduced with exact Release 47 RPMs on fresh Fedora Rawhide 46 and Rocky Linux 10.2 x86_64 Single-Node guests. Multi-Node has not been checked on the fixed candidate.
* **Reproduction:** Install R47, provision `examples/apps/e2e-whoami.yaml`, insert a marker in its PostgreSQL database, reboot the disposable guest, and query `admiralctl instances show`, rootless `podman ps -a`, the marker and HTTP endpoint on first SSH reconnect and through recovery.
* **Expected:** `effective_availability` is `unknown` until a workload health report exists, `unavailable` when a fresh report is not healthy, and `unavailable` after the last report becomes stale. The last observed `health_status` and timestamp remain intact. Availability returns only after a fresh healthy report.
* **Observed:** On Fedora and Rocky, the first post-reboot API snapshot reported `running/healthy/available` with a health timestamp 68–71 seconds old, while required app/DB containers were missing or still starting. Fedora then reported stopped while containers had returned and converged healthy after about 63 seconds; Rocky converged after about 34 seconds. SQL markers persisted on both guests and HTTP returned 200 after recovery. These are transient state discrepancies, not terminal failures or data loss.
* **Evidence:** `evidence/release47-invalidated-single-node.md`; restricted raw files are mode 0600 under ignored `packaging/build/validation/rc5-r47/`. Candidate-specific hashes are recorded in that evidence file.
* **Root cause:** Confirmed in `admirald/internal/database/instances.go`: the shared SQL expression derived effective availability only from assigned node status, heartbeat and health; it did not check whether instance health had ever been reported, was currently nonhealthy, or was older than the 30-second Fleet health interval.
* **Recommendation:** Treat no health report as unknown, nonhealthy workload observations as unavailable, and an observation older than two health-check intervals (60 seconds) as stale/unavailable while preserving last-known runtime fields.
* **Regression test:** Cover unknown-before-first-report, stale healthy, fresh stopped/unhealthy, node outage precedence, and fresh healthy recovery without changing placement or the last observation. Reboot a workload guest on the rebuilt candidate and require unavailable/unknown until a fresh healthy report; repeat on a Multi-Node worker.
* **Fix status:** Implemented and pushed as `admirald@d50523f7a75b0a1606c761423de9d1cdc844425e`; focused regression passed 10/10, full Go tests, `go vet` and `go build` passed locally, and GitHub CI is green. R48 contains the fix but was superseded before VM testing; issue remains open until the R49 runtime regression.

## ADM-F-011 — Existing-node bootstrap helper selects a stale RPM release ([#238](https://github.com/admiral-project/admiral/issues/238))

* **Severity:** LOW (validation integrity).
* **Component:** Release-validation audit scripts.
* **Environment:** Root `main`, before coordinated Release 49 preparation.
* **Reproduction:** Run `docs/audits/admiral-production-readiness-2026-10-21/scripts/bootstrap-candidate-node.sh el10 ...` without setting `ADMIRAL_RC_RELEASE`; inspect the selected `rc5-r${release}` repository path and requested package NEVRAs.
* **Expected:** Both Single-Node install and existing-node bootstrap helpers default to the same coordinated Release as all six Admiral RPM specs.
* **Observed:** The Single-Node helper defaulted to 48 while the bootstrap helper defaulted to 46, which would select an old repository and request old package versions. Static inspection caught this before an R48 guest run; no VM was misdirected.
* **Evidence:** `scripts/bootstrap-candidate-node.sh` had a stale literal default. `scripts/test_audit_release_defaults.py` now compares both helper defaults against all six RPM spec `Release` values; the root script suite passed 112 tests locally.
* **Root cause:** Candidate release was duplicated as independent hard-coded values in two helpers, with no synchronization check.
* **Recommendation:** Keep the release defaults aligned and retain the regression check so a coordinated spec bump cannot leave either helper stale.
* **Regression test:** Run the root script test suite and `bash -n` on both helpers; verify default selection points to the active staged candidate. The regression test passed locally in root commit `11c6c6861e81293148d4220c266305d6146375c`, and GitHub CI passed in run 39713868071. Both helpers default to Release 53 in signed package-preparation commit `e149571`; keep #238 open until the exact-candidate helper path is verified in the runtime matrix.

## ADM-F-012 — Ansible roles use deprecated injected fact variables ([#234](https://github.com/admiral-project/admiral/issues/234))

* **Severity:** LOW (future compatibility).
* **Component:** `admiral-common` installation tasks and other Ansible role/playbook fact references.
* **Environment:** Observed during Release 47 install on Fedora Rawhide 46; fixed source is root `be2054559a4835f8860e067345224b9dbe2c705f`. R48 was built from an older root payload pin and was superseded before VM execution.
* **Reproduction:** Run a clean secure Fedora install and observe the `Disable LLMNR on Fedora secure installs` task; before the fix, Ansible warned that `INJECT_FACTS_AS_VARS` and direct `ansible_distribution` access are deprecated. Related direct facts appeared in common, firewall, Fleet, Harbor, SELinux, WireGuard and site playbooks.
* **Expected:** Distribution, version, hostname, FQDN, primary IPv4 and SELinux facts are read from `ansible_facts`; no injected-facts deprecation warning is emitted.
* **Observed:** The installer continued, but direct top-level fact access emitted a compatibility warning and left the playbooks exposed to removal of fact injection.
* **Evidence:** Issue #234 records the R47 warning and restricted raw log. The root diff replaces injected facts across the playbooks/roles. `python3 -m pytest -q scripts/test_*.py` passed 113 tests, both main Ansible playbooks passed `--syntax-check`, the local gathered-facts assertion passed, and root CI passed in run 39714180234.
* **Root cause:** Ansible fact-injection compatibility variables were used instead of keys in the `ansible_facts` mapping.
* **Recommendation:** Keep all role conditions and templates on the explicit fact map.
* **Regression test:** Assert no deprecated top-level fact variable names remain in Ansible sources; syntax-check the installer playbooks; run a clean Fedora and EL10 install from the next package candidate and verify the warning is absent. Source fix and CI are complete; keep #234 open pending exact-RPM install evidence.

## ADM-F-013 — Structured capacity-policy rejection is retried by `admiralctl` ([#240](https://github.com/admiral-project/admiral/issues/240))

* **Severity:** MEDIUM.
* **Component:** `admiralctl` HTTP retry and provision-rejection handling.
* **Environment:** Reproduced with exact Release 49 RPMs on Rocky Linux 10 x86_64 Single-Node during a concurrent capacity test. The shared CLI request path affects both topologies.
* **Reproduction:** Fill the disposable node to its configured capacity, then submit a provision request for another workload. Inspect the structured HTTP 503 response and count resulting operation/task records. In the R49 Rocky probe, one capacity rejection was retried three times.
* **Expected:** A structured `ProvisioningRejectedResponse` with a policy code such as `no_node_available_for_requested_tier` is returned as a terminal policy rejection to the caller and is not retried as a transient server failure.
* **Observed:** `admiralctl` retried the structured HTTP 503 three times, producing four failed operations/tasks for one request and obscuring the policy rejection. No workload or capacity reservation leaked.
* **Evidence:** `TEST_MATRIX.md` row `R49-SN-CAPACITY-REJECTION`, `evidence/release49-exploratory-single-node.md`, and the restricted raw diagnostic `packaging/build/validation/rc5-r49/evidence/rocky-single-concurrency-diagnostic.log` (mode 0600; SHA-256 recorded in `evidence/release49-exploratory-single-node-sha256.txt`).
* **Root cause:** Confirmed in `admiralctl/internal/client/client.go`: generic retry handling treated all HTTP 5xx responses as transient before the provisioning-specific parser could classify a structured capacity-policy rejection.
* **Recommendation:** Detect a structured policy rejection in the shared response path and return it immediately, preserving its code and operation ID; continue retrying unstructured transient server errors.
* **Regression test:** The fix adds `TestProvisionPolicyRejectionIsNotRetried`, asserting one HTTP attempt and preservation of the typed rejection and operation ID. `GOTOOLCHAIN=auto go test ./...`, `go vet ./...`, and `go build ./...` passed locally. Commit `admiralctl@5ed381d7d152e1606e78fafe332587cca09bc989` is pushed and CI run [39724553667](https://github.com/admiral-project/admiralctl/actions/runs/39724553667) is green. Keep #240 open until the capacity rejection is revalidated on the next exact RPM candidate in Single-Node and Multi-Node with one policy operation/task and no leaked capacity/workload resources.

## ADM-F-014 — Local `admiralctl` Go tests need RPM-style dependency staging ([#241](https://github.com/admiral-project/admiral/issues/241))

* **Severity:** LOW (developer/test reproducibility; no observed RPM runtime impact).
* **Component:** `admiralctl` Go module replacement and local test workflow.
* **Environment:** Monorepo checkout where `admiralctl` and `admirald` are sibling submodules.
* **Reproduction:** From the root checkout, run `cd admiralctl && GOTOOLCHAIN=auto go test ./...` or `go mod tidy`. The replacement path `./admirald` does not exist in the ordinary checkout, so Go exits before running tests. The RPM spec creates the expected nested source directory during `%prep`.
* **Expected:** A documented, reproducible local command stages the exact pinned `admirald` source or otherwise sets up the module workspace, then runs the Go checks without manual filesystem changes.
* **Observed:** The first isolated `go test` invocation failed at dependency resolution. A temporary symlink matching the RPM-preparation layout allowed `go mod tidy`, `go test ./...`, `go vet ./...` and `go build ./...` to pass; it was removed and no tracked module files changed.
* **Evidence:** `evidence/unit-test-results.md`, release-fix validation run dated 2026-10-22; `packaging/rpm/admiralctl.spec` `%prep` stages the sibling module explicitly.
* **Root cause:** Confirmed local `replace github.com/admiral-project/admiral/admirald => ./admirald` assumes an RPM-prepared nested directory, while the ordinary submodule checkout keeps `admirald` as a sibling.
* **Recommendation:** Add a safe local staging/test helper or document a repository-level command that mirrors `%prep` and cleans up the staged dependency.
* **Regression test:** On a fresh checkout with no pre-created nested dependency directory, run the documented local workflow and require `go mod tidy`, `go test ./...`, `go vet ./...` and `go build ./...` to pass; verify tracked files remain unchanged after cleanup. This is a LOW tooling follow-up and does not block runtime validation.

## ADM-F-015 — Harbor suite retains dependency deprecation warnings ([#242](https://github.com/admiral-project/admiral/issues/242))

* **Severity:** LOW (maintenance and forward compatibility).
* **Component:** `admiral-harbor` Alembic configuration and SQLAlchemy query calls.
* **Environment:** Local Harbor component suite on the 2026-10-22 release-fix validation run.
* **Reproduction:** Run `python3 -m pytest tests/ -x --tb=short` in `admiral-harbor` and inspect pytest's warning summary.
* **Expected:** Configure Alembic's `path_separator` explicitly and avoid the legacy Flask-SQLAlchemy `Query.get()` method so these deprecations do not accumulate during the suite.
* **Observed:** All 350 tests passed in 202.03 seconds with 307 non-fatal warnings. The warnings include Alembic's legacy `version_locations` splitting behavior and SQLAlchemy's deprecation of `Query.get()`.
* **Evidence:** `evidence/unit-test-results.md`; no test failure or product runtime error was observed.
* **Root cause:** Confirmed older configuration/API usage in Harbor migration and query paths; individual call sites have not yet been narrowed down.
* **Recommendation:** Set the appropriate Alembic `path_separator` and replace legacy query access with equivalent session lookups where semantics permit.
* **Regression test:** Run the full Harbor suite and require zero warnings from these deprecations; run RPM `%check` and a clean migration/app startup to check compatibility. This LOW maintenance issue does not block the current runtime matrix.

## ADM-F-016 — GitHub Actions reports runner and Node runtime migration notices ([#243](https://github.com/admiral-project/admiral/issues/243))

* **Severity:** LOW (CI maintenance; current workflow is green).
* **Component:** `admiralctl` GitHub Actions workflow and runner selection.
* **Environment:** Push CI run 39724553667 for commit `admiralctl@5ed381d7d152e1606e78fafe332587cca09bc989`.
* **Reproduction:** Inspect the completed run's annotations after pushing to `main`.
* **Expected:** The workflow uses action/runtime versions and a runner image with an explicit, tested support window and produces no matching migration warnings.
* **Observed:** CI passed, while GitHub announced Node.js 20 deprecation for `actions/checkout@v4` and `actions/setup-go@v5`, and the upcoming `ubuntu-latest` migration to Ubuntu 26.
* **Evidence:** [GitHub Actions run 39724553667](https://github.com/admiral-project/admiralctl/actions/runs/39724553667); no failed CI step or product defect occurred.
* **Root cause:** Confirmed workflow action majors and runner label rely on GitHub-managed runtime/image transitions.
* **Recommendation:** Review action majors and either select a tested explicit runner image or document a deliberate migration plan; check all configured Admiral workflows for the same notices.
* **Regression test:** Run each affected workflow on the selected runner and confirm its test/security steps pass without the deprecation/migration annotations. This LOW maintenance finding does not block the runtime matrix while CI remains green.

## ADM-F-017 — Fresh audit guests lacked an authenticated first-contact host-key pin ([#239](https://github.com/admiral-project/admiral/issues/239))

* **Severity:** LOW (audit harness integrity; no Admiral runtime impact).
* **Component:** Libvirt audit VM creation and SSH evidence-transfer helpers.
* **Environment:** Fresh Fedora Rawhide and Rocky Linux 10.2 validation guests on the isolated libvirt NAT.
* **Reproduction:** Create a fresh audit guest, then run the SSH/SCP helpers with `StrictHostKeyChecking=yes`. Before the fix, no preexisting `known_hosts` entry existed; manual `ssh-keyscan` enrollment provided local TOFU but did not authenticate the first host key.
* **Expected:** A trust anchor for the guest's SSH host key is generated on the trusted KVM host and placed in `known_hosts` before any SSH connection.
* **Observed:** Release 49 used `ssh-keyscan` over the isolated NAT, then pinned that key for subsequent strict SSH/SCP. This prevented later prompts but did not provide independent first-contact identity proof.
* **Evidence:** Historical R49 note in issue #239; current targeted test and integration results in `evidence/ssh-host-key-bootstrap.md`.
* **Root cause:** The VM creator asked cloud-init to generate the host key inside the guest without exporting its public half over an authenticated out-of-band channel.
* **Recommendation:** Generate the key on the trusted host, provision it through protected cloud-init material, and emit a host-side per-guest `known_hosts` pin. Remove the protected cloud-init artifacts with the guest cleanup helper.
* **Regression test:** Five local tests pass for key correspondence, address pins, file modes, overwrite refusal and the ISO mode-preserving command. A synthetic ISO inspection confirmed `user-data` and `meta-data` remain `0600`. Fresh Fedora Rawhide and Rocky 10.2 guests accepted strict SSH, and their remote SHA-256 fingerprints matched the host pins. The fix is signed root commit `54d4a6b` with green CI [39726030742](https://github.com/admiral-project/admiral/actions/runs/39726030742); repeat on fresh Release 53 matrix guests. The harness integration does not count as an Admiral runtime matrix pass.

## ADM-F-018 — Common RPM payload has no package-local `%check` ([#244](https://github.com/admiral-project/admiral/issues/244))

* **Severity:** LOW (packaging test coverage; no runtime defect observed).
* **Component:** `admiral-common` RPM spec and staged installer/Ansible payload.
* **Environment:** Release 50 RPM build on Rocky Linux 10.2 x86_64.
* **Reproduction:** Build the coordinated six-package set and inspect the raw build log. Five package specs enter `Executing(%check)`; `admiral-common.spec` has no `%check` section.
* **Expected:** The common package's staged shell and Python entry points receive a package-local syntax check, or a documented reason explains why such a check is not applicable and which runtime checks cover them.
* **Observed:** The R50 common RPM built successfully without a package-local check. The root script suite passed separately; no R50 guest or matrix test ran.
* **Evidence:** `evidence/release50-candidate.md`, `evidence/release50-rpm-sha256.txt`, and restricted raw log hash `4d456ca97ac408141d9d680704bff7b72e1d1d9424434db246ae1d8a136f47db`.
* **Root cause:** `packaging/rpm/admiral-common.spec` had no `%check` section.
* **Recommendation:** Run `bash -n` on the four staged shell scripts and compile the five staged Python scripts during `%check`; keep this separate from the full install E2E checks.
* **Regression test:** The check is in signed root commit `012a571f3ffb2f4bfc58eed82c5778a92d07314c`, root CI [39727055542](https://github.com/admiral-project/admiral/actions/runs/39727055542) is green, and the actual Release 51 staged-payload `%check` passed for all four shell and five Python entry points. The issue remains open pending exact-candidate guest installation/matrix verification.

## ADM-F-019 — Effective availability ignores non-serving lifecycle states ([#245](https://github.com/admiral-project/admiral/issues/245))

* **Severity:** MEDIUM.
* **Component:** `admirald` instance availability projection/API.
* **Environment:** Reproduced on the exact Release 51 RPM candidate in a fresh Fedora Rawhide x86_64 Single-Node guest. A Rocky Linux 10.2 guest also installed R51, but the lifecycle repro was observed on Fedora.
* **Reproduction:** Install all six R51 RPMs and provision `examples/apps/e2e-whoami.yaml`. Pause the instance, then query its instance record; subsequently resume/restart, deprovision, and query again. Fedora pause operation `op_179ee1c2dc4dd8e0` succeeded and left `technical_status=stopped` while the API returned `health_status=healthy` and `effective_availability=available`; the test endpoint refused connections. Deprovision operation `op_c7d558ea106d6fc9` succeeded and left `technical_status=deprovisioned`, `commercial_status=cancelled`, and still `health_status=healthy` / `effective_availability=available`, despite no remaining runtime resources.
* **Expected:** Paused, stopping, and deprovisioned workloads must be presented as unavailable with a lifecycle-specific reason, regardless of a recent last-known healthy observation. Preserve that observation separately for diagnosis.
* **Observed:** R51 exposed `available` for workloads that were stopped or no longer deployed. Resume/restart returned to serving behavior; deprovision removed test resources but the API's effective-availability projection remained false-positive.
* **Evidence:** `evidence/release51-initial-lifecycle.md`, including test IDs `R51-FEDORA-SN-LIFECYCLE-001`, operation identifiers, API snapshots, cleanup inventory, and SHA-256 hashes for restricted raw logs. R51 is invalidated by this defect; the targeted probe is not a matrix pass.
* **Root cause:** Confirmed: `effectiveAvailabilityColumns` prioritized a fresh `healthy` report and did not account for lifecycle states such as `stopped`, `paused_for_storage`, `deprovisioning`, or `deprovisioned`.
* **Recommendation:** Derive effective availability from lifecycle state before considering the last runtime health report, and provide lifecycle-specific unavailable reasons without erasing the health observation.
* **Regression test:** Table-driven tests cover stopped, paused, deprovisioning and deprovisioned states, while retaining last-known health. Local tests, vet and build passed; fix pushed as admirald@0baf488 with green CI [39730492772](https://github.com/admiral-project/admirald/actions/runs/39730492772). R52 pause/resume/deprovision probes passed on Fedora and Rocky; complete Single-Node and Multi-Node regressions remain required.

## ADM-F-020 — Resize and reactivation omit persisted service secrets ([#246](https://github.com/admiral-project/admiral/issues/246))

* **Severity:** HIGH.
* **Component:** `admirald` task construction and `admiral-fleet` Quadlet rendering.
* **Environment:** Confirmed with the exact Release 52 RPM candidate on fresh Fedora Rawhide 46 and Rocky Linux 10.2 x86_64 Single-Node guests. Multi-Node runtime coverage remains outstanding.
* **Reproduction:** Apply `fixtures/e2e-resize.yaml`, provision its PostgreSQL-backed workload on the `small` tier, insert a SQL marker, resize small → medium → small, then inspect the DB container and query the marker using its generated credentials. Both resize operations succeeded and the effective cgroup limits changed to 768 MiB and back to 512 MiB. After resize, the DB unit had zero `--secret=` directives, the DB container lacked `POSTGRES_USER` and `POSTGRES_PASSWORD`, and the expected in-container query failed with `FATAL: role "root" does not exist`.
* **Expected:** Resizing or reactivating an instance must preserve each service's persisted secret references so recreated containers continue receiving their configured credentials; existing database data must remain usable.
* **Observed:** The workload's public `whoami` endpoint still returned HTTP 200, masking the DB failure. Reattaching the still-stored Podman secrets to a temporary client read the unchanged marker `persisted` on both guests, isolating the failure to secret injection rather than volume/data loss.
* **Evidence:** `evidence/release52-initial-single-node-execution.md`; raw resize trace hashes `299c0076d8298e79f824a9ed150c04262b0d3e337739908467d4f424ec7a0bd7` (Fedora) and `55bf70b28997c9c40a4804f262bfe5a6489f08dee888b27652618ce9259e9379` (Rocky). Sanitized confirmation hashes: `ee3900d1d72e2df11869717a840c92df9cd618e1cb2930ba8a4a638c2d720ba3` and `8e69d5a1b271c90de8923a8482c627387cff6c4408d05000d0a7f6e9cc68dee6`.
* **Root cause:** Confirmed in `admirald/internal/api/handlers_tasks.go`: `actionRequiresSecrets` and `scopeTaskSecrets` omitted `resize_app`. Static review found the same omission for `reactivate_app`, although only resize has a live reproduction so far. Fleet consequently re-rendered container units without their `Secret=` references.
* **Recommendation:** Include resize and reactivation in secret retrieval/scoping and ensure the generated service units retain the required secret names.
* **Regression test:** Unit tests assert both actions retrieve and scope the full persisted secret map. `admirald@b4b125e` contains the fix and tests; focused/full `go test ./...`, `go vet ./...`, and `go build ./...` passed locally. On exact R53 RPMs, the targeted resize/reactivation and SQL persistence regression passed on fresh Fedora and Rocky Single-Node guests. Repeat it in Multi-Node and finish all required cell scenarios before considering #246 resolved. The issue remains open with `fix-proposed`.

## ADM-F-021 — Audit VM helper reports requested DHCP address when a stale lease wins ([#247](https://github.com/admiral-project/admiral/issues/247))

* **Severity:** LOW (validation harness reliability; not a product defect).
* **Component:** `scripts/create-audit-vm.sh` and libvirt `default` network lease handling.
* **Environment:** Isolated KVM audit host, Release 53 Fedora and Rocky Single-Node guest creation.
* **Reproduction:** Leave a DHCP lease from a removed audit VM active for `.252` or `.253`, then create a new guest with a different MAC while reserving that same address. `virsh net-dhcp-leases default` showed the old MAC still owning those addresses. The new guests first received `.233` and `.232`, while the create helper reported the requested `.252` and `.253`; strict SSH to those requested addresses failed with `No route to host`. At 07:33 UTC, when old leases expired, the new MACs moved to `.252` and `.253` without guest reconfiguration.
* **Expected:** The helper detects an active conflicting lease or verifies the actual guest lease before reporting a usable address, and exits with actionable guidance if the requested address was not assigned.
* **Observed:** The host-key pin was generated for the requested address; strict SSH refused to connect to an unrecognized endpoint. We inspected the actual leases, matched each address to its host-generated guest key and only then continued. RPMs were not transferred during failed attempts. The corrected addresses and evidence are recorded in `evidence/release53-initial-single-node-execution.md`.
* **Root cause:** Confirmed stale dnsmasq lease records persist until expiry even after the previous libvirt guest and reservation are removed. `create-audit-vm.sh` added the new reservation but did not verify the actual guest lease before reporting success.
* **Recommendation:** The local proposed fix waits for the MAC's lease and fails closed with the actual address and safe retry instructions when it differs; strict host-key checking remains enabled.
* **Regression test:** `scripts/test_audit_vm_hostkeys.py` tests expected, conflicting and missing leases, and asserts lease validation occurs before the success message. All 123 root script tests pass locally. The fix is on root `main` at `dd5eca4` and root CI is green in [run 39783285976](https://github.com/admiral-project/admiral/actions/runs/39783285976). The issue remains OPEN with `fix-proposed`, linked to master tracker #200, pending end-to-end validation on future guests. It does not alter Admiral RPM identity.

## ADM-F-022 — Audit reboot helper reconnects before guest reboot completes ([#248](https://github.com/admiral-project/admiral/issues/248))

* **Severity:** LOW (validation harness reliability; not a product defect).
* **Component:** `scripts/r53/r53-host-reboot.sh` and guest reconnection/readiness checks.
* **Environment:** Release 53 Fedora Rawhide and Rocky Linux 10.2 Single-Node libvirt guests.
* **Reproduction:** Start a guest reboot through SSH, then immediately poll SSH availability and run post-boot health checks without first proving the guest boot ID changed. A reconnect can occur before shutdown/reboot has completed and report the pre-reboot state; the earlier helper also ran rootless libvirt commands from a working directory inaccessible to the validator account.
* **Expected:** Record the pre-reboot boot ID, request reboot, wait until the guest presents a different boot ID, then collect post-boot service, workload, SQL and HTTP evidence. Run rootless libvirt commands from a traversable working directory.
* **Observed:** Initial harness attempts either failed in the helper's working directory or began post-reboot checks before the guest had rebooted. These were preserved as harness failures and not counted as Admiral failures. The corrected helper completed actual reboots on Fedora and Rocky; both retained the SQL marker and recovered HTTP 200 after fresh health reports. Fedora converged at poll 6 and Rocky at poll 7.
* **Evidence:** `evidence/release53-initial-single-node-execution.md`; restricted final captures `fedora-host-reboot-bootid.log` (SHA-256 `2c967ce2d123ad59b51d4b703cbdf90bdebc70dfa8082ece3d9e573267f0c965`) and `rocky-host-reboot-bootid.log` (SHA-256 `ff87b3e9fdb900e942a59a7ef3b5f571a93d236be220e95374796781822967da`) remain mode `0600` outside Git.
* **Root cause:** Confirmed in the local helper: SSH reconnect alone was treated as proof of a completed reboot; no changed-boot-ID assertion prevented an early reconnection from being accepted.
* **Recommendation:** Keep the boot-ID transition as a mandatory precondition for every post-reboot probe and preserve the before/after IDs in evidence.
* **Regression test:** Local host-key/reboot-helper tests assert pre-reboot boot-ID capture and a changed ID before post-boot checks. The full root suite passes locally; the fix is on root `main` at `dd5eca4` and root CI is green in [run 39783285976](https://github.com/admiral-project/admiral/actions/runs/39783285976). Issue #248 remains OPEN with `fix-proposed`, linked to master tracker #200, pending end-to-end use across the matrix. This does not alter Admiral RPM identity.

## ADM-F-023 — R53 guest-side scenario runbook omits root CLI context ([#249](https://github.com/admiral-project/admiral/issues/249))

* **Severity:** LOW (audit harness documentation; not a product defect).
* **Component:** `scripts/r53/README.md` and guest-side scenario invocation.
* **Environment:** Fresh Release 53 AlmaLinux 10.2 and CentOS Stream 10 Single-Node guests.
* **Reproduction:** Upload the fixture and run `r53-concurrent-idempotency.sh` as `validator`. `admiralctl` exits before any state change with `no authentication token configured`, because the secure installer stores its admin CLI config under `/root/.config/admiralctl/config.yaml`. Re-run with `sudo -n bash`; all three same-key requests return one operation and one instance, then cleanup succeeds.
* **Expected:** The runbook specifies the required root execution context and gives a token-free command example.
* **Observed:** The initial non-root invocations on both guests failed before `apps apply`; the corrected privileged invocations passed and created no duplicate instances. The full scenario was executed with `sudo -n bash`.
* **Evidence:** `evidence/release53-followup-single-node-execution.md`; restricted failed-invocation SHA-256 values `0d9fe5e5eaa303f0a8d61aab9cea19e77bdc68585fbf262497b70349ff8c56ef` (AlmaLinux) and `eae19ed184518aeffc61a5433f7a14c41e3d26a606ce4b96bfe8ba0d7f9b8386` (CentOS Stream).
* **Root cause:** Confirmed runbook omission; the helper scripts rely on the root CLI profile installed by the secure installer.
* **Recommendation:** Document root invocation, state that tokens must not be passed on the command line, and keep scenario logs mode `0600` until scanned.
* **Regression test:** Reproduce as `validator` to confirm failure occurs before any API mutation; execute the documented `sudo -n bash` command on the remaining R53 matrix cells and confirm expected operation/resource results. The runbook correction is on root `main` at `a7c59c4` with green CI [39787978275](https://github.com/admiral-project/admiral/actions/runs/39787978275). Issue #249 remains OPEN with `fix-proposed`, linked to master tracker #200.

## ADM-F-024 — Multi-Node lab conflates the private underlay and WireGuard overlay ([#250](https://github.com/admiral-project/admiral/issues/250))

* **Severity:** LOW (audit harness documentation; not a product defect).
* **Component:** Audit README and cloud-init VM creation helper.
* **Environment:** Isolated libvirt validation host; R53 Multi-Node setup planning.
* **Reproduction:** `virsh net-dumpxml admiral-validation` shows the private underlay as `10.77.0.0/24`. The audit README instructed operators to place the second guest NIC on `10.99.0.0/24`, which is the WireGuard overlay configured separately by `admiral-install`. The `create-audit-vm.sh` positional `WG_IP` was passed to cloud-init as a static second-NIC address, so following its old name and README could place that NIC outside the connected libvirt subnet.
* **Expected:** Document and enforce distinct address roles: private NIC underlay `10.77.0.0/24`; WireGuard tunnel overlay `10.99.0.0/24` configured with installer `--wireguard-ip`.
* **Observed:** The previous runbook described both as the WireGuard validation network and assigned overlay addresses to the private NIC. No R53 Multi-Node test has run using that incorrect plan; no product runtime result is affected.
* **Evidence:** Current host network XML (`virsh net-dumpxml admiral-validation`); helper code in `scripts/create-audit-vm.sh` and `scripts/prepare-audit-cloud-init.py`; issue #250.
* **Root cause:** Confirmed naming/documentation mismatch: the helper generated a second-NIC underlay address but named the input `WG_IP`; the README then described that argument as a WireGuard address.
* **Recommendation:** Name helper parameters `PRIVATE_IP`/`PRIVATE_MAC`, document the three-node address mapping, and keep the supported installer's overlay addresses separate.
* **Regression test:** Assert the generated private-interface config uses a `10.77.0.x/24` underlay address and does not inject `10.99.0.x` as an interface address; create a fresh three-guest topology and confirm both network interfaces and WireGuard handshakes before issue #250 is considered resolved.

## Additional open source-review findings

The following issues were opened against the same Release 42 source and are part of the production-readiness tracker. Their GitHub descriptions contain the full source locations, exact reproduction steps and acceptance tests. R58 now has an installed-binary placeholder rejection check on three EL10 guests for #212; the remaining entries describe historical source-review reports, not current-candidate runtime results.

| Issue / severity | Component and affected context | Expected vs. observed; evidence and cause | Recommendation and regression evidence required |
| --- | --- | --- | --- |
| [#212](https://github.com/admiral-project/admiral/issues/212) — CLOSED / resolved | `admirald` production config and packaged `admirald.ini` | Historical R42 parser probe accepted placeholders for `secrets_key` and `fleet_callback_key`. The upstream fix (`admirald@9afa764`) rejects the shipped placeholder; the installed R58 daemon exited before startup with an explicit placeholder error on Rocky, Alma and CentOS. Evidence: `evidence/config-placeholder-probe.md` and `evidence/release58-el10-single-node-execution.md`. | The targeted runtime regression passed. Keep full secret-lifecycle coverage in the broader security matrix; no issue state change was made in this validation. |
| [#213](https://github.com/admiral-project/admiral/issues/213) — MEDIUM | Ansible dev-to-secure-single reconvergence | A secure run should leave a CA-signed leaf with the correct SAN. Existing-file guards can skip CSR/signing after a dev-mode self-signed leaf exists. Static evidence: `ansible/roles/admiral_common/tasks/main.yml`, `ansible/site.yml`; no dev-to-single guest transition was run. | Verify issuer and SAN, replace an invalid leaf, then run a dev-to-single regression and confirm every client validates TLS against the internal CA. |
| [#214](https://github.com/admiral-project/admiral/issues/214) — MEDIUM | `ansible/wireguard-peers.yml` operator and CI output | PSKs should never appear in normal, verbose or failed task output. Copy, slurp and fact-building tasks handle peer PSKs without `no_log`. Static evidence: the three task definitions identified in the issue; no verbose/failure capture was run. | Add `no_log: true` to secret-bearing tasks; capture successful `-vvv` and deliberate-failure output and assert the PSK canary is absent. |
| [#215](https://github.com/admiral-project/admiral/issues/215) — MEDIUM | Multi-Node spoke bootstrap followed by `wireguard-peers.yml` | The hub should register each spoke's own public key. The spoke's `admiral.pub` is copied from the controller and can therefore describe the hub; the peer playbook later reads it as the spoke key. Static evidence: `admiral_common`, `admiral_wireguard`, and `ansible/wireguard-peers.yml`; no post-install peer-playbook runtime test was run. | Store the spoke key separately from the hub key and run the peer playbook on a fresh standard cluster; require valid configuration and fresh handshakes without manual edits. |
| [#216](https://github.com/admiral-project/admiral/issues/216) — MEDIUM | Secure install/reboot on hosts whose persistent SELinux config is permissive | SELinux should remain enforcing across reboot. The role uses runtime `setenforce` but does not align `/etc/selinux/config`; the audit's enforcing guests do not exercise this starting state. Static evidence: `ansible/roles/admiral_selinux/tasks/main.yml`. | Persist enforcing mode and assert both runtime and file state; boot a disposable initially-permissive guest and verify it remains enforcing after reboot. |
| [#217](https://github.com/admiral-project/admiral/issues/217) — MEDIUM | Multi-Node WireGuard host forwarding | The secure node profile intends IP forwarding disabled. The role writes sysctls before starting `wg-quick`, whose routed interface may enable forwarding afterward. Static ordering evidence: `ansible/roles/admiral_wireguard/tasks/main.yml`; runtime sysctl state after interface start/reboot has not been captured. | Re-assert forwarding after interface activation, verify IPv4/IPv6 values on hub and spokes, and confirm handshakes still work. |
| [#218](https://github.com/admiral-project/admiral/issues/218) — MEDIUM | Optional `--enable-ssh-tunnel` worker profile | The `admiral` tunnel service should read its private key without exposing it. The role creates a `0600 root:root` key while the unit runs as `User=admiral`; the feature was not enabled in the audited cells. Static evidence: `admiral_ssh_tunnel` tasks and unit template. | Assign the private key to `admiral:admiral` mode `0600`; start the unit as `admiral` and verify connection without relaxing permissions. |
| [#219](https://github.com/admiral-project/admiral/issues/219) — MEDIUM | COPR setup and dev-node-to-secure reconvergence | Repository signature verification should apply before production package use. `dev-node` exempts the GPG-check assertion and its transition path may not re-check it. Static evidence: `admiral_common` repository assertion and `ansible/site.yml`; no tampered/unsigned repository test was run. | Enforce `gpgcheck=1` in all modes or before a secure transition; assert it on a dev-node-to-single guest and test that invalid repository policy fails closed. |
| [#220](https://github.com/admiral-project/admiral/issues/220) — LOW | RPM-created `admiral-apps` service account | The rootless service account should not permit interactive login unless required. `admiral-common.sysusers` assigns `/bin/bash`; no interactive-login probe was run. | Use `/sbin/nologin` if Podman/systemd still work; rebuild the coordinated RPM set and repeat the full rootless workload lifecycle. |
| [#221](https://github.com/admiral-project/admiral/issues/221) — LOW | Harbor confirmation-email URL generation | Email links should use the same effective external URL source as the portal. `_confirmation_url()` reads config directly, while the settings helper gives the database metadata precedence. Static evidence: `admiral-harbor/app/auth.py`, `app/settings.py`; no sent-email integration was run. | Use `get_external_url()` and test when DB metadata differs from config; assert the generated confirmation link uses the effective origin. |
| [#222](https://github.com/admiral-project/admiral/issues/222) — LOW | Harbor-to-Admiral customer-scoped client and admin backup contract | Internal request helpers should require customer scope and the backup detail query contract should be documented. `_headers` and `_request` permit omitted `customer_id`; the backup route requires `instance_id` but its README contract is absent. Static evidence: `admiral_client.py`, `admin.py`, README search; no cross-customer request was run. | Require customer scope in helpers and document `?instance_id=`; add a test that internal calls cannot omit scope and a route-contract regression. |
| [#224](https://github.com/admiral-project/admiral/issues/224) — MEDIUM | Multi-Node using a customized WireGuard subnet | Hub firewall rules should match the configured hub address. Two worker/portal rich rules use literal `10.99.0.1`, so a custom subnet can block expected traffic. Static evidence: `ansible/roles/admiral_wireguard/tasks/main.yml`; no custom-subnet cluster was built. | Use the derived hub IP variable and run a custom-subnet handshake plus Fleet/workload/portal traffic test; verify a second Ansible run is unchanged. |
| [#225](https://github.com/admiral-project/admiral/issues/225) — MEDIUM (functional scope) | Harbor customer support conversation after the bidirectional-support decision in #195 | Staff replies intended for customers should be visible while internal notes remain private. The client builds every conversation entry with `is_internal=False` from customer replies only; staff replies remain in internal notes. Static evidence: `admiral-harbor/app/client.py`, `app/admin.py` and templates; no staff-to-customer portal flow was run. | Add a distinct staff reply path, preserving tenant ownership, escaping, CSRF and internal-note privacy; cover each with integration tests. |

## Documentation / contract discrepancy

Harbor README calls the component an “Admin workspace for operators,” while the project contract describes Harbor as a customer portal and assigns infrastructure administration to Flagship. Harbor source also has admin routes. This is a confirmed scope/documentation discrepancy, not yet a confirmed authorization defect. No severity is assigned pending route-level role/tenant tests.

## Open risks that are not findings yet

* The central database and queue database do not share one cross-database transaction; crash-window behavior needs fault injection.
* Task delivery is at least once. Lease expiry, callback replay and external side-effect deduplication need real interruption tests.
* There is no control-plane HA or automatic worker migration guarantee. These are architectural limits, not unexpected behavior.
* Workload isolation, cross-tenant authorization, memory/disk pressure, network partitions, concurrent update/delete safety, and dependency advisories have not been fully tested.

## ADM-F-025 — Concurrent duplicate provision may be rejected after capacity selection ([#254](https://github.com/admiral-project/admiral/issues/254))

* **Severity:** MEDIUM.
* **Component:** `admirald` provision API.
* **Environment:** Confirmed on Admiral RC5 Release 54, CentOS Stream 10 x86_64, Single-Node, 2 vCPU / 2 GiB.
* **Reproduction:** With capacity sufficient for one more `small` tier, launch three simultaneous `admiralctl instances provision` calls with the same customer, payload and idempotency key. See `scripts/r53/r53-concurrent-idempotency.sh` and the Release 54 evidence file. Request 1 and 3 returned the same successful operation/instance; request 2 returned a different `no_node_available_for_requested_tier` rejection after capacity was reserved.
* **Expected:** Every identical same-key call returns the existing operation and instance, even when the first call consumes remaining capacity.
* **Observed:** A concurrent call took the no-capacity branch and created a separate rejected operation instead of replaying the committed request. No duplicate workload was created, but the idempotency response contract was violated.
* **Evidence:** `evidence/release54-invalidation-concurrent-idempotency.md`, `evidence/release54-centos-concurrent-idempotency.log` (SHA-256 `8fecb47f569018eb9dd0dafe1f55fa213bcc2ae94680a18fbcec142f89e36a64`), and `evidence/release54-centos-concurrent-idempotency-diagnostic.log` (SHA-256 `924509812946e9e1bb9f94c7e730ad0016a9c044a1749b572c9cac4d903ab065`).
* **Root cause:** Confirmed in source: `HandleCustomerApps` checked the idempotency record before node selection, then recorded a capacity rejection without checking whether a concurrent request had committed that key in the meantime.
* **Recommendation:** Recheck and replay the idempotency record before recording a no-capacity rejection.
* **Regression:** The test forces the node unavailable after a successful provision and invokes the no-capacity path, asserting the same response and no new operation. It passes in the full Go suite, vet/build and component CI [39813463149](https://github.com/admiral-project/admirald/actions/runs/39813463149). R55's same-key concurrent probes passed on Fedora and Rocky, but exact-candidate verification is required after the #256 rebuild. The finding and issue remain open.

## ADM-F-026 — Task dispatch can overwrite a terminal operation state ([#255](https://github.com/admiral-project/admiral/issues/255))

* **Severity:** MEDIUM pending live confirmation.
* **Component:** `admirald` task dispatch and Multi-Node migration restore.
* **Environment:** Reproduced as a five-minute timeout in GitHub CI run [39811936913](https://github.com/admiral-project/admirald/actions/runs/39811936913), in `TestRunMigrationCutoverPreservesLogicalInstanceID`; no live worker runtime reproduction yet.
* **Reproduction:** Run `go test ./internal/api -run TestRunMigrationCutoverPreservesLogicalInstanceID -count=1 -timeout 300s` with the mock publisher able to complete a task before the post-publish status update. The original CI run remained in `waitForOp` during restore until package timeout.
* **Expected:** A task that has entered running or terminal state cannot be moved back to `queued`; migration observes restore completion and completes cutover.
* **Observed:** The CI test waited for a restore operation whose terminal status could be overwritten by unconditional `queued` writes after publish. The mock used asynchronous completion and made the issue timing-sensitive.
* **Evidence:** CI run [39811936913](https://github.com/admiral-project/admirald/actions/runs/39811936913), `admirald/internal/api/admin_instances.go`, `admirald/internal/api/handlers_tasks.go`, and deterministic regression in `TestRunMigrationCutoverPreservesLogicalInstanceID`.
* **Root cause:** Confirmed in source: enqueue paths wrote `queued` unconditionally after publishing; `enqueueRestoreTask` repeated task-ID and queued updates. Whether the same ordering occurs with a live Fleet worker remains a hypothesis.
* **Recommendation:** Advance to `queued` only from `pending_dispatch`, remove duplicate post-publish restore writes, and keep an immediate-completion regression.
* **Regression:** Updated migration test completes tasks synchronously before `PublishTask` returns; focused test, full Go suite, vet/build and component CI [39813463149](https://github.com/admiral-project/admirald/actions/runs/39813463149) pass. R55 VM validation remains required on a non-invalidated candidate. Issue stays open.

## ADM-F-027 — Pre-boot runtime health can briefly report available after a fast host reboot ([#256](https://github.com/admiral-project/admiral/issues/256))

* **Severity:** MEDIUM.
* **Component:** `admirald` effective instance availability and Fleet health/heartbeat contract.
* **Environment:** Admiral RC5 Release 55, Fedora Rawhide x86_64 Single-Node, fresh 2026-10-22 seed overlay; same-candidate Rocky Linux 10.2 comparison. Root candidate `d5654ac776617154e2d63cb745d81c8d2ac9ee22`, `admirald@afcf02f094cf7c572cd0e135a280ebb48c0202d5`.
* **Reproduction:** Install exact R55 RPMs, provision a DB-backed workload with a `pg_isready` check and a persisted SQL marker, reboot the Fedora guest, wait for a changed boot ID and SSH reconnection, then compare Admiral's instance availability, rootless Podman container count and PostgreSQL readiness.
* **Expected:** Keep the prior runtime health fields as historical state but report unavailable until Fleet has observed every declared service ready in the node's current Linux boot.
* **Observed:** At `2026-10-22T16:56:12Z`, 45 seconds after the last pre-boot health report, the API returned `running/healthy/available` with only one rootless container running and `pg_isready` false. By `16:56:37Z` a fresh report arrived and the workload recovered. Rocky's same-candidate reboot remained unavailable until all three containers and PostgreSQL were ready; its SQL marker and HTTP probe passed. No data loss was observed.
* **Evidence:** Protected raw logs (mode `0600`): Fedora `fedora-host-reboot.log`, SHA-256 `92e521d6a62e85b365354dd728bfc79f6171d280450d50227f9cbd7f15862e6d`; Rocky `rocky-host-reboot.log`, SHA-256 `28f0fb57bdf487e2a8b72c298792778370276632e6ab9b16b99851baf1dd5b25`. Full record: `evidence/release55-invalidation-reboot-health.md`.
* **Root cause:** Confirmed. Effective availability only marked a health report stale after 60 seconds; local restart did not invalidate the pre-boot observation, so Fedora reconnected before that age threshold.
* **Recommendation:** Bind each Fleet runtime observation to the Linux boot ID reported by its node and require equality with the latest authenticated heartbeat boot ID before deriving `available`, while retaining historical health fields.
* **Regression:** A PostgreSQL-backed test proves an old-boot healthy report becomes unavailable on boot-ID change, retains its health fields/timestamp, and returns available only after a new-boot report. The fix is pushed in the pinned `admirald@9b8f129` and `admiral-fleet@74e8b0f`; local suites, vet/build and component CI pass. R56 fresh-guest reboot probes passed on Fedora Rawhide (available at poll 7) and Rocky Linux 10 (poll 6), with all containers, PostgreSQL readiness, HTTP 200, SQL marker and cleanup verified. This is targeted coverage; remaining OSes, full cells and Multi-Node reboot behavior are still required. Issue #256 remains open with `fix-proposed`.

## ADM-F-028 — EL10 repositories do not provide patched Flask required by Harbor ([#201](https://github.com/admiral-project/admiral/issues/201))

* **Severity:** HIGH — a clean Rocky Linux 10 installation cannot resolve the Harbor RPM's required Flask version from the configured repositories.
* **Component:** RPM dependency packaging and Admiral COPR publication.
* **Environment:** Rocky Linux 10.2 x86_64, BaseOS, AppStream, CRB, Extras, EPEL and Admiral COPR enabled; private R56 candidate repository disabled.
* **Reproduction:** Query available `python3-flask` packages from the configured repositories, then request the Release 56 Admiral packages with the Harbor RPM's `python3-flask >= 3.1.3` requirement.
* **Expected:** Admiral COPR provides the maintained Flask 3.1.3 RPM so DNF can install the candidate without weakening the security floor or depending on a preinstalled seed package.
* **Observed:** EPEL offers `python3-flask-3.1.2-2.el10_2`; Admiral COPR exposes no Flask package. The clean dependency gate fails. The validation seed already had `python3-flask-3.1.3-2.el10` installed, masking this gap during the first R56 package transaction.
* **Evidence:** R56 clean repository query and checksum in `evidence/release56-runtime-log-sha256.txt`; exact candidate RPM requirements and package identity in `evidence/release56-candidate.md`.
* **Root cause:** Confirmed repository publication gap. `packaging/rpm/python-flask.spec` builds 3.1.3 locally, but that helper RPM is not present in the enabled Admiral COPR metadata.
* **Recommendation:** Publish the signed EL10 Flask 3.1.3 helper RPM through the supported Admiral package repository while preserving the Flask security minimum.
* **Regression:** On a fresh Rocky Linux 10 guest with no Flask preinstalled, enable only the expected distribution repos and Admiral COPR, verify DNF metadata/GPG checks, and install all six exact Admiral RPMs. Record Flask's selected NEVRA and the complete transaction. Keep #201 open until reproduced.

## ADM-F-029 — Supported repositories do not provide Harbor's required Mistune version ([#257](https://github.com/admiral-project/admiral/issues/257))

* **Severity:** HIGH — clean Fedora Rawhide and EL10 installations cannot resolve the Harbor RPM's declared Mistune minimum.
* **Component:** Harbor runtime dependency packaging and Admiral COPR publication.
* **Environment:** Fedora Rawhide x86_64 and Rocky Linux 10.2 x86_64 with distribution repos and Admiral COPR enabled; private candidate repository disabled.
* **Reproduction:** Query available `python3-mistune` NEVRAs and attempt a clean installation of the Release 56 Admiral RPMs, where Harbor requires `python3-mistune >= 3.3.0`.
* **Expected:** The configured Admiral repository provides a maintained Mistune release at 3.3.0 or newer for Fedora Rawhide and EL10.
* **Observed:** Fedora offers Mistune 3.2.1 from Rawhide/COPR. Rocky offers 3.1.3 from EPEL and 3.2.1 from COPR. No available package satisfies the RPM requirement. Both seeds already had Mistune 3.4.0 installed, masking the gap during the first R56 package transaction.
* **Evidence:** R56 Fedora and Rocky clean repository queries and checksums in `evidence/release56-runtime-log-sha256.txt`; exact Harbor requirement in the candidate RPM metadata.
* **Root cause:** Confirmed publication gap. The tree contains `packaging/rpm/python-mistune.spec` for 3.4.0 and the local validation repository contains the built RPMs, but the configured public repository metadata does not.
* **Recommendation:** Publish signed Mistune 3.4.0 helper RPMs for Fedora Rawhide and EL10 through the supported Admiral package repository.
* **Regression:** On fresh Fedora Rawhide and EL10 guests without Mistune preinstalled, verify repository metadata/GPG checks and install all six exact Admiral RPMs with the private local repository disabled. Record the selected Mistune NEVRA and complete DNF transaction. Keep #257 open until reproduced.

## ADM-F-030 — User systemd restart can expose stale workload availability ([#259](https://github.com/admiral-project/admiral/issues/259))

* **Severity:** MEDIUM.
* **Component:** `admirald` effective availability and `admiral-fleet` runtime-health polling.
* **Environment:** Admiral RC5 Release 60, Rocky Linux 10.2 x86_64 Single-Node, fresh overlay `adm-r60-rocky-single`. Earlier intermittent observations occurred on Release 58.
* **Reproduction:** Provision the DB-backed `e2e-backup` fixture and write a SQL marker. Restart `user@<admiral-apps-uid>.service`, then poll the user manager PID, pod unit, PostgreSQL readiness, app HTTP, and `admiralctl instances show`. Preserve the exact R58 RPM identity.
* **Expected:** The instance remains unknown/unavailable until post-restart observations confirm that its required pod services are ready.
* **Observed:** On R60, the manager PID had changed at the first sample at `2026-10-22T23:59:20Z`; the pod was `activating`, PostgreSQL container absent and HTTP `000`, while API returned `running/healthy/available`. The system manager journal shows `user@991.service` stopping at `23:59:17.722Z`, deactivating at `23:59:19.811Z`, and restarting at `23:59:20.158Z`. Fleet did not log the PID replacement until `23:59:21.462Z`, after the false sample. By `23:59:26Z`, runtime readiness, HTTP 200 and API health had recovered; the SQL marker persisted and cleanup succeeded. This confirms the timing race rather than a data-loss condition.
* **Evidence:** R60 exact-candidate report `evidence/release60-rocky-single-node-invalidation.md`; restricted mode-0600 R60 logs and hashes are listed there. Earlier R58 reproduction is in `evidence/release58-el10-single-node-execution.md`.
* **Root cause:** Confirmed: the R60 Fleet watcher polled the rootless user-manager PID every two seconds. The manager's approximately 2.4-second stop/restart window overlapped a polling gap; Fleet only invalidated the last healthy observation after the new manager was already running. The Linux boot ID remains unchanged across a user-manager restart, so the old health observation remains eligible. R60's immediate runtime probe after invalidation also risked re-publishing transient state during startup.
* **Recommendation:** Detect manager stop/replacement promptly, invalidate old observations, and defer a new health report until a post-restart reconciliation. Keep the last-known observation diagnostic-only during that interval.
* **Regression:** Fleet main commit `c902a2895c1b12c18f4607b92f13c83515b3da25` reduces PID polling to 500 ms and waits for the next five-second runtime reconciliation after invalidation; unit tests and CI pass. Build a new synchronized six-RPM release and repeat high-frequency manager restart sampling on all four supported OSes. Require no `healthy/available` sample while the pod or a declared service is absent, verify HTTP 200 and SQL marker recovery, and rerun #256 host-reboot checks. R60 is invalidated; #259 remains open pending exact-new-candidate runtime evidence.
