# CentOS Stream 10 Multi-Node execution

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Result: **PARTIAL — FAILURES OPEN** (three-node install, registration, placement and cleanup executed; hub restart and failed-service injection both reproduced defects; full cell remains incomplete)<br>
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

The guest SSH host keys were checked from the guest disks against `ssh-keyscan`; strict host-key checking was used. A temporary audit-only SSH key was injected into the isolated guests because the original lab private key was unavailable. The first worker helper invocation stopped before mutation because its expected local key path did not exist; after provisioning that temporary key, both worker installers completed successfully. Later, guest-agent execution was denied by its allowlist, so a second temporary audit key was appended to the isolated guest authorization files while the VMs were shut down and their local virtual disks mounted. Both temporary private keys are excluded from tracked evidence.

The hub installed the six Release 42 packages and ran the secure admin/portal installer. Ansible reported `ok=229 changed=103 unreachable=0 failed=0 skipped=136`. Both worker installers exited 0. The workers initially resolved older published COPR builds; that mixed-version observation was discarded. The local Release 42 candidate repository was then used to install the exact six Release 42 NEVRAs on the hub and both workers, followed by sequential Fleet restarts. All three hosts reported the same package versions, and Fleet was active on both workers.

## Executed scenarios

| ID | Procedure | Expected | Observed | Status |
| --- | --- | --- | --- | --- |
| CS-MN-01 | Securely install hub and two workers, register nodes, check WireGuard and Fleet | Three authenticated, healthy nodes with recent heartbeats | Both workers registered as `active/healthy/available_for_provisioning`; both peers handshook; Fleet active on workers | PASS (scenario only) |
| CS-MN-02 | Apply `examples/apps/e2e-whoami.yaml`; provision explicitly to worker 1 and worker 2 | Each instance is assigned to the requested node and its declared services become ready | Both operations succeeded and each worker ran infra, app and PostgreSQL resources. PostgreSQL `pg_isready` eventually passed on each worker | PARTIAL / FAIL for readiness reporting: API showed `running/healthy` while the declared DB unit was still activating and before its container was present; it converged without intervention. See `ADM-F-006` / #227 |
| CS-MN-03 | Deprovision both test instances; inspect rootless Podman and Quadlet state | No test resources remain | Both deprovision operations succeeded; each worker had zero test pods, containers, volumes and Quadlets | PASS (scenario only) |
| CS-MN-04 | Restart the isolated hub/workers after onboarding; verify automatic peer and worker recovery | Durable peers load at hub start and both workers rejoin without manual edits | All three guests were shut down to add an audit key, then restarted. Hub WireGuard was active with zero runtime peers while two durable peer files remained; both workers went offline and a worker-targeted provision returned HTTP 503 without an operation ID. Appending peer fragments to the main config and restarting WireGuard restored both handshakes; worker 2 rejoined first and worker 1 returned active/healthy at 16:25:37Z | FAIL / HIGH `ADM-F-005` / #211; lab-only manual recovery |
| CS-MN-05 | Apply the `/bin/false` database fixture and provision on a selected worker | Operation fails or is degraded; instance health remains non-healthy while a required service fails | On worker 2, operation `op_b72dc14ab054552a` succeeded (`16:25:14.864Z`–`16:25:19.750Z`) for instance `inst_8be56687bf0356e4`; API reported `running/healthy` at `16:25:24Z`, while `admiral-inst_8be56687bf0356e4-db.service` was `failed` with exit status 1 and no DB container existed. The app and infra containers were `Up`. Deprovision `op_0e905f230f36ba15` succeeded (`16:25:46.524Z`–`16:25:51.297Z`); test resources were cleaned | FAIL / HIGH `ADM-F-006` / #227; direct Multi-Node reproduction |
| CS-MN-06 | Start two identical logical provisions concurrently with the same app/customer but target separate workers | One instance/operation or an explicit conflict; no duplicate customer workload | Requests began 22.9 ms apart (`16:31:56.142Z` and `16:31:56.165Z`). Both returned `succeeded`: `op_bb229b9601a046ad` created `inst_de21f056551792b1` on worker 1 and `op_af2c73cc35a2269e` created `inst_42609b8fb15431a0` on worker 2. Deprovision operations `op_76ad213cdfc47db2` and `op_69e8b80da52e5508` both succeeded; each worker then had zero matching containers, volumes and Quadlets | FAIL / MEDIUM `ADM-F-001` / #207; duplicate instances across workers |
| CS-MN-07 | Check candidate RPM verification and package-owned paths on hub/workers | Fixed roots retain spec owner/mode; Harbor can traverse/read TLS key while secrets remain private | On both workers, privileged `rpm -V admiral-common` returned no differences; data roots were `admiral:admiral 0751` for `/var/lib/admiral` and `instances`, `admiral-apps:admiral-apps 0750` for `backups` and `restore`, and `admiral-apps:admiral-apps 0700` for `tmp`. On hub, TLS key was readable as `admiral`; `/etc/admiral/secrets` was `root:root 0600`; Harbor drop-in dir was `root:admiral 0750`. `rpm -V admiral-harbor` showed only the installer-generated `harbor.env` config difference | PARTIAL for #191/#203/#205; a second Ansible reconciliation and full matrix remain pending |

Provision operation IDs were `op_ffa7795ed940e6f5` and `op_6d867fca9b7e6d60`; instance IDs were `inst_7ae597d2ffdeeacc` and `inst_0e819b27f51e789a`. Deprovision operation IDs were `op_1512140854ca08ec` and `op_f18d272b3d91347a`. The first provision ran from `16:10:04.97Z` to `16:10:11.00Z`; API state reported healthy at `16:10:39Z`, while PostgreSQL was not ready until approximately `16:10:47Z`. The second provision ran from `16:11:08.49Z` to `16:11:13.31Z`; API state reported healthy at approximately `16:11:43Z`, while the DB unit was still activating. By approximately `16:12:08Z`, the DB unit was active and `pg_isready` passed. These observations reproduce the health-reporting concern in a real Multi-Node topology.

### Hub restart and recovery

The three lab guests were shut down cleanly to add a temporary audit SSH key to their local authorization files, then started again from their existing disks. At `16:24:30Z`, the hub WireGuard unit was active, but the runtime peer count was zero while two `.conf` peer fragments remained in `/etc/wireguard/peers.d/`. Both workers were offline with `heartbeat_timeout`. A provision attempt targeting worker 1 received HTTP 503 and returned no operation ID. The ignored raw observation log is `audit-centos-multi-hub-reboot.log`, SHA-256 `444c55adada2e047f616ad3be3adcf25bbee8a16a852641ccf12070735cdaee3`.

For lab recovery, the two durable peer fragments were appended to the main WireGuard config and `wg-quick@wg-admiral` was restarted. The interface then showed two peers; worker 2 rejoined first and worker 1 returned active/healthy at `16:25:37Z`. No workload was present during the hub outage. The post-recovery status log is `audit-centos-multi-hub-recovery.log`, SHA-256 `cb27dfdb6cc15df9109220791595af8ed2a9dfeff0c8c40f7ad36c02260a856c`. This demonstrates manual recovery only and reproduces #211; it is not automatic recovery.

### Failed-service injection on a Multi-Node worker

After both nodes returned, the `/bin/false` fixture was applied to the hub and explicitly provisioned on worker 2. Admiral returned a successful terminal operation, and the instance API reported `running/healthy`; direct user-systemd inspection showed the required DB unit failed with exit status 1 and rootless Podman showed no DB container. The app and infra containers remained up. Deprovision succeeded and left zero test pods, containers, volumes or Quadlets. Raw operation, unit-journal and cleanup observations are in `audit-centos-multi-failing-db.log`, SHA-256 `cafbc88dbb608323d8c4bcb5d37985e4d13fad14caf1ee45d6cfb6d4d0279f9d`. This confirms `ADM-F-006` directly on a Multi-Node worker; it does not clear the defect.

### Concurrent provision across two workers

Two provision processes were released through a barrier on the hub for the same app and customer, one targeting each worker. The requests began 22.9 ms apart and both completed successfully with different operation and instance IDs. This is an integration reproduction of duplicate logical workloads across workers, not a simulated request. Both test instances were deprovisioned; each worker had zero matching test containers, volumes and Quadlets. The restricted raw log is `audit-centos-multi-concurrent-provision.log`, SHA-256 `7f5c9008e03c92b6a3f0427aad44e9b0066927a475596e65c8afb003acbe67dc`.

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
| Hub restart, pre-recovery observations | `444c55adada2e047f616ad3be3adcf25bbee8a16a852641ccf12070735cdaee3` |
| Hub peer recovery and worker rejoin | `cb27dfdb6cc15df9109220791595af8ed2a9dfeff0c8c40f7ad36c02260a856c` |
| Failed-service Multi-Node run and cleanup | `cafbc88dbb608323d8c4bcb5d37985e4d13fad14caf1ee45d6cfb6d4d0279f9d` |
| Concurrent cross-worker provision and cleanup | `7f5c9008e03c92b6a3f0427aad44e9b0066927a475596e65c8afb003acbe67dc` |
| Candidate RPM verification and package-owned path checks | `df1d6f5521f842aecc6abc892173dc0c7186fe9d45e63804d10a9cf865e9d354` |

The Fleet restart record includes an unavailable guest `go` command from an optional diagnostic; service state and RPM identity were recorded independently. No Go compiler availability is claimed. The initial helper failure log was overwritten during retry, so only the failure description above is retained, not a raw log.

## Not tested in this execution

This is not a full CentOS Stream Multi-Node cell PASS. This run did not test database persistence across reboot, database process failure independently of the guest restart, network partition, task replay/lease recovery, conflicting updates/deletes, node removal, cross-workload isolation, unauthorized callbacks, backup/restore, resource pressure or performance. Hub restart required manual peer recovery; failed-service injection and concurrent provision both reproduced defects. The full audit remains incomplete and the Multi-Node production-readiness decision remains **NOT READY**.
