# RC5 Release 68 AlmaLinux Multi-Node node-removal regression

Audit: `ADM-AUDIT-2026-10-21`
Test ID: `R68-ALMA-MN-NODE-REMOVE-01`
Result: **PASS, scoped**. This is not a Multi-Node cell PASS; the matrix remains **0/8**.

## Candidate and lab

- Candidate: Admiral RC5 Release 68, `0.0.1rc5-68.el10`.
- Root/package source commit: `4077c4ddb9d233682961d36c3570c63e70eb6405`.
- Selected component SHAs and exact-candidate CI: [Release 68 candidate record](release68-candidate.md).
- OS/topology: AlmaLinux 10.2 x86_64, three isolated KVM guests: admin/portal hub and two workers, each 2 vCPU and 2 GiB RAM.
- All guests were fresh overlays from the updated AlmaLinux seed. The hub had the six exact `.el10` Release 68 packages; each worker had the exact `admiral-common` and `admiral-fleet` Release 68 packages. SELinux was Enforcing, Fleet was active on both workers, and the hub's inventory showed both workers active, healthy and available before the test.
- The W2 installer completed at 2026-10-24 00:36:08 UTC: `ok=155 changed=53 unreachable=0 failed=0`; its temporary bootstrap credential was rejected after installation and the WireGuard handshake was present.
- This run used only the isolated lab. No production system or external service was modified.

## Procedure and observations

The reproducible helper is [`r68-alma-multinode-node-removal.sh`](../scripts/r68/r68-alma-multinode-node-removal.sh). It checks the candidate NEVRAs, applies the `e2e-whoami` fixture, provisions explicitly to W2, and verifies each state transition before cleanup.

| Check | Expected | Observed | Result |
|---|---|---|---|
| Provision to W2 | Terminal success, healthy/available workload and reachable endpoint | Operation `op_fd6382bd9cdafcf5` succeeded; instance `inst_3e2377ccc96262cc` was `running/healthy/available`; endpoint returned HTTP 200 | PASS |
| Authenticated API removal while workload is active | HTTP 409 with active-instance count and `--force` guidance | One DELETE returned HTTP 409: `node has active instances (1 active instance); use --force to override` | PASS |
| CLI removal while workload is active | Nonzero conflict with actionable guidance; no generic/retried HTTP 500 | Exit code 1; same active-instance guidance; no server-error/retry-exhaustion message | PASS |
| State after rejected removal | Worker remains registered and workload stays healthy and reachable | W2 remained registered; instance remained `running/healthy/available`; HTTP remained 200 | PASS |
| Cleanup and idle removal | Deprovision succeeds; no workload resources remain; idle node can be removed | Deprovision operation `op_09612db7e333352e` succeeded; containers, pods, volumes and matching files were absent; CLI removed W2; subsequent node lookup returned HTTP 404 and inventory contained only hub and W1 | PASS |
| Server-side credential rejection after removal | Removed node cannot continue authenticated Fleet task claims | W2's Fleet service remained active, but the hub rejected its later task claim with HTTP 401 `invalid_token` | PASS for rejection; remote Fleet shutdown is outside the documented “remove a registered node” operation |
| Re-enrollment after removal | The operator can re-add the worker through the supported secure installer | Re-ran the supported worker installer on the same AlmaLinux guest and exact R68 candidate. Recap: `ok=146 changed=12 unreachable=0 failed=0`; bootstrap key was revoked; the hub again reported W2 active, healthy and available with a current WireGuard handshake | PASS, scoped |

The operation from initial provision through node removal took 57 seconds (00:36:44–00:37:41 UTC). Re-enrollment ran from 00:40:18–00:44:36 UTC. The 12 changed installer tasks reflect re-registering and converging the removed worker; this was not an installer-idempotency test. No source or RPM changed during these runs. The node-removal script's local output manifest verifies with `sha256sum -c`.

## Evidence and reproduction

- Helper: [`scripts/r68/r68-alma-multinode-node-removal.sh`](../scripts/r68/r68-alma-multinode-node-removal.sh).
- Private raw scenario artifacts are retained mode `0600` under the ignored local directory `packaging/build/validation/rc5-r68/alma-mn-node-removal/run/`. Their `SHA256SUMS` manifest SHA-256 is `67ecaf922ef62bbf8110beac580d56b16d046ebcaf3ceadb5b0eabb3468ce67a`; all 17 listed files passed `sha256sum -c` from that directory.
- Pre-removal three-guest baseline: local file `packaging/build/validation/rc5-r68/alma-mn-cluster-pre-node-removal.log`, SHA-256 `a3c49d479e5387817546e8d3be2dc08a6dd09e67935e3d89dba76e73f42ccc06`.
- W2 installation transcript: local mode-0600 file `packaging/build/validation/rc5-r68/alma-mn-w2-install.log`, SHA-256 `9602d3ce2ab43b4ec2def9e58379c843b659bd71d6d786327824e1bcb3884c15`.
- Re-enrollment transcript: local mode-0600 file `packaging/build/validation/rc5-r68/alma-mn-w2-reenroll-after-removal.log`, SHA-256 `d6181ac8f6be2d1aeb90b74fad890bb434ee37890c9f02b5784a1b67e762ac98`.
- Post-removal/re-enrollment guest baselines are mode-0600 local files: hub SHA-256 `85a0a9265f603fbb0cd67bc907f28eb3f29ebb2b977ede85acd2d0dc1691fc4c`, W1 `949ec1a7b714aa60cc058f43f6b909d695e819f78dbe37c99637476e2eb0aee1`, W2 `0b449027b4096ea154774aaf7d53d63c59e8b402966f37d62ae1cfa2f2a1344f`.
- The raw files contain lab-specific host and operation identifiers and are not copied into this tracked report. The helper records the sanitized test outputs and hashes on a repeat run.

## Finding disposition and limits

This exact-candidate run revalidated the reported #267 behavior on AlmaLinux: an active-instance removal is surfaced as a permanent conflict, not an HTTP 500 or retry loop, and the workload remains available until explicitly deprovisioned. Issue [#267](https://github.com/admiral-project/admiral/issues/267) remains open with its existing `fix-proposed` label; this report does not close or relabel it.

The supported CLI describes node removal as removing a **registered node from the platform**. In this run it did not uninstall or stop Fleet on the remote guest. The hub had removed the node token, and subsequent Fleet task claims were rejected with 401. Operators must separately decommission or reprovision the guest. The behavior is recorded as an operational boundary, not classified as a defect by this test.

This run does not test active task cancellation/compensation, force removal, removal on the other three operating systems, broad concurrency, partition recovery, isolation, resource pressure or performance. AlmaLinux Multi-Node therefore remains incomplete, and the overall matrix remains **0/8**.
