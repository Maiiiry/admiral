# R67 CentOS Stream 10 Multi-Node concurrent idempotency

Audit ID: `ADM-AUDIT-2026-10-21`  
Test ID: `R67-CENTOS-MN-CONCURRENT-IDEMPOTENCY`  
Result: **PASS for this scoped scenario; not a Multi-Node cell PASS**

## Candidate and environment

- Admiral source commit: `833d15aa4f8e96be30d28dad169b9d06a4d9894d`.
- Candidate: RC5 Release 67, `0.0.1rc5-67.el10`.
- OS: CentOS Stream 10 x86_64, three real isolated guests on the libvirt network.
- Roles: hub `adm-r67-centos-mn-hub` (`192.168.122.190`), W1 `adm-r67-centos-mn-w1` (`192.168.122.191`), W2 `adm-r67-centos-mn-w2` (`192.168.122.192`).
- Exact package NEVRAs were captured on the hub and both workers in the raw evidence directory. The hub had all six Admiral packages at Release 67 `.el10`; workers had the Release 67 `.el10` `admiral-common` and `admiral-fleet` packages.
- The scenario used an already configured R67 three-node topology. No source or package change occurred during the run.

## Procedure and expected result

The test applied the `e2e-whoami` app definition, then released three concurrent `admiralctl` provision requests through a shared barrier. Each request used the same customer, app, tier, explicit W1 placement, request body, and caller idempotency key. The expected result was one successful operation, one task, one instance, and one workload resource set assigned to exactly one worker. The test waited for healthy/available state, required workload HTTP 200, deprovisioned the instance, and inspected both workers for residual containers, pods, volumes, or app endpoints.

## Observed result

- Request launches were `2026-10-23T21:04:37.939Z`, `.941Z`, and `.948Z` (9 ms from first to last), behind the same release barrier.
- All three returned the same successful operation `op_f2635946f12b047f`, task `task_0366ef4ff44c41e7`, instance `inst_20b1753e59c2303b`, and assigned node W1.
- The hub's customer-instance query contained exactly that one instance. W1 had one app pod, its three containers (`infra`, `app`, `db`), one database volume, and one app endpoint. W2 had no matching workload resources.
- The first health sample conservatively reported `running/stopped/unavailable` with `runtime_not_healthy`; the next sample reported `running/healthy/available`. The workload endpoint returned HTTP 200 before cleanup.
- Deprovision operation `op_fb7881a72daa9d66` succeeded. Post-cleanup inventories on W1 and W2 contained no matching containers, pods, volumes, or app endpoints.
- Test interval: `2026-10-23T21:04:34.953Z` through `21:05:03.345Z` (28.392 seconds).

## Evidence and limits

Reproducer: [`../scripts/r67/r67-centos-multinode-concurrent-idempotency.py`](../scripts/r67/r67-centos-multinode-concurrent-idempotency.py). Raw captures are retained locally under the ignored path `packaging/build/validation/rc5-r67/centos-mn-concurrent-idempotency-03/`; all files verify with `sha256sum -c SHA256SUMS`. The evidence directory is mode `0700`; its manifest and run log are mode `0600`. Manifest SHA-256: `6b3c510030e0fbcafa05ada2b740570c128e7be595c8a5b78d00ff51d60d7db5`. Wrapper-log SHA-256: `26ee319cb6aa24750837a81b849dde3ef564be6ae3c53a9f345079c3980291f1`. The committed reproducer SHA-256 is `fcc8d2d9e96a65e1f58686fdfbf9c2ee83b9a928b546719e5cae88121cd44883`.

This verifies same-key duplicate suppression and runtime cleanup for this R67 CentOS Multi-Node request pattern. It does not separately inspect the capacity-reservation counter, simulate a client timeout after commit, test a conflicting body or different key, exercise simultaneous mutations from separate workers, or cover other operating systems. It is scoped evidence for issue #207 and earns no full-cell credit. The overall matrix remains **0/8**.
