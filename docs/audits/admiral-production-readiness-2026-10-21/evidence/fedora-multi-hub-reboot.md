# Fedora Rawhide Multi-Node hub recovery and worker lifecycle

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Candidate: Release 42 x86_64 RPMs, root source `748b703662eafdaf3919bad28787d0264f06bf16`.<br>
Guests: `rc5-r42-fedora-x86-multi-admin`, worker1 and worker2; Fedora Linux 46 Cloud Edition prerelease (Rawhide), x86_64. Management IPs `.120`–`.122`, WireGuard addresses `10.99.0.1`–`.3`. Isolated libvirt guests; no production systems were involved.

## Hub restart and manual recovery

After starting the three guests from their existing disks, the hub had zero `[Peer]` sections in `/etc/wireguard/wg-admiral.conf`, zero runtime peers, and two mode-0600 peer fragments in `/etc/wireguard/peers.d/`. The WireGuard, Admirald and PostgreSQL units were active. At `14:29:40Z`, the hub reported both workers `offline/degraded`; their last heartbeats were from `02:06Z`. Worker1 Fleet logs showed repeated timeout errors claiming tasks and refreshing the image list from the hub. This independently reproduces the hub restart defect `ADM-F-005` on the Fedora target.

For lab continuation, the existing peer fragments were appended to the main config, `wg-quick strip` validated the result, and `wg-quick@wg-admiral` was restarted. No product source or RPM files were changed. The manual recovery began at `14:29:54Z`; the config had two peer sections, and by `14:29:59Z` there were two runtime peers with recent handshakes and both workers were `active/healthy`. The raw recovery output records node status and handshake counts without exposing key material.

## Placement and worker reboot

`e2e-whoami` was applied to the hub and explicitly provisioned on each worker:

| Instance | Requested node | Operation | Result interval |
| --- | --- | --- | --- |
| `inst_52c8237d7d4a5986` | `rc5-r42-fedora-x86-worker1` | `op_6f9a828d61ddc78f` | succeeded, `14:30:33.621Z`–`14:30:38.335Z` |
| `inst_9f20cc5a14ff5a75` | `rc5-r42-fedora-x86-worker2` | `op_1ba052ecb91f7c7e` | succeeded, `14:30:46.064Z`–`14:30:51.258Z` |

After initial image/container startup, direct rootless Podman checks on both guests showed infra, app and PostgreSQL containers `Up`; `pg_isready` returned `accepting connections` on each. Hub records showed both instances `running/healthy` on the requested workers and all nodes `active/healthy`.

On worker2, SQL marker `fedora-worker-reboot-persisted` was inserted into the test database. `virsh reboot rc5-r42-fedora-x86-multi-worker2` was requested at `14:32:43Z`; the boot ID changed from `e58ab8f5-0bf2-432b-9d14-15bf7f96813e` to `eb6ae0b5-346b-48c6-9c74-29e7f87ab91f`. SSH returned with the new boot ID by `14:33:18Z` (~35 seconds). Infra, DB and app containers returned `Up`, PostgreSQL accepted connections, the SQL marker remained, and the hub showed worker2 active/healthy with a fresh heartbeat.

Both instances were then deprovisioned successfully. Worker1 deprovision operation `op_a83a2cdc484a4a30` completed `14:33:36.181Z`–`14:33:43.679Z`; worker2 operation `op_8c2f0eae15c99c63` completed `14:33:44.772Z`–`14:33:51.827Z`. The hub showed both records deprovisioned and all three nodes active/healthy. Each worker had zero rootless containers, zero Podman volumes, and zero matching test Quadlet files.

## Status and raw evidence

The Fedora run confirms the Multi-Node hub peer-loading failure after startup (**FAIL**, `ADM-F-005`); manual configuration restored the lab. Explicit placement on both workers, worker reboot persistence and deprovision cleanup passed their scoped checks. This is not a complete Fedora Multi-Node cell pass because recovery required manual intervention and several audit scenarios remain untested.

Ignored local raw logs are mode `0600`:

| Log | SHA-256 |
| --- | --- |
| `audit-target-fedora-hub-reboot.log` | `be31ad20bbd39883f075d3f646b36917e6efd8cc99396eb2ad54b44c0b0f9d25` |
| `audit-target-fedora-worker1-timeouts.log` | `d4dbaba4ae6a6210eb8324567cf58ffdbd404ffb097b2d1eb2ef34d7fda9cca3` |
| `audit-target-fedora-hub-manual-recovery.log` | `82bded9ad8ee49df3332437b71206eb01f8ce7662c60e152a4002b44fcdf9f42` |
| `audit-target-fedora-worker-reboot.log` | `650d4c0afcd8d20dab84343359c67f9db1889f10bbe313f2327f2eee501803d4` |
| `audit-target-fedora-multi-provision-worker1.log` | `4eff2519cd7a01987b034cad1cf676bc6518ac55b896ed0d8a47e617a41f5fa6` |
| `audit-target-fedora-multi-provision-worker2.log` | `e3ee8bba6a3e4a0785ebfbfe1c067e021d3f5948d99de876e562677d57e23a6a` |
| `audit-target-fedora-multi-deprovision-worker1.log` | `965440089a328b9ad0ddf37334c7f670903a53bf67a1c6456562915528584355` |
| `audit-target-fedora-multi-deprovision-worker2.log` | `fba189bb6ec0c3577ef2c90b7c0334a38cd7b160c4c886a548c12acabfd07c64` |

The logs contain no credentials.
