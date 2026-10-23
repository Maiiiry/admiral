# R67 Fedora Rawhide Multi-Node fresh bootstrap

**Result: PASS for the scoped fresh-bootstrap regression; NOT a complete Multi-Node cell.**

Test ID: `R67-FEDORA-MN-BOOT-01`<br>
Candidate root commit: `833d15aa4f8e96be30d28dad169b9d06a4d9894d`<br>
Source correction: root payload commit `ad4f6caa0572ebeff54d3dfcb51f635cf346b31e`<br>
Test date: 2026-10-23 UTC

This is an exact-candidate, live three-guest bootstrap test for #266. It verifies
the root cause/fix path and worker enrollment, but does not cover workload
placement, lifecycle, persistence, outage recovery, partitions, concurrency,
isolation, stress or the other seven release cells. Matrix remains **0/8**.

## Environment and candidate

Three disposable 2-vCPU/2-GiB Fedora 46 x86_64 guests were created as fresh
overlays from the updated seed
`Fedora-Rawhide-seed-20261023-r66.x86_64.qcow2`, SHA-256
`5e79471888e5e0bbc24a1d410b8cebc054d0c459b61f970cd89018eb04cb5b7c`. The seed
had already received its OS updates. The `--validation-seed` installer mode
skipped a second base-OS/security update transaction; no full OS update ran in
this test. SELinux was Enforcing on all three guests.

| Role | Guest | Underlay | WireGuard |
| --- | --- | --- | --- |
| Hub (`--admin-portal-node`) | `adm-r67-fedora-mn-hub` | `10.77.0.10` | `10.99.0.1` |
| Worker 1 | `adm-r67-fedora-mn-w1` | `10.77.0.11` | `10.99.0.2` |
| Worker 2 | `adm-r67-fedora-mn-w2` | `10.77.0.12` | `10.99.0.3` |

Each guest used the local Fedora repository at
`http://192.168.122.1/rc5-r67/fedora/x86_64/`. Its `repomd.xml` returned HTTP
200; it contains six `.fc46` Admiral RPMs and eight `.fc46` Python helper RPMs.
The full package set and SHA-256 values are recorded in
[`release67-fedora-RPM-MANIFEST.tsv`](release67-fedora-RPM-MANIFEST.tsv). DNF
installed the six exact `.fc46` Admiral RPMs on the hub through normal
dependency resolution. The installer allowed normal repo vendor selection;
the transaction did not use `--nodeps`, `--force`, or an equivalent dependency
bypass. Both workers ended with the exact Release 67 `.fc46`
`admiral-common` and `admiral-fleet` packages. An RPM inventory on each worker
found no `.el10` packages.

## Procedure and results

1. Created all guests with `scripts/create-audit-vm.sh` from the updated Fedora
   seed; the guests had fresh unique host keys and strict `known_hosts` pins.
2. Installed the exact Release 67 package set and secure admin/portal profile
   on the hub using `scripts/install-admin-portal-audit.sh`.
3. Enrolled Worker 1, then Worker 2, through the supported secure installer
   using `scripts/install-worker-audit.sh`. Each worker received the exact
   Fedora local repo config. Both bootstrap keys were temporary.
4. Queried the hub's node inventory and each guest's RPM, systemd, resolver,
   SELinux and WireGuard state after installation.

| Test ID | Procedure | Expected | Observed | Status |
| --- | --- | --- | --- | --- |
| `R67-FEDORA-MN-HUB-01` | Install fresh Fedora hub from local R67 repo and configure secure admin/portal profile | All six R67 packages install; secure install succeeds; API and core dependencies are healthy; LLMNR is disabled | DNF installed all six exact `.fc46` NEVRAs. Ansible recap: `ok=245 changed=107 unreachable=0 failed=0 skipped=135`. Installer elapsed 450 s, exit 0. `admiralctl status` returned `healthy`; `admirald`, PostgreSQL and `wg-quick@wg-admiral` were active; SELinux was Enforcing; `resolvectl` showed `-LLMNR`; no listener on port 5355. | **PASS, scoped** |
| `R67-FEDORA-MN-W1-01` | Enroll a clean Fedora worker using the supported secure installer | Baseline package precedes resolver hardening; install exits 0; exact R67 worker packages, disabled LLMNR, active Fleet, heartbeat/metrics, WireGuard peer; temporary bootstrap credential is revoked | `admiral-common` task appeared before `Disable LLMNR on Fedora secure installs`; the LLMNR verification task passed. Recap: `ok=157 changed=54 unreachable=0 failed=0 skipped=220`; installer elapsed 406 s, SSH exit 0. Hub inventory reported `active/healthy`, fresh heartbeat and metrics. Fleet active; WireGuard handshake present; LLMNR listener absent; SELinux Enforcing; no `.el10` package installed. Helper reported that the temporary bootstrap key was rejected while pinned validator access remained available. | **PASS, scoped** |
| `R67-FEDORA-MN-W2-01` | Repeat enrollment from a second clean Fedora worker | Same expected result as Worker 1; no duplicate worker identity or wrong-distro artifacts | Same task order and successful LLMNR verification. Recap: `ok=157 changed=54 unreachable=0 failed=0 skipped=220`; installer elapsed 401 s, SSH exit 0. Hub inventory reported `active/healthy`, fresh heartbeat and metrics. Fleet active; WireGuard handshake present; LLMNR listener absent; SELinux Enforcing; no `.el10` package installed. Helper reported temporary bootstrap key rejection. | **PASS, scoped** |
| `R67-FEDORA-MN-TOPOLOGY-01` | Check hub and worker records after both enrollments | One portal plus two distinct active, healthy workers; two working peer handshakes | `admiralctl nodes list` showed the hub, W1 and W2 as three distinct `active/healthy` nodes. Hub reported two non-zero WireGuard handshakes; each worker reported a handshake. | **PASS, scoped** |

The worker bootstrap playbooks logged brief `FAILED - RETRYING` samples while
polling for Fleet heartbeat and metrics (two retries observed per worker).
Each poll recovered to `ok`; the node records then showed fresh heartbeats and
metrics, and both installer commands exited 0. The retry samples are retained
and not suppressed.

## Evidence files

Raw installer logs are local, ignored, mode `0600`, and were scanned for
private-key blocks, credential assignments, bearer tokens and database URLs;
no matches were found.

| File | SHA-256 |
| --- | --- |
| `packaging/build/validation/rc5-r67/fedora-mn-hub-install.log` | `8189ddd0f20fff4b477d61b0e27c5e5504b5764ef2000ece803c0d9718317e9f` |
| `packaging/build/validation/rc5-r67/fedora-mn-w1-install.log` | `1d987250987b788357777ffb9531ba23deacce7ea3c09859c76b7b5a3723f58b` |
| `packaging/build/validation/rc5-r67/fedora-mn-w2-install.log` | `ba49cdb55b5208eb6a88628792ef85697d5724bd7a13849b877cb19ed5751c86` |

The workflow used strict host-key checking. The only credential evidence in
this report is the install helper's boolean result that each temporary
bootstrap key was rejected; key material and generated Admiral credentials
are not retained in the report.

## Interpretation

The R66 Fedora fresh-worker failure is **not reproduced** on the exact R67
candidate. Both fresh workers installed the baseline before applying the
Fedora resolver drop-in, completed the secure installer, enrolled through the
hub, reported current heartbeat/metrics, and established WireGuard handshakes.
This is scoped evidence for the #266 regression only; it does not complete a
Fedora Multi-Node cell or validate the overall production-readiness goal.
Issue #266 remains open per the audit tracking policy.
