# R67 AlmaLinux 10 Multi-Node concurrent idempotency

Audit ID: `ADM-AUDIT-2026-10-21`

Test ID: `R67-ALMA-MN-CONCURRENT-IDEMPOTENCY`

Result: **PASS for this scoped scenario; not a Multi-Node cell PASS**

## Candidate and environment

- Admiral source commit: `833d15aa4f8e96be30d28dad169b9d06a4d9894d`.
- Candidate: RC5 Release 67, `0.0.1rc5-67.el10`.
- OS: AlmaLinux 10.2 x86_64, three real guests in the isolated libvirt lab.
- Roles: hub `adm-r67-alma-mn-hub` (`192.168.122.187`), W1 `adm-r67-alma-mn-w1` (`192.168.122.188`), W2 `adm-r67-alma-mn-w2` (`192.168.122.189`).
- Hub contained all six Release 67 `.el10` Admiral NEVRAs; both workers contained Release 67 `.el10` `admiral-common` and `admiral-fleet`.
- The topology was already configured for R67. No source or package change occurred during this test.

## Procedure and observed result

Applied `e2e-whoami`, then released three concurrent `admiralctl instances provision` requests through a shared barrier. All requests used the same customer, app, tier, W1 placement and `--idempotency-key`.

- Request launches: `2026-10-23T21:11:42.963Z`, `.967Z`, and `.968Z` (5 ms from first to last).
- All three returned successful operation `op_51fd45f8116ca54c`, task `task_a6fc5949b0a7bca5`, instance `inst_e55d17f0ca65964d`, assigned to W1.
- The hub's customer query contained only that instance. W1 had exactly one pod, three containers and one volume; W2 had no matching workload resources.
- The first health observation conservatively reported `running/stopped/unavailable` with `runtime_not_healthy`; the next showed `running/healthy/available`. The workload endpoint returned HTTP 200.
- Deprovision operation `op_17b2a0369dbae04e` succeeded. Both workers had empty matching container, pod, volume and endpoint inventories afterward.
- Test interval: `2026-10-23T21:11:40.615Z` to `21:12:11.339Z` (30.724 seconds).

## Reproduction and evidence

Reproducer: [`../scripts/r67/r67-alma-multinode-concurrent-idempotency.py`](../scripts/r67/r67-alma-multinode-concurrent-idempotency.py). The command used the fixed lab SSH identity and per-guest pinned `known_hosts` files, with output path `packaging/build/validation/rc5-r67/alma-mn-concurrent-idempotency-01`. The raw directory is ignored, mode `0700`; its files and manifest are mode `0600`. Every capture verifies with `sha256sum -c SHA256SUMS`. Manifest SHA-256: `b8a056f951fcaf7d6ab52e17ddfa09e63a06193a99466ba857235bcc882aa6e5`. Reproducer SHA-256: `bd8f28fe9ca5d186a74faf037c026813c1d75745577198422fd4c4c66efd27f6`.

This proves same-key concurrent duplicate suppression, health convergence, HTTP service and cleanup for this R67 AlmaLinux pattern. It does not measure the capacity-reservation counter separately, simulate a client timeout after commit, test a conflicting body or distinct key, exercise cross-worker simultaneous mutation, or cover other OSes. The overall matrix remains **0/8**.
