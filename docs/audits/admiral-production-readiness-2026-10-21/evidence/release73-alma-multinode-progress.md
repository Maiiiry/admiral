# RC5 Release 73 — AlmaLinux 10 Multi-Node progress

**Result: scoped scenarios passed; this is not a complete Multi-Node cell.** Tests used the exact Release 73 RPM payload. No Admiral source or RPM was changed during these runs.

## Candidate, seed and lab

- Audit window: 2026-10-21 through 2026-10-24. The AlmaLinux Multi-Node scenarios below ran on 2026-10-24; elapsed times describe individual VM operations, not continuous audit work.
- Candidate root commit: `d84c130380ca5db3f73c32762c5f38bcccd75a10`.
- Runtime packages: exact `0.0.1rc5-73.el10` Admiral RPMs on AlmaLinux 10.2 x86_64.
- Seed: `/var/lib/libvirt/images/admiral-validation/seeds/AlmaLinux-10.2-seed-20261024-r71.x86_64.qcow2`; SHA-256 `c6f9bf83159c706ecaea84b7717767749b4fdf8d66cd5c2b4ae68583ba890234`. A fresh R73 guest's `dnf --refresh check-update` returned 0 at 2026-10-24T12:23:55Z. The R73 VM overlay used this seed as its backing file.
- Three real KVM guests, each 2 vCPU / 2 GiB: hub `adm-r73-alma-mn-hub`, W1 `adm-r73-alma-mn-w1`, W2 `adm-r73-alma-mn-w2`. Underlay addresses: `10.77.0.23–25`; WireGuard addresses: `10.99.0.1–3`.
- Host: x86_64, 8 GiB RAM and 4 GiB swap. Only one three-guest cluster was run at a time.
- Raw guest logs and captures remain in the ignored validation tree, mode `0600`. No credential or token value is included here.

## Executed scenarios

| Test ID | Procedure and observed result | Status |
|---|---|---|
| `R73-ALMA-MN-BASELINE-01` | Exact R73 NEVRAs and AlmaLinux 10.2 confirmed on all guests. SELinux Enforcing, firewalld/fail2ban active, zero failed units; hub services and worker Fleet active. All nodes active/healthy/available with fresh WireGuard handshakes. W1/W2 had rootless Podman enabled and no remaining workload resources. | PASS, scoped |
| `R73-ALMA-MN-PLACEMENT-01` | Explicit placement on W1 and W2; replay of each same-key request returned its original operation and instance. Each workload reached healthy/available, storage converged to 1 GiB (`1073741824`, `ok`), HTTP returned 200 over WireGuard, and a PostgreSQL marker persisted. Deprovision left no matching containers, pods, volumes, units or files. | PASS, scoped; both workers |
| `R73-ALMA-MN-CONCURRENT-IDEMPOTENCY-01` | Three barrier-synchronized identical requests returned one operation `op_fe941855c99860ae`, task `task_830cc11aeb706f5b` and W1 instance `inst_436c15df0f869ea7`. The workload became healthy/available, HTTP returned 200, cleanup was empty. Run: 12:53:39.133–12:54:06.017Z. | PASS, scoped; one race sample |
| `R73-ALMA-MN-API-CONFLICT-01` | Authenticated active-node removal on W2 returned HTTP 409; CLI reported the conflict; the workload stayed HTTP 200. After deprovision, cleanup passed. The successful retry completed at 12:55:18Z. | PASS, scoped |
| `R73-ALMA-MN-PARTITION-01` | W2's WireGuard path was partitioned. A hub request timed out (curl 28); the instance first showed stale observation, then the node became offline/degraded and the instance `heartbeat_timeout` at 12:58:04Z, about 138 seconds after partition start. Restoring the peer at 12:58:05Z returned node and instance to active/healthy/available by 12:58:06Z. HTTP and SQL marker persisted; cleanup passed. | PASS, scoped |
| `R73-ALMA-MN-WORKER-REBOOT-01` | Rebooted W1 with an active workload at 12:58:35Z; boot ID changed. Initial state was stopped/unavailable with no runtime; containers and HTTP recovered, then API converged to available at 12:59:34Z (about 59 seconds). SQL marker persisted and cleanup passed. | PASS, scoped |
| `R73-ALMA-MN-HUB-REBOOT-01` | Rebooted the hub at 13:00:40Z with an active W1 workload. PostgreSQL, `admirald` and WireGuard returned; routes and fresh handshakes for both workers recovered. W1 health, HTTP 200 and SQL marker persisted; deprovision passed. | PASS, scoped |
| `R73-ALMA-MN-NODE-REMOVE-01` | Active W2 removal was rejected. After deprovision and empty inventory, idle removal removed W2 from hub inventory and revoked its live and persistent WireGuard peer. W2 was re-enrolled with the supported installer; heartbeat and fresh handshake returned, the temporary bootstrap SSH key was rejected, and all three nodes were healthy. Removal run: 13:03:06–13:03:34Z; re-enrollment: 13:04:29–13:09:08Z. | PASS, scoped |
| `R73-ALMA-MN-OLD-TOKEN-REVOKE-01` | To isolate token authorization from expected VPN loss, a temporary W2 WireGuard peer was added only for the negative request. The removed W2's old Fleet token received HTTP 401. The temporary peer was immediately removed and verified absent from live and persistent config; the token was never printed or captured. | PASS, scoped |
| `R73-ALMA-MN-PEER-REVOCATION-RETRY-01` | A temporary failure shim under `/run` made the packaged peer-revocation service return failure. `admiralctl nodes remove` returned HTTP 503 after retries; W2 stayed active/healthy/available, its active token fingerprint was unchanged, and its peer remained in live and persistent WireGuard state. Restoring the packaged helper made the retry remove the node, token and peer; the supported secure installer re-enrolled W2 and rejected the temporary bootstrap SSH key. Run: 15:42:24–15:46:34Z. | PASS, scoped |
| `R73-ALMA-MN-PRIVATE-UI-AFTER-REMOVAL-01` | After idle removal, the removed W2's Fleet process remained active, but its request to the hub's private UI timed out (`curl` exit 28, HTTP `000`). The removed peer count was zero in both live and persistent hub WireGuard state. | PASS, scoped |
| `R73-ALMA-MN-REMOVED-PEER-HUB-REBOOT-01` | Rebooted the real hub after W2 removal. Boot ID changed; after reboot, the W2 route and node record remained absent, while W1's route and fresh handshake returned and the remaining cluster was healthy. W2 was securely re-enrolled after the check. SSH returned at poll 5; the recorded recovery check passed at poll 1, 15:48:30Z. | PASS, scoped |
| `R73-ALMA-MN-POSTCHECK-01` | Final postcheck after re-enrollment: all three nodes active/healthy/available, exact R73 package tags, secure services and no failed units; workers rootless with empty workload inventories. | PASS, scoped |

The first placement attempt used stale worker IDs in the local harness and created no workload; the corrected attempt passed. The first API-conflict attempt checked runtime health immediately after operation terminality. `admiralctl --wait` waits for operation completion, not asynchronous workload health; the harness was corrected to wait for healthy/available and rerun successfully. These are retained harness-precondition errors, not product failures. An SSH probe against the old Single-Node guest reset before authentication and ran no guest command; seed freshness was then checked successfully using a fresh clone.

## Evidence and reproducers

Protected raw evidence is under `packaging/build/validation/rc5-r73/runtime/multi/alma/`. The SHA-256 values below are hashes of each successful `SHA256SUMS` manifest:

| Scenario | SHA-256 |
|---|---|
| Initial baseline postcheck | `d6334a8532c8c98f8796f60e323e78c5117efbfc7b52a6bd688996fe76b9a842` |
| Final postcheck after re-enrollment | `31ad1f1d47ba0ffa793ed1ee45acf03e7986a253e16f0e56092e10bc3ee927ba` |
| Placement on W1 and W2 | `7458fee053384e14c8440c4c5bb566eb1cee16fe8a0f4dd221a003a479e3eb38` |
| Concurrent idempotency | `6aff77ad9f603479b7a50056b81cffcb4ba79f4c58cc44bd8590c9414a19c1e0` |
| API conflict | `bce1524b927b1731ffaf57713dcd3c437994ad3a8792644d6b4806c61e55e56f` |
| WireGuard partition/rejoin | `ad486971bee376b1e016638c9b4dd86703c067868ccb506d646b7fdf325844f0` |
| Worker reboot | `10b26b4a5943bed4ac049656d83a9647d0e273666d8006fa3cca8535adc4aa22` |
| Hub reboot | `34131c94292fa6eb2c353ae7c6b3e5dadab3acd71db0f721e6747aa4f7da454d` |
| Node removal | `100da0acea9bd5562478d6aabd9e39e04cc0ecea664a44ad54de688aece5e82d` |
| Old-token revocation | `f665734188b3a605aeaa54fcc129a9fc21607c16919b8a85daee2c007b68b771` |
| Peer-revocation helper failure and retry | `29d5549010a423c13d322e462621a283eb49b0f83f9be07ef2d24f996b53875b` |
| Private UI denial after removal | `31c9b662d369d268084f6a79871fad8a77d374257f764170dd699b837fd60133` |
| Removed-peer persistence across hub reboot | `44e1cb0a0f10c4aa3b8bd2c66346efb2de75f5ad0672bb14185d23c111f19639` |

Reproduction scripts are in [evidence/scripts](scripts/):

- `r73-alma-multinode-placement.sh` — SHA-256 `26fd4ccc35c01158b1e2df5b7c7574415bc603ccddc30cc7430c14aa4e7377ee`
- `r73-alma-multinode-concurrent-idempotency.py` — SHA-256 `707dd392c2287e586f004201a4b2c811b1edae4f5abc4423d314b13bf5562308`
- `r73-alma-multinode-api-conflict.sh` — SHA-256 `52327a262fe342443b2c66bbe8076afe25be4b0e9b61ad0b830fc87216c442a6`
- `r73-alma-multinode-partition.sh` — SHA-256 `4adb4d5d4878af05ffd0577358ef37b453e16c8004a21c7297877cf2d1161a12`
- `r73-alma-multinode-worker-reboot.sh` — SHA-256 `8e460f59841b8ccb817453165249a2eaf7f96648df8b885bb545b6e2c2cc5279`
- `r73-alma-multinode-hub-reboot.sh` — SHA-256 `5f02f150f2ebf3da3795b2b8ad9107f8e487e58dbc264ac11128b0e50290e25c`
- `r73-alma-multinode-node-removal.sh` — SHA-256 `3bddebaa1b1140f6722a9172c3bdb4435f63bb4f92f0f83be63c1ae39a57b845`
- `r73-alma-multinode-old-token-revocation.sh` — SHA-256 `1f88384876296e46a51d86d12f70535e22afb55f1e03ae839efce003dee00827`
- `r73-alma-multinode-peer-revocation-retry.sh` — SHA-256 `84402916ab7bd8ed23ab2499fa32b7b2f6649064dff1c66b1040844188fa3565`
- `r73-alma-multinode-private-ui-after-removal.sh` — SHA-256 `ad4e4208fb725616c1b702d660886b5ba267d895c8dd47f2bdf07c36e5ab3e9b`
- `r73-alma-multinode-removed-peer-hub-reboot.sh` — SHA-256 `69c4efb4c801f78d3823df1e7e4dfec20688ba4e599fffe27f2816366bdc8821`
- `r73-alma-multinode-postcheck.sh` — SHA-256 `9215c9f44e46638d997efba1e5fb043089e33ec022b67446e716a735b7100100`

## Limits and cell decision

These are real three-guest end-to-end and failure-injection results for the named scenarios only. Active task interruption/replay, database outage, latency injection, resource exhaustion, conflicting update/delete, cross-workload isolation negatives, exhaustive authorization, and performance distributions were not tested. The old-token test isolates token rejection only; the private-UI probe covers one endpoint and one removed worker.

AlmaLinux 10 Multi-Node is **PARTIAL**, not a full cell pass. The active Release 73 matrix is **4/8 PASS, 3/8 PARTIAL, 1/8 NOT TESTED**: all four Single-Node cells pass; Rocky, AlmaLinux and CentOS Stream Multi-Node have scoped evidence; Fedora Multi-Node remains untested. CentOS Stream's scoped bootstrap is documented in [`release73-centos-multinode-bootstrap.md`](release73-centos-multinode-bootstrap.md). Issue #272 stays open with `fix-proposed`: Fedora revalidation, the Rocky post-removal hub-reboot check, broader private-service reachability, and cross-OS revalidation remain outstanding. Helper-failure rollback/retry and post-removal hub-reboot/private-UI scenarios now have scoped AlmaLinux evidence.
