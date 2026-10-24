# RC5 Release 68 AlmaLinux Multi-Node concurrent idempotency

Audit: `ADM-AUDIT-2026-10-21`
Test ID: `R68-ALMA-MN-CONCURRENT-IDEMPOTENCY-01`
Result: **PASS, scoped** for concurrent same-key duplicate prevention and workload cleanup. This is not a complete AlmaLinux Multi-Node cell; matrix status remains **0/8**.

## Candidate and lab

- Candidate: Admiral RC5 Release 68, `0.0.1rc5-68.el10`.
- Root/package source commit: `4077c4ddb9d233682961d36c3570c63e70eb6405`.
- Exact root/component CI, native RPM builds, package NEVRAs and SHA-256 values: [`release68-candidate.md`](release68-candidate.md).
- OS/runtime: AlmaLinux 10.2 x86_64; three real KVM guests (admin/portal hub and two workers), each 2 vCPU/2 GiB RAM; kernel `6.12.0-211.67.1.el10_2.x86_64`; SELinux Enforcing.
- Preflight verified all six hub RPMs and both worker-role RPMs at Release 68 `.el10`; W1 and W2 were registered, active, healthy and available.
- This reused the R68 AlmaLinux guests from the previous placement and node-removal scenarios. W2 had been re-enrolled using the supported secure worker installer; this was not a clean-bootstrap test. No source or RPM payload changed.

## Procedure and observed results

The reproducible helper [`r68-alma-multinode-concurrent-idempotency.py`](../scripts/r68/r68-alma-multinode-concurrent-idempotency.py) staged three SSH clients behind a shared barrier. All sent the same `e2e-whoami` app, tier, customer and idempotency key. The three client starts were recorded within a 9 ms interval (`01:00:42.591Z`, `.594Z`, `.600Z`); the barrier was released only after all three clients reached it.

| Check | Expected | Observed | Result |
|---|---|---|---|
| Candidate and node preflight | Exact candidate on the correct roles; both real workers available | Hub had six and each worker had two `0.0.1rc5-68.el10` packages; both workers were active/healthy/available | PASS |
| Concurrent same-key requests | All callers return the same operation, task and instance; no duplicate customer instances | Three responses all returned operation `op_52d4c9b82de41704`, task `task_bcded9b247b82114`, instance `inst_27c93046aadd07b9`, node `adm-r68-alma-mn-w1`, status `succeeded`. The active customer query returned exactly one instance. | PASS |
| Runtime placement | Only the assigned worker has the instance's expected runtime resources; API health converges and service is reachable | W1 had exactly its infra/app/DB containers, one pod, one DB volume, generated user units/files and endpoint `10.99.0.2:40001`; W2 had no matching resources. The next health sample converged to `running/healthy/available`; hub HTTP returned 200. | PASS, scoped |
| Deprovision and cleanup | No active instance or workload runtime resources remain; cluster recovers | Deprovision succeeded. W1 and W2 had no matching containers, pods, volumes, endpoints, units or files; the remote scratch directory was absent; both workers remained active/healthy/available. | PASS |
| Durable instance record | Deprovisioned history remains distinguishable from an active instance | Customer listing retained one record for this instance with `technical_status=deprovisioned` and `commercial_status=cancelled`; there were no active customer instances. | PASS; retained audit record |

The operation became terminal `succeeded` at `01:00:48.779Z`. The first health snapshot still reported `running/stopped/unavailable` with its last health observation at `01:00:46.566Z`; the next snapshot recorded `running/healthy/available` at `01:00:52.142Z`. No manual intervention was needed. This is consistent with the documented `--wait` contract tracked by [#236](https://github.com/admiral-project/admiral/issues/236): it waits for terminal operation state, not asynchronous runtime health. The test separately waited for health and verified HTTP 200; it does not claim immediate readiness.

The run took 32.13 seconds (`01:00:37.503Z`–`01:01:09.633Z`). The three identical responses were not counted as three successful provisions: they referenced one operation, one task, one instance and one worker resource set.

## Evidence and reproduction

- Reproducer: [`scripts/r68/r68-alma-multinode-concurrent-idempotency.py`](../scripts/r68/r68-alma-multinode-concurrent-idempotency.py); executed against the exact R68 guest packages.
- Private raw output directory: `packaging/build/validation/rc5-r68/alma-mn-concurrent-idempotency/run-20261024T010037Z/` (ignored by Git; directory mode `0700`, files mode `0600`). It contains 56 hashed files: metadata, candidate/OS preflight, three request/response captures, health snapshots, pre/post worker inventories, cleanup, postcheck and driver console.
- Raw manifest SHA-256: `d566c616e1bcb27e6ab4da74c71bdb27cdeff756802cea72478d6c90769357c5`; all listed entries passed `sha256sum -c`.
- The first auxiliary postcheck incorrectly expected the customer history list to become empty after deprovision. Admiral retained the deprovisioned/cancelled audit record. That assertion and its captured output are preserved in `postcheck-assertion-excluded.txt` and `customer-instances-after-cleanup.json`; the corrected check verified no active customer instance, no runtime resources and no leftover remote scratch directory. This harness expectation error is excluded from the product result.
- Reproduction command shape (supply the private lab key, pinned host-key files and an unused private output path):

  ```bash
  python3 scripts/r68/r68-alma-multinode-concurrent-idempotency.py \
    --ssh-key "$SSH_KEY" \
    --hub-known-hosts "$HUB_KNOWN_HOSTS" \
    --w1-known-hosts "$W1_KNOWN_HOSTS" \
    --w2-known-hosts "$W2_KNOWN_HOSTS" \
    --hub-ip "$HUB_UNDERLAY_IP" \
    --w1-ip "$W1_UNDERLAY_IP" \
    --w2-ip "$W2_UNDERLAY_IP" \
    --output "$OUTPUT_DIR"
  ```

## Limits and disposition

This run covers a single three-caller same-key race on AlmaLinux 10.2 Multi-Node. It does not cover requests with conflicting bodies/keys, timeout after commit, cross-worker concurrent update/delete, repeated statistical trials, load/performance, faults during deployment, isolation negatives or the other three Multi-Node OSes. The transient health window is tracked in #236 and recovered without manual action; it is separate from a terminal failed-service result. Issue [#207](https://github.com/admiral-project/admiral/issues/207) is not modified by this report. The complete per-cell checklist in [#200](https://github.com/admiral-project/admiral/issues/200#issuecomment-6374384636) remains unmet, and no production-readiness or HA guarantee is inferred.
