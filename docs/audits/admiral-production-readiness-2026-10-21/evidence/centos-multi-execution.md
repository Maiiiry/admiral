# CentOS Stream 10 Multi-Node execution

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Result: **PARTIAL** (three-node install, registration, placement and cleanup executed; the complete cell and declared-service failure scenario are not validated)<br>
Candidate root: `748b703662eafdaf3919bad28787d0264f06bf16`<br>
Candidate packages: six Admiral RPMs at Release 42; exact package identity is recorded in the private execution logs.<br>
Platform: CentOS Stream 10 x86_64, three isolated KVM guests, each 2 vCPU and 2 GiB RAM.<br>
Topology: one admin/portal hub and two Fleet workers; SELinux enforcing.

## Setup and identity

| Guest | Role | Guest address | WireGuard address | Node ID |
| --- | --- | --- | --- | --- |
| `audit-cs10-multi-hub-r42` | admin + portal | `192.168.122.170` | `10.99.0.1` | hub |
| worker 1 | workload worker | `192.168.122.171` | `10.99.0.2` | `cs10-worker1` |
| worker 2 | workload worker | `192.168.122.172` | `10.99.0.3` | `cs10-worker2` |

The guest SSH host keys were checked from the guest disks against `ssh-keyscan`; strict host-key checking was used. A temporary audit-only SSH key was injected into the isolated guests because the original lab private key was unavailable. The first worker helper invocation stopped before mutation because its expected local key path did not exist; after provisioning that temporary key, both worker installers completed successfully. The key is excluded from tracked evidence.

The hub installed the six Release 42 packages and ran the secure admin/portal installer. Ansible reported `ok=229 changed=103 unreachable=0 failed=0 skipped=136`. Both worker installers exited 0. The workers initially resolved older published COPR builds; that mixed-version observation was discarded. The local Release 42 candidate repository was then used to install the exact six Release 42 NEVRAs on the hub and both workers, followed by sequential Fleet restarts. All three hosts reported the same package versions, and Fleet was active on both workers.

## Executed scenarios

| ID | Procedure | Expected | Observed | Status |
| --- | --- | --- | --- | --- |
| CS-MN-01 | Securely install hub and two workers, register nodes, check WireGuard and Fleet | Three authenticated, healthy nodes with recent heartbeats | Both workers registered as `active/healthy/available_for_provisioning`; both peers handshook; Fleet active on workers | PASS (scenario only) |
| CS-MN-02 | Apply `examples/apps/e2e-whoami.yaml`; provision explicitly to worker 1 and worker 2 | Each instance is assigned to the requested node and its declared services become ready | Both operations succeeded and each worker ran infra, app and PostgreSQL resources. PostgreSQL `pg_isready` eventually passed on each worker | PARTIAL / FAIL for readiness reporting: API showed `running/healthy` while the declared DB unit was still activating and before its container was present; it converged without intervention. See `ADM-F-006` / #227 |
| CS-MN-03 | Deprovision both test instances; inspect rootless Podman and Quadlet state | No test resources remain | Both deprovision operations succeeded; each worker had zero test pods, containers, volumes and Quadlets | PASS (scenario only) |

Provision operation IDs were `op_ffa7795ed940e6f5` and `op_6d867fca9b7e6d60`; instance IDs were `inst_7ae597d2ffdeeacc` and `inst_0e819b27f51e789a`. Deprovision operation IDs were `op_1512140854ca08ec` and `op_f18d272b3d91347a`. The first provision ran from `16:10:04.97Z` to `16:10:11.00Z`; API state reported healthy at `16:10:39Z`, while PostgreSQL was not ready until approximately `16:10:47Z`. The second provision ran from `16:11:08.49Z` to `16:11:13.31Z`; API state reported healthy at approximately `16:11:43Z`, while the DB unit was still activating. By approximately `16:12:08Z`, the DB unit was active and `pg_isready` passed. These observations reproduce the health-reporting concern in a real Multi-Node topology; they do not show that failed-service injection was run there.

## Evidence retention

Installer, candidate-bootstrap, provision, deprovision and cleanup verification logs are retained under the ignored local directory `packaging/build/validation/rc5-r42/` with restricted permissions. SHA-256 values:

| Artifact | SHA-256 |
| --- | --- |
| Hub package bootstrap | `76f7f2ba530f5ac87fa0661857f7610809a895266b85cc5c7d9158b0078413e6` |
| Hub secure install | `3b3620225520104c5273cc9952503117bed8cd098760fc2c2691f0dfe30deca8` |
| Worker 1 install | `10479ab1c83c555d415f0dc567d19b33dc1b1a867cde3b1d45f4d885a53a0733` |
| Worker 2 install | `c7843e997cabbd629177482b3e04778d8e65cc281ddbbaa8c3e6438cc32d080e` |
| Worker 1 Release 42 candidate bootstrap | `23c961f4bc3e9bfa004f033b37487fcee27b3ed6ff70f75c889197841b170689` |
| Worker 2 Release 42 candidate bootstrap | `a896841440c80a52f02fb2ee050aa22d6de88342786c1e6d514c047d8141b321` |
| Fleet restart and package check | `037dac47e0ffbacbb008b4193f8f9416924ecd4495981cbcf1bbe6e91eef1591` |
| Worker 1 provision | `01da460a1aa9eb08e9c6f466e88445509f79ba6259b453471ef4a8f9a9da34d1` |
| Worker 2 provision | `7dc82ba245431c9b7038cb974cf1a10de34147f69960abe652b03568e3266b64` |
| Worker 1 deprovision | `410ba100ebbddf93ba30bed8f45b9e2c03b2aca582122423dd65d43b7d409daf` |
| Worker 2 deprovision | `c95a3e5052f1ce63daae3b33fa319a5e6d8164ca0e6bea180f98d666a1dd5196` |
| Cleanup verification (both workers) | `3f2e5105546fd4f84fc8946a8c613f529b0e581a66e72b217239a33854349d5` |

The Fleet restart record includes an unavailable guest `go` command from an optional diagnostic; service state and RPM identity were recorded independently. No Go compiler availability is claimed. The initial helper failure log was overwritten during retry, so only the failure description above is retained, not a raw log.

## Not tested in this execution

This is not a full CentOS Stream Multi-Node cell PASS. This run did not test database persistence across reboot, host/hub outage, network partition, worker loss/rejoin, task replay, duplicate or concurrent requests, node removal, cross-workload isolation, unauthorized callbacks, backup/restore, resource pressure, performance, or failed declared-service injection. The full audit remains incomplete and the Multi-Node production-readiness decision remains **NOT READY**.
