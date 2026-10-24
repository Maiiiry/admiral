# RC5 Release 68 — CentOS Stream Multi-Node placement and lifecycle

Audit: `ADM-AUDIT-2026-10-21`
Test ID: `R68-CENTOS-MN-PLACEMENT-01`
Result: **PASS, scoped before candidate invalidation; no cell credit.**
Candidate: `0.0.1rc5-68.el10`, root/package source commit `4077c4ddb9d233682961d36c3570c63e70eb6405`.

## Environment

- Three real isolated CentOS Stream 10 x86_64 guests: hub `192.168.122.204`, W1 `.205`, W2 `.206`; each had 2 vCPU and 2 GiB RAM.
- Fresh overlays backed by `/var/lib/libvirt/images/admiral-validation/seeds/CentOS-Stream-10-seed-20261023-r66.x86_64.qcow2`, SHA-256 `2cbea69dd6f99334decc0c89441f54d7d78f1e6370e2ecd7771e9cc51096bf68`.
- SELinux Enforcing. Exact R68 `.el10` packages: six Admiral packages on hub; `admiral-common` and `admiral-fleet` on each worker. The postcheck found active hub/Fleet services, no failed systemd units, no Fedora-tagged packages, fresh WireGuard handshakes and three active/healthy/available nodes.
- The protected raw evidence and postcheck are in ignored `packaging/build/validation/rc5-r68/centos-mn-placement/run-20261024T014515Z/`. Directory mode is 0700; files are 0600. Manifest SHA-256: `2a50df5fd4fc68b904d4ab9b3df92776619c044e3b394ae00931d79e5dcb3c53`; every entry passed `sha256sum -c` after the postcheck log was added.
- Reproducer: [`../scripts/r68/r68-centos-multinode-placement.sh`](../scripts/r68/r68-centos-multinode-placement.sh). Executed helper SHA-256 `b7cc37c4afd94344a5f711fa37558835414873ed3fd275085e43db1e7c52c6de`; fixture SHA-256 `8adad770e879a655a676af2e9f389343f93547a39f73f5779dbd7c9c1372d2f4`.

## Procedure and observed result

The helper rechecked the OS, architecture, SELinux mode and exact R68 NEVRA tags on all three guests, then applied `examples/apps/e2e-whoami.yaml`. It explicitly provisioned sequentially on both workers, replayed each request with the same idempotency key, checked actual rootless Podman state, inserted/read a local PostgreSQL marker, verified the hub received the expected `whoami` HTTP response over WireGuard, deprovisioned each workload, checked runtime/filesystem cleanup and rechecked node health.

| Worker | Provision result | Same-key replay | Health convergence | SQL/HTTP | Deprovision and cleanup |
|---|---|---|---|---|---|
| W1 `adm-r68-centos-mn-w1` | `op_f8eea4256a64b2ff`, `task_a60459d9fd25fab0`, `inst_e9b18d9cfdb1d94f`, terminal `succeeded` | Same operation and instance returned | First sample `running/unhealthy/unavailable`; next sample healthy/available at `2026-10-24T01:46:04.429658Z` | Marker `r68-centos-inst_e9b18d9cfdb1d94f` read back; hub received HTTP 200 and a `Hostname:` whoami response at `10.99.0.2:40000` | `op_405264cfa74d05a1` succeeded; no matching containers, pods, volumes, units or files |
| W2 `adm-r68-centos-mn-w2` | `op_4d5840d2047b928c`, `task_a93fd176454a6615`, `inst_2ee7ed334c1e2804`, terminal `succeeded` | Same operation and instance returned | First sample `running/unhealthy/unavailable`; next sample healthy/available at `2026-10-24T01:47:06.717778Z` | Marker `r68-centos-inst_2ee7ed334c1e2804` read back; hub received HTTP 200 and a `Hostname:` whoami response at `10.99.0.3:40000` | `op_e67e040afa5165ba` succeeded; no matching containers, pods, volumes, units or files |

Each workload used its own application/database/infrastructure containers and remained assigned to the requested worker. Both workers remained active/healthy/available after cleanup. The recorded initial unavailable health samples are consistent with the documented `admiralctl --wait` contract: it waits for terminal operation state, not asynchronous runtime health. This check waited separately for health and HTTP success.

## Limits and disposition

This was one sequential placement/replay sample per worker. It did not test concurrent operations, failure injection, partitions, reboot, security/isolation negatives, performance, or the complete Multi-Node cell catalog. A separate storage-state discrepancy in the same candidate is recorded in [the storage observation report](release68-centos-multinode-storage-observation.md) and tracked by [#268](https://github.com/admiral-project/admiral/issues/268). R68 has since been superseded for release-matrix credit; this result is historical evidence only and does not carry to Release 69. The matrix remains **0/8**.
