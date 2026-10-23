# R67 Fedora Rawhide Multi-Node workload placement and lifecycle

**Result: PASS for the named workload scenarios; NOT a complete Multi-Node cell.**

Test date: 2026-10-23 UTC<br>
Candidate root source commit: `833d15aa4f8e96be30d28dad169b9d06a4d9894d`<br>
Tested packages: Admiral RC5 Release 67 `.fc46`, x86_64<br>
Topology: fresh Fedora 46 hub plus two fresh workers; see
[`release67-fedora-multinode-bootstrap.md`](release67-fedora-multinode-bootstrap.md)
for image identity, node addresses, install recaps and package provenance.

This run adds workload placement, same-key replay, HTTP/SQL and cleanup evidence
to the prior bootstrap-only result. It does not cover the full Multi-Node
catalog, restart/fault recovery, concurrent mutations, cross-workload isolation,
external backup, resource exhaustion, or performance sampling. Matrix remains
**0/8**.

## Candidate and environment

The hub and both workers installed the exact Fedora-native Release 67 packages
from the local Fedora repo. Hub inventory showed all three nodes active,
healthy and available before workload tests. Workers were:

| Node | Fedora guest | WireGuard address | RPMs checked after test |
| --- | --- | --- | --- |
| W1 | `adm-r67-fedora-mn-w1` | `10.99.0.2` | `admiral-common-0.0.1rc5-67.fc46.noarch`, `admiral-fleet-0.0.1rc5-67.fc46.x86_64` |
| W2 | `adm-r67-fedora-mn-w2` | `10.99.0.3` | `admiral-common-0.0.1rc5-67.fc46.noarch`, `admiral-fleet-0.0.1rc5-67.fc46.x86_64` |

The hub retained the exact six `.fc46` NEVRAs listed in
[`release67-fedora-RPM-MANIFEST.tsv`](release67-fedora-RPM-MANIFEST.tsv). No
`.el10` package was installed. The workload definition was the repository
fixture [`examples/apps/e2e-whoami.yaml`](../../../../examples/apps/e2e-whoami.yaml):
one HTTP app container and one PostgreSQL container with a persistent volume.

## Procedure and results

The reproducible helper is
[`scripts/r67/r67-fedora-multinode-placement.sh`](../scripts/r67/r67-fedora-multinode-placement.sh).
It applies the example definition, explicitly provisions one small instance on
each worker, replays each request with its original idempotency key, inspects
runtime and API state, checks HTTP and SQL, then deprovisions and checks for
leftover containers, pods, volumes, user units and files.

| Test ID | Worker | Provision operation / instance | Observed result | Status |
| --- | --- | --- | --- | --- |
| `R67-FEDORA-MN-PLACE-W1-01` | `adm-r67-fedora-mn-w1` | `op_8a7fcf1d4a56c56e` / `inst_129469f2177e49a9` | Provision terminal state `succeeded`; API reported `running/healthy/available`; replay returned the same operation and instance. PostgreSQL became ready on poll 2; SQL marker inserted and read back; hub request to `10.99.0.2:40000` returned HTTP 200. Deprovision succeeded; no matching containers, pods, volumes, units or files remained. | **PASS, scoped** |
| `R67-FEDORA-MN-PLACE-W2-01` | `adm-r67-fedora-mn-w2` | `op_4c3f750def3d823c` / `inst_dc15afc9e4580494` | Provision terminal state `succeeded`; API reported `running/healthy/available`; replay returned the same operation and instance. PostgreSQL became ready on poll 2; SQL marker inserted and read back; hub request to `10.99.0.3:40000` returned HTTP 200. Deprovision succeeded; no matching containers, pods, volumes, units or files remained. | **PASS, scoped** |

The exact second-run evidence is in local mode-`0600` logs, excluded from Git
because they contain raw guest command output. They were scanned for private
keys, credential assignments, bearer tokens and database URLs; no matches were
found.

| Local evidence | SHA-256 |
| --- | --- |
| `packaging/build/validation/rc5-r67/fedora-mn-placement-20261023-02.log` | `216d1a2ba39c9f22c5c08f810542b13280ed70563fd79ab8557b6db74dac8d1a` |
| `packaging/build/validation/rc5-r67/fedora-mn-postcheck-placement.log` | `d13d8844a2e41211a3507ec7c2dd377d22c8720a978e11a1e6ea8f51e984e364` |

Post-check at 15:31:17 UTC found all three nodes active, healthy, available for
provisioning, and at zero active pods. The hub retained all six R67 `.fc46`
packages, and each worker retained only the expected exact R67 common/Fleet
packages. The temporary uploaded YAML was removed.

## Failed first attempt retained

The first invocation used the incorrect target node ID `fedora-r67-w1`; Admiral
returned HTTP 404 `Requested node not found` before creating an instance. The
log is preserved locally at
`packaging/build/validation/rc5-r67/fedora-mn-placement-20261023-01.log`,
mode `0600`, SHA-256
`3c8c29d3a349d2bf87ef55acd332ec3777ec6347a76d04431c4db2e4887eecbc`.
The invocation wrapper did not use `set -e`, so a later `sha256sum` made the
shell's final exit status zero despite the failed test command. That attempt is
**FAIL (test harness input/wrapper error)** and is not counted as a pass. The
node IDs were corrected to the registered IDs shown in the hub inventory, and
the successful run above used a new idempotency suffix. The corrected helper
now checks both workers' active/healthy/available inventory before changing
state and reports cleanup failures. Its current version passed `bash -n`; the
successful workload run preceded this additional preflight guard. No product
defect was found from the 404 response.

## Interpretation and remaining work

This proves that, for this Fedora Release 67 sample, the hub can target both
distinct workers, same-key sequential retries return the original operation
and instance, the workload becomes usable over WireGuard, PostgreSQL data can
be written/read, and successful deprovision removes the tested resources.
It does not prove behavior during a worker outage, concurrent update/delete,
host restart, interrupted task, secret-isolation attack, backup restore or
sustained load. No new product issue was identified; the initial failed
attempt was caused by the validation harness passing an unregistered node ID.

After preserving the logs and confirming zero active pods/resources, all three
Fedora validation guests were shut down gracefully to release host memory. The
VM definitions and overlays remain available for the next R67 scenarios; no
seed image or evidence log was deleted.
