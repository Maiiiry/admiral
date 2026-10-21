# Fedora Rawhide Multi-Node same-worker isolation probe

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Candidate: Release 42 x86_64, root source `748b703662eafdaf3919bad28787d0264f06bf16`.<br>
Environment: Fedora Linux 46 Cloud Edition prerelease (Rawhide), x86_64; isolated three-guest cluster; both workloads assigned to `rc5-r42-fedora-x86-worker1` (`10.99.0.2`).<br>
Probe time: `2026-10-21T14:55:48Z`.

## Procedure

Two disposable `e2e-whoami` instances were provisioned independently on worker1:

| Instance | Provision operation | Result |
|---|---|---|
| `inst_fd72f75ff72b4cf4` | `op_b36edc584ac8574b` | succeeded `14:39:00.153Z`–`14:39:07.809Z` |
| `inst_92797293524a1531` | `op_d2b8936808ceefd8` | succeeded `14:39:08.842Z`–`14:39:15.041Z` |

The reproducible read-only probe is `scripts/fedora-same-worker-isolation.sh INSTANCE_A INSTANCE_B`. It uses rootless Podman inspection through the guest's operator account and reports only secret presence/equality, never secret values.

## Observed results

All six containers (infra, app and DB for each instance) were `Up` before deprovision. Containers belonging to each instance shared that instance's network namespace; the two instances had different network namespace inodes:

| Instance | Shared network namespace | App PID namespace | App mount namespace | App runtime settings |
|---|---|---|---|---|
| `inst_fd72f75ff72b4cf4` | `net:[4026532500]` | `pid:[4026532576]` | `mnt:[4026532578]` | `Privileged=false`, `PidMode=private`, `NoNewPrivileges` set, no explicit capability add/drop |
| `inst_92797293524a1531` | `net:[4026532579]` | `pid:[4026532652]` | `mnt:[4026532654]` | `Privileged=false`, `PidMode=private`, `NoNewPrivileges` set, no explicit capability add/drop |

Each DB container mounted only its own named persistent volume at `/var/lib/postgresql/data`; the volume names and host storage paths included their respective instance IDs and were distinct. Neither DB container had `/run/podman/podman.sock` or `/run/user/987/podman/podman.sock`. `pg_isready` on the second DB returned `accepting connections`.

Rootless Podman returned blank container IP fields for both DB containers. The probe therefore could not address the second DB from the first workload namespace, and did **not** establish a cross-workload network denial. The saved environment-only comparison also did not prove that the DB secrets differ. These checks remain open; this evidence is partial and does not establish complete workload isolation. Container inspect reported no explicit `CapDrop`, so the effective capability sets also need direct verification.

## Cleanup

Both instances were deprovisioned through `admiralctl`; both operations succeeded:

| Instance | Deprovision operation | Result |
|---|---|---|
| `inst_fd72f75ff72b4cf4` | `op_35f7b42846cb0e31` | succeeded `14:56:54.998Z`–`14:57:02.990Z` |
| `inst_92797293524a1531` | `op_e6afba7140c4d3b7` | succeeded `14:57:03.340Z`–`14:57:11.365Z` |

Direct worker inspection then found zero matching containers, zero matching Podman volumes and zero matching Quadlet files. The unrelated worker workloads were not modified.

**Status: PARTIAL** for same-worker namespace, volume and socket checks; cross-workload network denial, secret separation and effective capability verification remain **NOT TESTED**. This is one Fedora Multi-Node scenario, not a full cell pass.

Ignored raw logs are mode `0600` under `packaging/build/validation/rc5-r42/`:

| Log | SHA-256 |
|---|---|
| `audit-target-fedora-isolation-provision-a.log` | `38509fee6626f92517051a603251ebc5b8e6d25465499db2131d1ab122780e2c` |
| `audit-target-fedora-isolation-provision-b.log` | `9f67934cbeb5518c5360d19c1cab1ef6cd405172eeac9b8dd3cd3cdecaa7c6e6` |
| `audit-target-fedora-isolation.log` | `3492f80a15a80e3d5df45b8a728e47cdce20657471b7ec92e135326476b91f22` |
| `audit-target-fedora-isolation-deprovision-a.log` | `80717f20cc65a85852755cc2a5b043d2ab825759dcbeba0aed576af91d9836bd` |
| `audit-target-fedora-isolation-deprovision-b.log` | `76af6c9dfbc1fa9f940dc31da66c699fcd6db8be7df99b39922f0bdbebbc7e2f` |
| `audit-target-fedora-isolation-cleanup.log` | `ffb3f039864333dce6568f6e2f15a644b8295e32be4f2eb54ec339b598c0066b` |
