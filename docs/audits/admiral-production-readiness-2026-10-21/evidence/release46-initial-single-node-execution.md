# Release 46 fresh Single-Node execution checkpoint

Audit: `ADM-AUDIT-2026-10-21`<br>
Candidate: six coordinated Release 46 RPMs from root package-preparation commit `7223561646b60d3c24e8bfb257d544a5eb6dea04`; source pins and package hashes are recorded in `release46-candidate.md` and `release46-rpm-sha256.txt`. The queue fix is `admirald@e2b4fcee8fcd63d3c66b9f659156874d2a1bbb09`.<br>
Scope: targeted Single-Node scenarios on fresh x86_64 guests. The Fedora result remains in scope. The Rocky probe below is preserved but no longer counts: Rocky Linux 10 was removed from the matrix by user direction after EPEL dependency resolution failed on Rocky 10.2. The current matrix is 0/6.

## FEDORA-R46-SN-RES-013 — stale task after deprovision and reboot

**Result: PASS for this targeted Fedora Rawhide Single-Node regression.** Multi-Node execution required by issue #229 remains pending; the issue stays open.

- Guest: `adm-r46-fedora-single`, Fedora Rawhide 46 x86_64, 2 vCPU / 2 GiB, fresh overlay from the verified 2026-10-20 updated seed. Candidate repo installed all six `0.0.1rc5-46.el10` RPMs; `getenforce` was `Enforcing`. The clean installer completed at `2026-10-21T22:49:22Z`, with Ansible recap `ok=235 changed=99 failed=0 unreachable=0` and Harbor API probe success.
- Applied `fixtures/e2e-failing-db.yaml`; its required database runs `/bin/false`. Provision used app `e2e-failing-db-audit`, tier `small`, customer `audit_rc46_fedora_20261021`, and idempotency key `audit-r46-fedora-20261021-stale-replay`.
- Provision operation `op_583b233f733b8794`, task `task_c51e614736ba4d7f`, reached `failed` at `22:53:36Z` with the expected DB-readiness error. The instance simultaneously reported `technical_status=failed` while the DB container was absent and app/infra containers remained up, passing the targeted failed-service reporting check for #227 on this Fedora Single-Node scenario. Deprovision operation `op_a1e9ce0ff64c2d17`, task `task_619096fb15bba601`, reached `succeeded` at `22:54:36Z`.
- Before reboot, the durable `fleet_commands` row for the failed provision task was `cancelled`, attempt `2/5`, with reason `operation is terminal: failed`. The instance reported `technical_status=deprovisioned`; rootless Podman had no matching containers, pod, or volumes; no matching user systemd units, Quadlet files, or instance data path remained.
- Reboot changed the boot ID from `6e36acf82f8f496da6659ab08eaffd5e` to `9b03b98c3998476db475fdbaadde8c09`. The post-boot state was captured at `22:57:39Z`, then checked again at `23:00:02Z`, 2m46s after the new boot. At the delayed check, Admirald, Fleet, Flagship and Harbor were active; both operation results and queue states were unchanged; no workload resource had reappeared.

This reproduces the Release 45 failure trigger against Release 46 and shows the stale queue command is cancelled before restart and stays settled after restart. It is a real guest fault/recovery test, not a unit-test inference. It also exercises the #227 failed-service result on Fedora Single-Node. Both findings remain open until their affected Multi-Node paths receive fresh three-guest regressions.

## Excluded probe — Rocky Linux 10 (not a matrix result)

**Result: PASS for the named targeted lifecycle probe before scope exclusion.** This is not a current matrix result or a full Single-Node pass.

- Guest: `adm-r46-rocky-single`, Rocky Linux 10.2 x86_64, 2 vCPU / 2 GiB, fresh overlay from the verified 2026-10-20 updated seed. All six exact Release 46 RPMs were installed. Secure installer completed at `2026-10-21T22:58:41Z`, with recap `ok=229 changed=97 failed=0 unreachable=0`; Harbor API probe succeeded. `admiralctl status` reported the API online and control plane healthy.
- Applied `examples/apps/e2e-whoami.yaml` and provisioned `e2e-whoami` / tier `small` for customer `audit_rc46_rocky_single_20261021`, with idempotency key `audit-r46-rocky-single-whoami-20261021`.
- Provision operation `op_12526fa2d116a6d2`, task `task_e56307249612fe31`, reached `succeeded` at `22:59:58Z`. The API reported the instance `running/available`; rootless Podman showed the infra, app and PostgreSQL containers `Up`, the pod `Running`, and the generated per-instance systemd units active. A request to `http://127.0.0.1:40000/` returned HTTP 200 with the `whoami` response.
- Deprovision operation `op_899998a0220de958`, task `task_2a4fa43cbca5b145`, reached `succeeded`. The instance reported `technical_status=deprovisioned`; subsequent rootless Podman container, volume and instance-unit inventories were empty.

## Limits and raw evidence

The in-scope probes do not cover the other required lifecycle scenarios, repeated or concurrent operations, persistence across workload reboot, backups, isolation negatives, resource exhaustion, Podman/systemd fault injection, performance sampling, or any Multi-Node scenario. No full Release 46 matrix cell has passed; current completion remains **0/6**. The excluded Rocky result is retained as historical evidence only.

Unsanitized install and guest-state logs remain in the ignored local directory `packaging/build/validation/rc5-r46/`, mode `0600`. Their SHA-256 digests are listed in `release46-single-probe-log-sha256.txt`. No credentials or raw logs are committed.
