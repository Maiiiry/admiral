# Release 52 initial Single-Node execution — invalidated

Audit: `ADM-AUDIT-2026-10-21`  
Candidate: Admiral RC5 Release 52, six exact x86_64 RPMs `0.0.1rc5-52.el10`.  
Source refs: root package preparation `c22d05ef23dce9c693af8e46bf53f3e19955979b`; `admirald` `0baf488353386fdb67f995ef3e72cfe6cfc6de07`; `admiral-fleet` `740b690fdb49e86fa63c9db2b56a1e576247b162`; `admiralctl` `5ed381d7d152e1606e78fafe332587cca09bc989`; `admiral-flagship` `3911eb784aef732f0bbe4662d1dbc6a5947eb659`; `admiral-harbor` `92c5ccac6a647cb85da36b056cb3352f391ab8c9`.  
Disposition: **INVALIDATED by HIGH finding #246. No complete matrix cell passed; matrix remains 0/8.** The positive rows below are scoped scenario results for this exact candidate, not release validation passes, and must be rerun on a new candidate after the fix.

## Lab and installation

Two fresh seed overlays ran in parallel on the isolated Rocky Linux 10.2 KVM host:

| Guest | OS snapshot | Address | Resources | Security state |
| --- | --- | --- | --- | --- |
| `adm-r52-fedora-single` | Fedora Rawhide, Fedora 46 prerelease snapshot, x86_64 | `192.168.122.252` | 2 vCPU, 2 GiB RAM | SELinux Enforcing |
| `adm-r52-rocky-single` | Rocky Linux 10.2, x86_64 | `192.168.122.253` | 2 vCPU, 2 GiB RAM | SELinux Enforcing |

Both guests used the prepared updated OS seeds, the candidate's local RPM repository, and the configured EPEL/CRB/COPR dependency repositories. No full OS update ran during the test round. Fresh-install Ansible setup completed, all six exact R52 RPMs were present, Admiral services were active, and `admiralctl status` was healthy. The unauthenticated status API returned HTTP 401. The full install logs and post-install captures remain outside Git, mode `0600`.

## Executed scenarios

| Scenario | Fedora Rawhide | Rocky Linux 10.2 | Evidence / limit |
| --- | --- | --- | --- |
| Fresh install, service status, unauthenticated API | PASS, scoped | PASS, scoped | `fedora-install.log`, `rocky-install.log`, `*-postinstall-baseline.txt`; exact RPM inventory and HTTP 401. |
| Same-key provisioning replay and actual app HTTP | PASS, scoped | PASS, scoped | Replay returned the same operation/instance IDs. Initial DB readiness briefly reported unknown/unavailable, then converged; ten HTTP requests returned 200. `*-provision-replay.log`, `*-convergence.txt`. |
| Pause, resume, deprovision and cleanup | PASS, scoped | PASS, scoped | Paused/deprovisioned instances were unavailable; resume converged to healthy/available; deprovision left no matching container, volume, user unit, or instance data/config path. Short convergence delays were recorded. |
| Restart `admirald` and `admiral-fleet` | PASS, scoped | PASS, scoped | Services returned active; instance health, HTTP 200, and expected containers recovered. |
| Host reboot recovery | PASS, scoped | PASS, scoped | Boot IDs changed. Fedora returned to available/HTTP 200 about 26 s after SSH returned; Rocky about 33 s. Temporary stale/stopped observations occurred before fresh health reports. |
| Local PostgreSQL backup and restore | PASS, scoped | PASS, scoped | Checksum-verified local backup restored a mutated marker after the required pause/restore/resume workflow. External S3 was **NOT TESTED**. |
| Declared DB service fails during provision | PASS, scoped regression for #227 | PASS, scoped regression for #227 | `/bin/false` service left the instance failed/unhealthy/unavailable; cleanup succeeded. |
| Three concurrent same-key provision requests | PASS, scoped | PASS, scoped | All callers converged to one operation and instance; exactly one customer instance and three workload containers existed; cleanup succeeded. |
| Kill app container and SIGKILL Admiral processes | PASS, scoped | PASS, scoped | Quadlet restarted the app; systemd restarted both Admiral services; workload became healthy and was cleaned up. |
| Inject Podman deletion failures and retry | PASS, scoped regression for #228 | PASS, scoped regression for #228 | Failed cleanup did not report deprovisioned while resources remained; after restoring Podman, retry removed resources. The original Podman binary hash was restored. |
| Same-host workload isolation inspection | PARTIAL; cross-workload reachability **NOT TESTED** | PARTIAL; cross-workload reachability **NOT TESTED** | Runtime inspection found non-privileged containers, `no-new-privileges`, no Podman socket mounts, distinct network namespace inodes, and loopback-only published ports. Rootless Podman exposed no DB container IP for a negative cross-workload TCP probe. This is not a full isolation pass. |
| Effective CPU and memory cgroup limits | PASS, scoped | PASS, scoped | Parent `user-libpod_pod_*slice` enforced 512 MiB / 1 CPU and the test also observed the 768 MiB resize target. Container child cgroups alone showed `max`, so the parent slice is the effective limit. |
| Resize with generated PostgreSQL credentials and data marker | **FAIL — #246** | **FAIL — #246** | Both resizes reported success and effective limits changed, but regenerated DB Quadlets omitted secret directives and containers lacked `POSTGRES_USER`/`POSTGRES_PASSWORD`. The persistent SQL marker survived when the stored Podman secrets were reattached to a temporary client. Details below. |

All scoped results above are invalidated for release readiness because the candidate produced a new HIGH defect. Unexecuted Single-Node cases include conflicting concurrent updates/deletes, request timeout/retry ambiguity, complete network/storage/config/secret lifecycle coverage, cross-workload negative reachability, external S3, resource exhaustion, broad performance percentiles, and complete scenario coverage. No Release 52 Multi-Node run was performed.

## Finding #246 reproduction

Fixture: [`../fixtures/e2e-resize.yaml`](../fixtures/e2e-resize.yaml). Reproduction script: [`../scripts/r52/r52-resize-persistence.sh`](../scripts/r52/r52-resize-persistence.sh). The script provisioned a small-tier workload, inserted a SQL marker, resized small → medium → small, checked HTTP and cgroup limits, and queried the marker again.

| Guest | Instance | Medium operation | Small operation | Observed result |
| --- | --- | --- | --- | --- |
| Fedora Rawhide | `inst_283d4a095a7819a9` | `op_bec96e5dc14fd277` | `op_9825b716435b9856` | Both succeeded; HTTP 200; post-resize DB query failed with `FATAL: role "root" does not exist`. |
| Rocky Linux 10.2 | `inst_6598976491ad5546` | `op_4dd6839051047e5f` | `op_a5bd514cbda2b958` | Both succeeded; HTTP 200; post-resize DB query failed with `FATAL: role "root" does not exist`. |

Sanitized post-resize diagnostics confirmed `POSTGRES_USER` and `POSTGRES_PASSWORD` were absent from the DB container environment and the regenerated DB unit contained zero `--secret=` directives on both guests. A temporary client container reattached the still-stored rootless Podman secrets and read marker value `persisted` on both, confirming the volume/data persisted and isolating the defect to missing secret injection. The test fixture's `whoami` app does not depend on the database, which explains why HTTP 200 did not expose the DB failure.

Root cause confirmed in `admirald/internal/api/handlers_tasks.go`: `resize_app` was neither classified as a secret-bearing action nor included when scoping persisted secret values. Fleet therefore re-rendered the Quadlet without its `Secret=` declarations. Static review found the same omission for `reactivate_app`, which uses Fleet's start/re-render path. Issue [#246](https://github.com/admiral-project/admiral/issues/246) is open and linked from master tracker [#200](https://github.com/admiral-project/admiral/issues/200). The source fix is proposed in `admirald@b4b125e`; regression tests, `go test ./...`, `go vet ./...`, and `go build ./...` passed locally. This candidate must not be used for final resize validation.

## Evidence integrity

Raw captures are retained under ignored `packaging/build/validation/rc5-r52/evidence/`, mode `0600`; the reproduction scripts and fixture are committed in the audit tree. Each hash below identifies the exact local capture. The captures contain no credential values.

| Guest | Evidence | SHA-256 |
| --- | --- | --- |
| Fedora | Install log | `5e96caa86f0c31c52f02eb0daee51ba4f91f874990040f6097ea0a9be243a02` |
| Fedora | Post-install baseline | `d1a6b39e63eea6f40b687b8ed64c748e0d77483f9f67ddedd03e51531f5d3240` |
| Fedora | Replay / convergence | `d187fbeda0d626815c8fc3765f9035b82c6cc3b52f9f81362aa8e705bae0342b` / `f924bd1721ee576753e8218193468e68462f4171072580ace72cf70c7ab90ecd` |
| Fedora | Lifecycle: pause / resume / cleanup | `583c8f79df387e55b5ab160e168b9352492f035e21b2bc97e56ad434ecbbdf0c` / `e489bbec0c176eb46ea3762e3bcf37d9e5b32256981fd1af9530838ef79eca29` / `4d3a7e38cac30057e1c32682ce583942464e7b44fd5be3e6c3ef1e6f5b99297d` |
| Fedora | Service restart / host reboot | `ed608d43af6f76053befa82c7e8ba4758fe538b6ab1493cf4cc9213144803677` / `a27dda7474d160843eeff78820056be8e2e6c921e1d3fee039db7df079c97c0d` |
| Fedora | Backup / failed service / concurrent idempotency | `e9f43295c53f584de1634916002ec02018dbd76d4a82a17e0808b318f42dd5d4` / `4a663981d014c7d70dfc757062d14be10200ca35ab638dbfb2e6b79e39d2821f` / `6edad14bccc1003b397c1e92a36d2f54b258cf98fa259d64ed28e18b2c078bd0` |
| Fedora | Process recovery / Podman failure | `fe1ad4145226fe084a111ed9a9cc5de301cf7c458fa69a2a2d317dfe7175699a` / `9d8aa765ab7fb2cd41f1d7f73d8e256c9830f8d5ad058a1592f48e71c5cab597` |
| Fedora | Isolation / cgroup / resize / confirmation | `29a754f4a88d0c61480106a472300624293859549d02f7ac108315fb69099e26` / `d63f42a8178e511c6f2b584e1080e6fde78793815f4b3cd77e99078fa4e6e789` / `299c0076d8298e79f824a9ed150c04262b0d3e337739908467d4f424ec7a0bd7` / `ee3900d1d72e2df11869717a840c92df9cd618e1cb2930ba8a4a638c2d720ba3` |
| Rocky | Install log | `4a5034ab0fe9b89898002f2ae5fad799fa5376e1fafcda3f2a9ce4b3e6b85156` |
| Rocky | Post-install baseline | `dbe8ab1237a0d725e33c2b42aff90007048879e094f621f0cfa643c38a7478fc` |
| Rocky | Replay / convergence | `75b8f79784a2af9f3e2b7c71f9277bfbcb2784a4802e01df166dbc8e44e32dbe` / `f80842b7f2bebdc00e56be482beb1c0e7016cf4c64e14598240fcf7da9aafe1f` |
| Rocky | Lifecycle: pause / resume / cleanup | `7aeb453469efea4f0a7f289a93416960c38179eace1d91cf6685c74a56085996` / `311f447c9db5d1286391258f26da4842b45b3adfe1066fc0fd59fb35351176c2` / `baf873bfa6a40e1d9e3b848b915a3e8032cb7cc5391397d0ca348573675ea743` |
| Rocky | Service restart / host reboot | `2b6d8bcff1726e5f1399bec5f1507ff93ad48f2264fe40c576b14d4aaff2e3d1` / `87b394df9a15d3e726709bc17342b002022433a65c52a5d922718bf50e46111e` |
| Rocky | Backup / failed service / concurrent idempotency | `040887941edc56cb23e2425e07d12182f6f1452fb8795b5925485f3eb5a643e1` / `fdfff144fe3edf1a0e74c7030ab9b78870aaf521b9357d5fe4fd7416a9d29433` / `5da7c4f90e4084a2cab6bfa511215a45f6b4468396410e778f14ae16edd967b4` |
| Rocky | Process recovery / Podman failure | `264410fc5937c592274b33de7eac79c32040a9833d83285bb5a02960a04dbcdb` / `4f17c8a7dda0eb8b4e293649344eee4dc6112acbf1612b43aa7f6689ac73587d` |
| Rocky | Isolation / cgroup / resize / confirmation | `f31312a3e6cc4dc9255bf3b0b65ffefb750b489e0d6b3945d8446749c5016f6e` / `11a5e680be5f062cd72fe8a5493f0f08bc204eadf2f8fedbb836cdbbba8f6757` / `55bf70b28997c9c40a4804f262bfe5a6489f08dee888b27652618ce9259e9379` / `8e69d5a1b271c90de8923a8482c627387cff6c4408d05000d0a7f6e9cc68dee6` |

After preserving the captures, both invalidated R52 guests were shut down and removed with `scripts/cleanup-audit-vm.sh`. Only their overlays, cloud-init artifacts and DHCP reservations were deleted; the shared updated seeds were preserved. Host free disk rose from 86 GiB to 89 GiB. The mode-0600 cleanup record is `packaging/build/validation/rc5-r52/evidence/r52-vm-cleanup.txt`, SHA-256 `f1b8ff19ddefbcf17b2ec105fb3c6ba2aa8e37950fdfdb8b124a3cbfec9daa94`.

