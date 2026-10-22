# Release 54 invalidation: concurrent provision idempotency

- Audit ID: `ADM-AUDIT-2026-10-21`.
- Candidate: Admiral RC5 Release 54, root source `623083f369579ba0031b77ef9537a0aacf904a93`, `admirald` source `ac50b5a6583e16cecba72d5e8d589be49064ecc7`.
- Environment: CentOS Stream 10 x86_64, Single-Node, 2 vCPU / 2 GiB guest.
- Finding: MEDIUM, tracked in open [#254](https://github.com/admiral-project/admiral/issues/254).
- Matrix impact: Release 54 is invalidated. Its probes do not count for the next candidate. Matrix stays **0/8**.

## Reproduction outcome

Three simultaneous provision calls used the same customer, request body, and idempotency key. Requests 1 and 3 returned successful replay identity `op_c11251d21ce726f5` / `inst_9ade70100754dd21`. Request 2 returned a separate `no_node_available_for_requested_tier` rejection, operation `op_4a26a7cc97d8dd6d`, after the first reservation consumed the remaining RAM commitment. The rejection was caused by the same-key request taking the capacity check path without replaying the idempotency record already committed by its concurrent peer. The customer had one workload, so this was a replay-contract failure rather than duplicate workload creation.

Expected: all same-key, same-payload calls return the same operation and instance, regardless of the capacity consumed by the first call.

Observed: one call received a capacity rejection with a different operation ID. The `admirald` handler checked the key before node selection, then went directly to blocked-attempt recording when selection returned no node.

## Evidence

- `release54-centos-concurrent-idempotency.log` — request PIDs and outcomes.
- `release54-centos-concurrent-idempotency-diagnostic.log` — response bodies, customer workload list, and rootless container inventory.
- Original log SHA-256: `8fecb47f569018eb9dd0dafe1f55fa213bcc2ae94680a18fbcec142f89e36a64`.
- Original diagnostic SHA-256: `924509812946e9e1bb9f94c7e730ad0016a9c044a1749b572c9cac4d903ab065`.

## Correction and verification status

The #254 fix was pushed in `admirald` commit `bedcecccb4d001a30da815c5471567a82714a31a`. Component CI run [39811936913](https://github.com/admiral-project/admirald/actions/runs/39811936913) then exposed #255: a migration test can lose a terminal operation state to a post-publish `queued` write. That second issue was fixed in `admirald` commit `afcf02f094cf7c572cd0e135a280ebb48c0202d5`, which also contains #254. Focused regressions, the full Go suite, `go vet ./...` and `go build ./...` pass locally against an isolated PostgreSQL test database. CI run [39813463149](https://github.com/admiral-project/admirald/actions/runs/39813463149) is pending. Release 55 has not yet been built or run in VMs, so neither fix is validated in the release matrix.
