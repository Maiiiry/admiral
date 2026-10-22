# Release 53 follow-up Single-Node execution — AlmaLinux and CentOS Stream

Audit: `ADM-AUDIT-2026-10-21`
Candidate: RC5 Release 53 x86_64 RPMs, package-preparation commit [`e149571`](https://github.com/admiral-project/admiral/commit/e149571e6124d1e4223f2c868a2a1c1f685f8d58). Exact NEVRAs, source refs and RPM checksums: [`release53-candidate.md`](release53-candidate.md).
Disposition: **targeted Single-Node scenarios passed on fresh AlmaLinux 10.2 and CentOS Stream 10 guests; neither cell is complete. Release matrix remains 0/8.** These results do not change the candidate or establish production readiness.

## Lab and installation

Fresh 2-vCPU / 2-GiB libvirt overlays were created from the updated 2026-10-22 seeds on the isolated Rocky Linux 10.2 KVM host (4 vCPU, 8 GiB RAM, 4 GiB swap). The R53 local repository served the exact six `0.0.1rc5-53.el10` NEVRAs. DHCP lease verification matched the guest MACs before either helper reported success.

| Guest | Reported OS | Address | Seed | Installer result |
| --- | --- | --- | --- | --- |
| `adm-r53-alma-single` | AlmaLinux 10.2 (Lavender Lion), x86_64 | `192.168.122.250` | `AlmaLinux-10.2-seed-20261022.x86_64.qcow2` | `ok=232 changed=97 unreachable=0 failed=0`; 13:05:19–13:14:59 UTC |
| `adm-r53-centos-single` | CentOS Stream 10 (Coughlan), x86_64 | `192.168.122.251` | `CentOS-Stream-10-seed-20261022.x86_64.qcow2` | `ok=231 changed=97 unreachable=0 failed=0`; 13:05:20–13:14:46 UTC |

Both guests reported SELinux enforcing, rootless Podman enabled, all six exact R53 packages installed, and `admirald`, Fleet, Harbor and Flagship active. The audit installer and resulting baseline are captured in mode-0600 raw files; hashes appear below. These are installation subsets, not cell passes.

## Scenario results

All guest-side R53 scenario helpers require root because the secure installer places the administrator CLI configuration at `/root/.config/admiralctl/config.yaml`. Invoke them through `sudo -n bash`; their output does not need or accept a token argument.

| Test ID | Guest | Procedure and observed result | Status |
| --- | --- | --- | --- |
| `R53-ALMA-SN-IDEMP` | AlmaLinux 10.2 x86_64 / Single-Node | Three simultaneous same-key requests returned operation `op_87bb84f573e232cc` and instance `inst_7915a7ca133423cc`; one instance/three containers were observed; deprovision left no matching resources. | **PASS — same-key replay only** |
| `R53-CENTOS-SN-IDEMP` | CentOS Stream 10 x86_64 / Single-Node | All three requests returned `op_ae33eebb290733cf` and `inst_92f4cff31c31a005`; one instance/three containers; cleanup left no matching resources. | **PASS — same-key replay only** |
| `R53-ALMA-SN-246` | AlmaLinux 10.2 x86_64 / Single-Node | Instance `inst_da6efbbfd5ad31ff`: small→medium→small, HTTP 200 at each tier, 512/768-MiB memory limits and one CPU; SQL marker survived resize and pause/reactivation. Operations: medium `op_c325bd6bafba2e87`, small `op_cc04f1455a7ec4fa`, pause `op_4b6bf8cc89a9b0e8`, reactivate `op_3aa970c21b10d315`, cleanup `op_fb706f7c8191e6a7`. | **PASS — targeted #246 regression only** |
| `R53-CENTOS-SN-246` | CentOS Stream 10 x86_64 / Single-Node | Instance `inst_25a60114d7624add`: both resize directions returned HTTP 200 with expected 512/768-MiB limits and one CPU; SQL marker survived resize/reactivation. Operations: medium `op_4000fefcd5fcd917`, small `op_7c60dd46f54baea7`, pause `op_f3b12503782e92f9`, reactivate `op_c9c05298837ba3ee`, cleanup `op_87b50cdba82fe04d`. The health report remained stopped/unavailable for five polls after reactivation, then converged on poll 6. | **PASS — targeted #246 regression only** |
| `R53-ALMA-SN-BACKUP` | AlmaLinux 10.2 x86_64 / Single-Node | Local PostgreSQL backup `bk_11b36302f5be8470` for instance `inst_d13ddeadf6998063`; restore completed and recovered the original SQL marker after mutation. Restore precondition while running was rejected; backup and instance were removed. | **PASS — local database only; S3 and volume backup not tested** |
| `R53-CENTOS-SN-BACKUP` | CentOS Stream 10 x86_64 / Single-Node | Local PostgreSQL backup `bk_ad9886c8aa9033dc` for instance `inst_14e8d2ad8009ea6a`; restore returned the original marker and cleanup removed backup/instance. | **PASS — local database only** |
| `R53-ALMA-SN-FAILDB` | AlmaLinux 10.2 x86_64 / Single-Node | Required DB service failure produced terminal operation `op_1139ed318ab5dc42` / instance `inst_0d27a9078f6391dc` in failed, unhealthy/unavailable state; cleanup operation `op_07a31891614637e1` succeeded. | **PASS — targeted failure-state behavior** |
| `R53-CENTOS-SN-FAILDB` | CentOS Stream 10 x86_64 / Single-Node | Required DB service failure produced terminal operation `op_075a93e77ba180fb` / instance `inst_4c0a8e7af5e0525e` in failed, unhealthy/unavailable state; cleanup operation `op_f2004d7fca54c5e3` succeeded. | **PASS — targeted failure-state behavior** |
| `R53-ALMA-SN-RECOVERY` | AlmaLinux 10.2 x86_64 / Single-Node | App process kill restarted its unit and restored HTTP 200. `admirald` and Fleet SIGKILL/restart left one provision operation, restored healthy/available state and HTTP 200; cleanup succeeded. Instance `inst_ef21364c6c64569c`; provision `op_4e96de8ad5cb4e9d`. | **PASS — selected process recovery; no active task during daemon kills** |
| `R53-CENTOS-SN-RECOVERY` | CentOS Stream 10 x86_64 / Single-Node | App unit restart restored HTTP 200. `admirald` and Fleet SIGKILL/restart left one provision operation and restored healthy/available state; cleanup succeeded. Instance `inst_aa02c81967040dc5`; provision `op_5f5a280e6f4226d5`. | **PASS — selected process recovery; no active task during daemon kills** |
| `R53-ALMA-SN-ISO` | AlmaLinux 10.2 x86_64 / Single-Node | Two workloads had distinct PID/network namespaces; inspected containers were non-privileged, `NoNewPrivs`, with no Podman socket mount; both cleaned up. Rootless Podman exposed no target DB IP, so direct cross-workload TCP denial was not run. | **PARTIAL — network denial NOT TESTED** |
| `R53-CENTOS-SN-ISO` | CentOS Stream 10 x86_64 / Single-Node | Same namespace, privilege and socket checks passed and both workloads were removed. No target DB IP was exposed; direct cross-workload TCP denial was not run. | **PARTIAL — network denial NOT TESTED** |
| `R53-ALMA-SN-REBOOT` | AlmaLinux 10.2 x86_64 / Single-Node | Boot ID changed `11a4f5d5-dc38-4664-bded-8b3279f6dab3`→`e048d0e4-ca5e-49e7-b61d-72da560af127`. API remained stopped/unavailable until poll 7; then PostgreSQL readiness, HTTP 200 and SQL marker `r53-reboot-persisted` passed. Instance `inst_db213c514cb312f9`; cleanup succeeded. | **PASS — targeted guest reboot only** |
| `R53-CENTOS-SN-REBOOT` | CentOS Stream 10 x86_64 / Single-Node | Boot ID changed `82b07f88-429e-48e2-a041-fbf5a73b8d3f`→`35014e47-4976-4a9b-9b75-05d9bb22c9c4`. API remained stopped/unavailable until poll 6; then PostgreSQL readiness, HTTP 200 and SQL marker passed. Instance `inst_4848811c0bd9b254`; cleanup succeeded. | **PASS — targeted guest reboot only** |

The Fedora/Rocky initial R53 report contains their corresponding named scenarios. Across all four distributions, no complete Single-Node cell has passed. No R53 Multi-Node topology has run.

## Harness invocation failure and correction

The first AlmaLinux and CentOS idempotency invocations ran as `validator`. Both stopped before `apps apply` could mutate state with `no authentication token configured`; the root-only CLI configuration was not visible to that user. The exact failed invocation is preserved in `alma-single-idempotency.log` and `centos-single-idempotency.log`. Re-running through `sudo -n bash` passed on both guests. This was a harness/runbook context error, not an Admiral failure, and is tracked in open issue [#249](https://github.com/admiral-project/admiral/issues/249). The R53 runbook now states the required root context and gives a token-free invocation example.

## Restricted raw evidence hashes

All files below remain in ignored `packaging/build/validation/rc5-r53/evidence/` with mode `0600`; a credential-pattern scan found no private-key blocks, credentials, bearer values or known token prefixes.

| Artifact | SHA-256 |
| --- | --- |
| AlmaLinux installer log | `eb7eb3b301b33cbd947c102b32d0bdf3084a9a258d501b83346a2dd39095109f` |
| CentOS Stream installer log | `4251ee12eb6843ea47558f9c9248da62cc0d242541466ba35fadfe8ed2ba175d` |
| AlmaLinux baseline | `4f4e41d5c476b202e37ccb1a228a76dc10337616c1f79c32c82a3057c3962db9` |
| CentOS Stream baseline | `3d9c13f280909cbfe57f887db20064fbc5dda5c86c290e2869c8bc4afc3a953c` |
| AlmaLinux failed non-root invocation | `0d9fe5e5eaa303f0a8d61aab9cea19e77bdc68585fbf262497b70349ff8c56ef` |
| CentOS failed non-root invocation | `eae19ed184518aeffc61a5433f7a14c41e3d26a606ce4b96bfe8ba0d7f9b8386` |
| AlmaLinux idempotency | `77c6e8d8eda1a91f59e788705261ce181214c7c2be07f311f6348da29d11119b` |
| CentOS Stream idempotency | `eb8cdf7ded9748e881c97bbe2581321a1dedfee1a6515cf846aed469fefd1323` |
| AlmaLinux resize/reactivation | `9fc0bdd1c6ab46e69481291bd63a129a9be257715bdb0786048d57a0421a7928` |
| CentOS Stream resize/reactivation | `e6dded6379aeb5e68edf776e55881fa48cad970231a6336d27bde6aaa2281bf0` |
| AlmaLinux backup/restore | `c68a43771523d68013dc2fbfbd16977ed2ee9606a29708b798ff9da4640c8422` |
| CentOS Stream backup/restore | `e6d82349638fe5ba7eff0f42579fa3d71f87da27a87b1ffed926ae8c13c7eb69` |
| AlmaLinux failed-service injection | `351b359c8e9a593dcc4381712f448e5a6edd1a44f9284aacb0c029a66ba21b12` |
| CentOS Stream failed-service injection | `e5934a0c44e64f7181f465fb1a5a2601f91b5e2a3d7cad0cdd84bb72fc9bb7c6` |
| AlmaLinux process recovery | `833f952269a6f22ec1382a7cd2c5823ce41312b3f8082eaac8385f11e437571a` |
| CentOS Stream process recovery | `40392baa05614901c9a7f4cd7a75b2fde2980e0852c3610743e7f81fdef342e1` |
| AlmaLinux isolation sample | `27d448ad74936fad086b7f33bc8f4c3e466d933304450a46a60dd6d43af2adb9` |
| CentOS Stream isolation sample | `62f57adfccb6def723acae530ea15525ebc307173e436d1b5b3ecbeae0241d01` |
| AlmaLinux host reboot | `5d742c35a747c04c8942f4bc6b8c18f2d7403165c86cb36d59add5adeeb99359` |
| CentOS Stream host reboot | `13b2bf422fa630b5176579a90b23fe91d92c11731aa5e7b62d7f19cd508be2aa` |

## Remaining scope

These targeted results do not complete either OS cell. Broader update/delete lifecycle, conflicting-operation and timeout-retry concurrency, cross-workload network/storage/secret negatives, Podman/systemd daemon failure, resource pressure, external storage backup, performance percentiles and additional security negatives remain outstanding. All four R53 Multi-Node cells still need fresh three-guest topologies. Matrix remains **0/8**, both production-readiness decisions remain **NOT VALIDATED**, and no issue was closed.
