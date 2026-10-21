# Rocky Multi-Node controlled hub-worker partition

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Candidate: Release 42 x86_64, root source `748b703662eafdaf3919bad28787d0264f06bf16`.<br>
Topology: Rocky Linux 10.2 x86_64 hub `.110` and two workers `.111`/`.112`; WireGuard addresses `10.99.0.1`/`.2`/`.3`. These were isolated libvirt guests. No production systems were involved.

## Procedure

The test provisioned `e2e-whoami` on `rocky-r42-worker1` and confirmed the operation succeeded. It then inserted a temporary nftables input rule on the hub to drop all packets arriving on `enp2s0` from worker1's isolated underlay address. SSH management used a separate interface. A shell trap removed the temporary table on exit.

```sh
nft add table inet admiral_audit_partition
nft add chain inet admiral_audit_partition input '{ type filter hook input priority -10; policy accept; }'
nft add rule inet admiral_audit_partition input iifname enp2s0 ip saddr 10.77.0.11 drop
```

The hub's `admiralctl nodes list --output json` was polled every ten seconds. The provisioned instance was queried before partition, once the node became offline, and after network recovery. The rule was deleted before waiting for the node to rejoin.

## Result

Provisioning succeeded at `14:18:48.927Z`–`14:18:51.475Z` (`op_5e82499da617db68`, instance `inst_11315ca4624b7c29`, worker `rocky-r42-worker1`). Before partition the node was `active/healthy/available` and the instance reported `running/healthy`.

The partition began at `14:23:27Z`. The worker remained shown as `active/healthy` through `14:25:29Z`, then changed to `offline/degraded`, unavailable for provisioning, at `14:25:40Z` (133 seconds after packet loss began). During that outage the instance still reported `technical_status=running` and `health_status=healthy`; `last_health_checked_at` remained `14:22:58.727Z`, before the test started. This reproduces `ADM-F-002` and demonstrates stale instance health during a real packet filter, not only VM suspension.

The nftables table was removed at `14:25:40Z`. The node returned to `active/healthy/available` by `14:25:50Z`, ten seconds later. The instance ID remained unchanged and still reported `running/healthy`. No request was in flight during the outage; duplicate task delivery and callback replay were not exercised.

Deprovision then succeeded at `14:26:23.587Z`–`14:26:30.740Z` (`op_1a118f6ec73f9b96`). Worker1 had zero rootless containers, zero Podman volumes, and zero matching instance Quadlet files afterward. The nftables audit table was absent after the test.

## Status and evidence

**FAIL (availability state reporting); PARTIAL (rejoin and cleanup).** Node failure detection and rejoin worked, and the workload deprovisioned cleanly. The API continued to expose a stale healthy/running instance while its assigned worker was offline. In-flight task and callback recovery remain untested.

The ignored raw poll log is `packaging/build/validation/rc5-r42/audit-target-rocky-partition.log` (SHA-256 `1faf362f5151905e8541e56021310951cb4e19bb570b2cb092a9fd797d2c4702`, mode `0600`). The cleanup operation log is `audit-target-rocky-partition-deprovision.log` (SHA-256 `ba498e8aadc769e6c59a66e4a57587854edaff16980b381d09df5c3002d5842e`, mode `0600`). The logs contain no credentials.
