# Release 67 Rocky Linux 10 Multi-Node targeted evidence

**Result: scoped fresh install, placement, central database recovery, WireGuard partition/rejoin, hub reboot recovery, and Podman deletion-failure retry passed. This is not a completed Multi-Node cell. Matrix remains 0/8.**

Date: 2026-10-23 UTC
Candidate RPM source root commit: 833d15aa4f8e96be30d28dad169b9d06a4d9894d
Candidate: six Admiral RPMs at 0.0.1rc5-67.el10
Target: Rocky Linux 10.2 x86_64
Topology: hub adm-r67-rocky-mn-hub; workers adm-r67-rocky-mn-w1 and adm-r67-rocky-mn-w2; each 2 vCPU / 2 GiB
Underlay: 10.77.0.20 / .21 / .22; WireGuard overlay: 10.99.0.1 / .2 / .3
Seed: Rocky-10.2-seed-20261023-r66.x86_64.qcow2, SHA-256 64d918c2b1b8d69d210372d0e80252798178e3ae9b6b7f4af4dbec2b39b5b3d0
Lab host: Rocky Linux KVM host, 8 GiB RAM plus 4 GiB swap. Disposable libvirt guests only; no production infrastructure was touched.

## Distro-native package boundary

The candidate was built from the same selected source pins in separate native builders. Fedora uses Fedora Rawhide tooling and only .fc46 RPMs; EL10 uses EL10 tooling and only .el10 RPMs. No EL10 binary RPM was copied to Fedora, force-installed there, or used as Fedora evidence. The build provenance and manifests are in [the R67 candidate record](release67-candidate.md); the durable rule is in [the RPM packaging guide](../../../rpm_packaging.md).

This topology used the local EL10 Release 67 repository with normal DNF dependency resolution and no --nodeps/--force bypass. The hub installed all six exact Release 67 .el10 Admiral RPMs. Each worker installed exact admiral-common and admiral-fleet .el10 RPMs. The final post-check verified the full expected package sets, SELinux Enforcing, no failed units, active required services, fresh node metrics/heartbeats, two fresh WireGuard handshakes, and no leftover containers, pods or volumes.

The installer was invoked in validation-seed mode. Its base OS and security-update transactions were skipped; the guests did not run a full dnf update. The seed already held the spec-derived Admiral runtime dependencies, but not every package required by the secure Ansible roles. Each worker's package delta recorded 88 added NEVRAs and one removed Cockpit package. In particular, installing firewalld added kernel-modules and kernel-modules-extra for 6.12.0-211.67.1.el10_2, the same version already running, and regenerated initramfs. Installing fail2ban added its EPEL/EL10 dependency set. These were role dependency installations, not a full operating-system update or a kernel version change. This gap should be accounted for when refreshing future seeds.

## Results

| Test ID | Scenario and observed result | Status |
| --- | --- | --- |
| R67-ROCKY-MN-BOOTSTRAP | Fresh hub secure install completed with ok=239, changed=105, unreachable=0, failed=0 in 576 seconds. Each worker secure install completed with ok=155, changed=54, unreachable=0, failed=0; W1 took 605 seconds and W2 646 seconds. The first worker heartbeat/metrics arrived after two retries; the second enrolled and handshook on the first attempt. All three nodes were active/healthy/available with fresh metrics, the control-plane CLI was healthy, SELinux was Enforcing, and checked services were active. | PASS, scoped |
| R67-ROCKY-MN-PLACEMENT-W1 | Provision operation op_66453b67af3095ca created inst_4225c90515f155b9 on W1. Sequential same-key replay returned the same operation and instance. API health converged to running/healthy/available on the first sample; PostgreSQL was ready on its first probe; SQL marker roundtrip succeeded; hub-to-app WireGuard HTTP returned 200. Deprovision op_8a4303849347e336 succeeded and no matching containers, pods, volumes, user units or files remained. | PASS, scoped |
| R67-ROCKY-MN-PLACEMENT-W2 | Provision operation op_3a2ba6c1b215e597 created inst_abba4becc72890d3 on W2. Sequential same-key replay returned the same operation and instance. API health converged to running/healthy/available on the first sample; PostgreSQL was ready on its first probe; SQL marker roundtrip succeeded; hub-to-app WireGuard HTTP returned 200. Deprovision op_2fcf66dc8e687151 succeeded and no matching resources remained. | PASS, scoped |
| R67-ROCKY-MN-DB-OUTAGE (#264) | With inst_0f202a1d1ecfd780 running on W1, central PostgreSQL was stopped for about 66 seconds and automatically restarted by the test timer. App HTTP stayed 200 at all 13 samples. Admirald logged 81 Fleet HTTP 503 records and zero 401/429. After PostgreSQL recovered, the worker and instance returned active/healthy/available, the SQL marker persisted, HTTP returned 200 and deprovision cleaned up. | PASS, scoped |
| R67-ROCKY-MN-PARTITION (#208/#237) | W2's WireGuard AllowedIPs were temporarily changed to isolate it from the hub, with an automatic restore timer armed before injection. Hub access from W2 timed out. Instance availability became unavailable with runtime_observation_stale and then heartbeat_stale. At poll 12, 136 seconds after partition start, W2 became offline/degraded and the instance reason became heartbeat_timeout. Restoring the peer returned W2 and the instance to active/healthy/available on the first rejoin poll. HTTP returned 200, the SQL marker persisted, and deprovision left no resources. | PASS, scoped |
| R67-ROCKY-MN-HUB-REBOOT (#211) | With inst_def1103d843f7e6f active on W1, the isolated hub VM was rebooted. Its boot ID changed. By recovery poll 2, about 76 seconds after reboot, PostgreSQL, Admirald and WireGuard were active; both worker routes and fresh handshakes returned; both workers had fresh post-reboot heartbeats; and the instance was healthy/available. The workload SQL marker persisted and HTTP returned 200. Deprovision succeeded. | PASS, scoped |
| R67-ROCKY-MN-PODMAN-FAILURE (#228) | On inst_d3c60a11a5ddb316, the scoped wrapper made only deletion commands naming this instance return exit 125. The first deprovision operation op_a3a15718def9bba9 failed and reported cleanup failure; the instance remained stopped and the pod, containers and volume remained for retry. Restoring Podman preserved the original SHA-256 4c8e6618c8075f15c5d695525d3272172aad52b4e70f447908e3b95e06cd9e6b and version 5.8.2. Retry operation op_122a6a897569ce6b succeeded; the instance became deprovisioned and no containers, pods, volumes or matching files remained. Temporary audit files and timer were removed after evidence capture. | PASS, scoped |

The final post-check at 18:58:20 UTC found all three nodes active/healthy/available with fresh heartbeats and metrics, Admiral status healthy, exact Release 67 .el10 package sets, SELinux Enforcing, no failed units, required services active, two fresh WireGuard handshakes, and zero rootless containers/pods/volumes on either worker.

## Retained harness failures and scope

The first #228 harness attempt injected the same expected deletion errors but stopped during a read-only resource inventory because its remote command inherited /home/validator and the admiral-apps user could not chdir there. The EXIT handler restored Podman; its SHA matched the pre-injection value. The workload was then deprovisioned successfully with restored Podman and the worker was verified clean. That incomplete attempt is not counted as a pass. The helper was corrected to run rootless inventory from /tmp; the second complete attempt above passed.

An initial hub-reboot helper invocation stopped before reboot because its domain-name guard contained stale guest names. The guard was corrected before the recorded reboot run. The post-check's earlier parser attempts are retained in the ignored local evidence directory; they exposed checker parsing errors, not Admiral failures. Only the corrected final post-check is counted.

Raw logs are kept outside Git under packaging/build/validation/rc5-r67/ with mode 0600. They were scanned for credentials, private keys, bearer tokens and database URLs; scans were clean. Test values are synthetic. Failed attempts were retained rather than overwritten.

## Reproduction and evidence hashes

Run from the repository root with the three disposable guests running, strict pinned known_hosts files and the local EL10 repository available. The secure bootstrap helper is scripts/install-admin-portal-audit.sh plus scripts/install-worker-audit.sh. Placement and failure procedures are in the R67 scripts below; DB-outage, partition and hub-reboot helpers are parameterized for these guest addresses and node IDs.

| Evidence | SHA-256 |
| --- | --- |
| Hub secure install log, packaging/build/validation/rc5-r67/rocky-mn-hub-install.log | 1a124997ca9d376d734d9fb83dd7236d5bf92fe0e7f58398b6fe2a539354bdb6 |
| W1 secure install log, packaging/build/validation/rc5-r67/rocky-mn-w1-install.log | e040fb53aaffb46cf53f0dfa4d479436aa4d83470a384bd6f19fbd18a47b5c09 |
| W2 secure install log, packaging/build/validation/rc5-r67/rocky-mn-w2-install.log | 9cffcf28f19b95131f1cea22f488ce55e93b3fa7ad76cc01c4d068618d780d0b |
| Final three-node post-check, packaging/build/validation/rc5-r67/rocky-mn-postcheck-final.log | 5d285ff04cb463d09e194c6294752806cd8c15f6ef5d30c192bfe11188e90379 |
| W1/W2 placement, packaging/build/validation/rc5-r67/rocky-mn-placement.log | ccf3e58cb9b6224be6e3cc57d327472743c49404e20f9b69b8d75cb77db778e6 |
| Central PostgreSQL outage, packaging/build/validation/rc5-r67/rocky-mn-db-outage-run.log | 2993b00044ed69aa63f38befdd02f76b88980428bf28c55592e2aca251da8794 |
| W2 partition/rejoin, packaging/build/validation/rc5-r67/rocky-mn-partition-run.log | 46deeae74692f4189fa5214eb264ff6ae8f80557def3d23bf1dafd7eb263e414 |
| Hub reboot recovery, packaging/build/validation/rc5-r67/rocky-mn-hub-reboot-run-02.log | c5c5ff32e5fc8b44dc9ceff5b5bd97336c65e677b3169237db383fd6e8cc2c4e |
| Podman fault/retry, packaging/build/validation/rc5-r67/rocky-mn-podman-failure-run-02.log | 617ee4af4cb74dffe84c2f4c3c77e3558f4b5dc1c5a96aadf3d2f1c9ddd9a1e4 |
| Injected Podman deletion command log, local evidence file | 71f00554909b50357697d754e667008d0a257decda12ad75316aebc47a809c00 |
| Podman run SHA-256 manifest, local evidence file | c2175c836f874d569f8747394e3bfe9f5442b711ee35c6a8c696142c5ad86219 |

Reproduction helpers (all checked with bash -n):

- [Rocky placement](../scripts/r67/r67-rocky-multinode-placement.sh)
- [Rocky central database outage](../scripts/r67/r67-rocky-multinode-db-outage.sh)
- [Rocky WireGuard partition and recovery](../scripts/r67/r67-rocky-multinode-partition.sh)
- [Rocky hub reboot](../scripts/r67/r67-rocky-multinode-hub-reboot.sh)
- [Rocky Podman deletion failure and retry](../scripts/r67/r67-rocky-multinode-podman-removal-failure.sh)

## Limits

This proves only the listed scoped scenarios on Rocky Linux 10.2 Multi-Node. It does not complete a Rocky Multi-Node release cell. It does not test task interruption after claim, lease expiry/replay, conflicting cross-node mutations, multi-tenant authorization, cross-workload network/database/storage isolation, external backup targets, memory/disk exhaustion, latency/packet-loss tuning, concurrency load, long-duration operation or performance percentiles. R67 secure-bootstrap and workload tests on Fedora and all other candidate records are separate evidence and do not combine into a Multi-Node matrix pass.
