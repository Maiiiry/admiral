# RC5 Release 68 AlmaLinux Multi-Node placement and lifecycle

Audit: `ADM-AUDIT-2026-10-21`
Test ID: `R68-ALMA-MN-PLACEMENT-01`
Result: **PASS, scoped**. This result does not complete the AlmaLinux Multi-Node cell; matrix status remains **0/8**.

## Candidate and lab

- Candidate: Admiral RC5 Release 68, `0.0.1rc5-68.el10`.
- Root/package source commit: `4077c4ddb9d233682961d36c3570c63e70eb6405`.
- Selected component SHAs, native build evidence, exact RPM NEVRAs and RPM SHA-256 values: [`release68-candidate.md`](release68-candidate.md).
- Runtime: AlmaLinux 10.2 x86_64, three real isolated KVM guests — admin/portal hub and workers W1/W2 — each with 2 vCPU and 2 GiB RAM. Kernel `6.12.0-211.67.1.el10_2.x86_64`; SELinux Enforcing.
- Hub contained all six exact Release 68 `.el10` RPMs. Each worker contained exact Release 68 `admiral-common` and `admiral-fleet` `.el10` RPMs. Both workers were registered, active, healthy and available before and after the test.
- This reused the R68 AlmaLinux guests from the preceding node-removal regression. W2 had been securely re-enrolled with the supported worker installer after that test; this run validates workload placement on the restored cluster, not clean bootstrap.
- No source or RPM payload changed during the run. The fixture in the checked-out tree is unchanged from package-source commit `4077c4d`.

## Procedure and observed results

The helper [`r68-alma-multinode-placement.sh`](../scripts/r68/r68-alma-multinode-placement.sh) verified package NEVRAs and worker readiness, applied the `e2e-whoami` fixture, then ran the same sequential create/replay/runtime/cleanup scenario with explicit placement on each worker. The replay used the same app, tier, customer, target node and idempotency key as the initial request.

| Check | Expected | Observed | Result |
|---|---|---|---|
| Candidate and topology preflight | Exact six hub RPMs, exact two worker RPMs, two healthy/available real workers | All role-specific packages were `0.0.1rc5-68.el10`; both workers were active/healthy/available | PASS |
| Explicit placement on W1 | Operation succeeds on requested W1; replay returns same operation/instance; runtime becomes healthy; local DB marker and hub-to-workload HTTP succeed | Operation `op_336686b1f4fa5248`, instance `inst_d2deaf385220dba2`, W1 `adm-r68-alma-mn-w1`; replay returned the same IDs; health converged on poll 1; PostgreSQL accepted and returned marker `r68-alma-inst_d2deaf385220dba2`; endpoint `10.99.0.2:40000` returned HTTP 200 | PASS, scoped |
| W1 deprovision and cleanup | Operation succeeds and no matching containers, pods, volumes, units or files remain | Deprovision `op_511b4db4768878a5` succeeded; all five resource inventories were empty | PASS |
| Explicit placement on W2 | Operation succeeds on requested W2; replay returns same operation/instance; runtime becomes healthy; local DB marker and hub-to-workload HTTP succeed | Operation `op_b80f5b84c14ed297`, instance `inst_58ddc5c1e441ff88`, W2 `adm-r68-alma-mn-w2`; replay returned the same IDs; health converged on poll 2; PostgreSQL accepted and returned marker `r68-alma-inst_58ddc5c1e441ff88`; endpoint `10.99.0.3:40001` returned HTTP 200 | PASS, scoped |
| W2 deprovision and cleanup | Operation succeeds and no matching containers, pods, volumes, units or files remain | Deprovision `op_e6b62ef09249d75f` succeeded; all five resource inventories were empty | PASS |
| Cluster postcheck | Both workers remain registered, healthy and schedulable | W1 and W2 remained active/healthy/available; uploaded fixture was removed | PASS |

The scenario ran from `2026-10-24T00:53:47Z` to `2026-10-24T00:55:09Z` (82 seconds). All node-level records identify AlmaLinux 10.2 x86_64 and the expected `.el10` candidate. The helper exited 0 and its raw manifest passed `sha256sum -c`.

## Evidence and reproduction

- Reproducer: [`scripts/r68/r68-alma-multinode-placement.sh`](../scripts/r68/r68-alma-multinode-placement.sh); syntax checked with `bash -n` and executed for this result.
- Private raw output directory: `packaging/build/validation/rc5-r68/alma-mn-placement/run-20261024T005347Z/` (ignored by Git; directory and files mode `0700`/`0600`). It contains 29 hashed files, including pre/post node inventory, exact installed NEVRAs, operation/replay JSON, SQL/HTTP observations, cleanup inventories, the complete driver output and an excluded SSH-auth preflight attempt.
- Raw manifest SHA-256: `a10ab564d84195e37bda077c7e768f59f97a8af08c2e6aa20f2a55f6be5c2bd6`; all 29 entries passed `sha256sum -c`.
- An initial SSH access attempt used an unrelated builder key and was denied before remote command execution. It made no guest change, is retained in `preflight-auth-denial-excluded.txt`, and is excluded from the product result. The actual test used the lab validator key and per-guest pinned host keys.
- Reproduction command shape (supply the private lab key, pinned host-key files and a new empty private output directory):

  ```bash
  scripts/r68/r68-alma-multinode-placement.sh \
    "$SSH_KEY" "$HUB_KNOWN_HOSTS" "$W1_KNOWN_HOSTS" "$W2_KNOWN_HOSTS" \
    "$HUB_UNDERLAY_IP" "$W1_UNDERLAY_IP" "$W2_UNDERLAY_IP" "$OUTPUT_DIR"
  ```

## Limits and disposition

This test demonstrates sequential explicit placement on both workers, same-key replay behavior, a PostgreSQL marker operation, HTTP reachability from the hub, and cleanup for this exact candidate and OS. The replay requests were sequential; this is **not** a concurrent race test. It does not cover timeout-after-commit, conflicting requests, restart or partition during a task, worker loss/rejoin, cross-workload isolation, S3/volume backup, load, latency or resource pressure. The separate scoped #267 removal/re-enrollment result is documented in [`release68-alma-multinode-node-removal.md`](release68-alma-multinode-node-removal.md).

These scenarios are partial evidence only. The full per-cell gate in [issue #200](https://github.com/admiral-project/admiral/issues/200#issuecomment-6374384636) remains unmet for AlmaLinux Multi-Node. Issue [#267](https://github.com/admiral-project/admiral/issues/267) remains open with `fix-proposed`; this result does not close or relabel it. No high availability, consensus or automatic migration guarantee is inferred.
