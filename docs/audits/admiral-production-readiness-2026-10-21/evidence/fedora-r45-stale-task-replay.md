# Fedora Rawhide Release 45 stale-task replay

Audit: `ADM-AUDIT-2026-10-21`<br>
Test ID: `FEDORA-R45-SN-RES-013`<br>
Classification: real end-to-end fault/recovery test<br>
Result: **FAIL — HIGH, issue [#229](https://github.com/admiral-project/admiral/issues/229)**<br>
Candidate: root `0e4e607a124144c0cfa54912c914d74e3139ac0b`, six Release 45 RPMs recorded in `release45-candidate.md`<br>
Guest: Fedora Rawhide 46 x86_64, 2 vCPU / 2 GiB RAM, isolated KVM guest `rc5-r45-fedora-single`<br>
Execution: 2026-10-21 21:57–22:20 UTC

## Procedure and result

1. Provisioned fixture `fixtures/e2e-failing-db.yaml`, whose required DB service executes `/bin/false`. Provision operation `op_4128a116f0708f74` / task `task_23ff82be44eb6dc4` became `failed` at 21:59:56Z with the expected DB readiness error.
2. Deprovisioned the failed instance. Operation `op_32c6c26865d7a4fd` succeeded at 22:00:54Z. The guest inventory then contained no matching containers, pod, volume, Quadlet or instance data directory.
3. Rebooted the Fedora guest. Fleet reclaimed the same provision task after restart and rendered the same instance's Quadlets again. The rootless pod and partial resources reappeared while the recorded provision operation was still `failed` and its deprovision operation was still `succeeded`.
4. The replay again failed readiness and cleaned its partial resources. At 22:17:59Z the durable queue row remained `leased`, attempt 5/5, although both operations remained terminal. The stale row was cancelled directly in the isolated audit database after evidence capture; `admiral-fleet` was stopped and the guest shut down. No production system was touched.

Expected: a terminal operation's task is not dispatched after lease recovery; the deprovisioned workload stays absent.<br>
Observed: a previously failed/deprovisioned operation's task was dispatched again after host restart and recreated resources. This invalidates all Release 45 candidate evidence under the audit's candidate-reset rule. **Release 45 contributes 0/8 cells.**

## Confirmed code path

At the Release 45 source, `HandleTaskClaim` returned a queue claim without verifying that its operation remained non-terminal or that the operation still referenced the claimed task. `HandleFleetCallback` returned success for callbacks against a terminal operation without settling that queue row. Lease recovery could therefore dispatch stale work again. Release 46 adds operation/task/node validation before dispatch and settles late terminal callbacks.

## Restricted raw evidence

Raw evidence is retained locally with mode `0600` under ignored `packaging/build/validation/rc5-r45/`; secret values are not included in this document.

| Artifact | SHA-256 |
| --- | --- |
| `fedora-r45-single-replayed-failure-task-events.txt` | `b6c046bff29a6a310e0ece80eacc11e33ad0c76568b130d2ec2f1f54ad2ec6b3` |
| `fedora-r45-single-replay-final-evidence.txt` | `0b337296aeb9075d4cc75a8a9ef2c35e6703f34de4de72fed744ed4c4cd1af10` |
| `fedora-r45-single-replayed-failure-state.txt` | `2a6b5f559defa43e1cd25a7ef0fe62363b6b1e126f4986e40ab219e76edf628f` |
| `fedora-r45-single-stale-task-lab-containment.txt` | `5ebf78d6e600728bea7b539c09ee5ac3239d7b05cc7883889b684a62bbafff7c` |

## Recommended regression

On a fresh Release 46 Fedora Rawhide guest, force provision failure, confirm deprovision leaves zero resources, reboot or restart Fleet, and verify the old task is cancelled before Fleet receives it. Confirm its queue status remains terminal, the instance remains absent, and a distinct explicit retry creates only the new operation's intended resources.
