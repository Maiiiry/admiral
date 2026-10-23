# RC5 Release 66 candidate record

Audit: `ADM-AUDIT-2026-10-21`
Candidate: Admiral RC5 Release 66 (`0.0.1rc5-66`)
Package-preparation root commit: `c5365da267eca6f1f5246c60a26c7875f07a5ffa`
Audit evidence baseline root commit: `288f906119d4639653978c6843afab1fb1708ad5`
Scope: x86_64 only; EL10 and Fedora Rawhide package builds.

## Component pins and CI

All five Git submodules are pinned to the following exact commits in the R66 package-preparation commit. Root package validation passed with `python3 scripts/validate-release-refs.py` before the build.

| Repository | Commit | CI result |
| --- | --- | --- |
| `admiral` package preparation | `c5365da267eca6f1f5246c60a26c7875f07a5ffa` | [39916175033](https://github.com/admiral-project/admiral/actions/runs/39916175033) success |
| `admirald` | `643d203576037a12eba59d534d51d170acae9b5d` | [39916850987](https://github.com/admiral-project/admirald/actions/runs/39916850987) success |
| `admiral-fleet` | `0c805d6293bfb11fd4f015f1b0ccff520481e627` | [39878457179](https://github.com/admiral-project/admiral-fleet/actions/runs/39878457179) success |
| `admiralctl` | `49cf2428c064434c65af9a14f96975c1bb2db637` | [39796863070](https://github.com/admiral-project/admiralctl/actions/runs/39796863070) success |
| `admiral-flagship` | `b7325bbc71fc474a521496e593b2967e4d555ac1` | [39795263415](https://github.com/admiral-project/admiral-flagship/actions/runs/39795263415) success |
| `admiral-harbor` | `dd39e9a74bf658ecf6fd6e9f8bd30b2ddf82d7db` | [39795262318](https://github.com/admiral-project/admiral-harbor/actions/runs/39795262318) success |
| `admiral` current audit evidence | `288f906119d4639653978c6843afab1fb1708ad5` | [39938396376](https://github.com/admiral-project/admiral/actions/runs/39938396376) success |

CI success is source/build evidence; it is not runtime validation.

## RPM sets

The local EL10 repository and Fedora 46 repository each contain 14 RPMs: six Admiral packages at Release 66 and eight Python helper RPMs. Both manifests list the complete NEVRA and SHA-256 for every RPM:

- [EL10 RPM manifest](release66-el10-RPM-MANIFEST.tsv)
- [Fedora RPM manifest](release66-fedora-RPM-MANIFEST.tsv)

The six Admiral package NEVRAs are `0.0.1rc5-66.el10` and `0.0.1rc5-66.fc46` respectively. The runtime guests installed the exact six candidate packages from their matching repository. EL10 includes the pinned helper set, including Flask 3.1.3, Flask-Alembic 3.3.0, Flask-Login 0.6.3, Flask-SQLAlchemy 3.1.1, Alembic 1.20.1, SQLAlchemy 2.0.55, Mistune 3.4.0 and typing-extensions 4.16.0.

## Updated seed images

All four R66 seeds had available OS updates applied, enabled the required distribution/COPR/local repositories, and installed package requirements read from the Admiral specs. An independent `dnf check-update` returned 0 on each newly refreshed EL10 seed. The four QCOW2 images passed `qemu-img check` after flattening. This establishes reusable, updated test bases; it is not runtime validation of Admiral.

| OS seed | Guest image | SHA-256 | Runtime use |
| --- | --- | --- | --- |
| Rocky Linux 10.2 x86_64 | `/var/lib/libvirt/images/admiral-validation/seeds/Rocky-10.2-seed-20261023-r66.x86_64.qcow2` | `64d918c2b1b8d69d210372d0e80252798178e3ae9b6b7f4af4dbec2b39b5b3d0` | Rocky Release 66 Single-Node |
| Fedora Rawhide x86_64 | `/var/lib/libvirt/images/admiral-validation/seeds/Fedora-Rawhide-seed-20261023-r66.x86_64.qcow2` | `5e79471888e5e0bbc24a1d410b8cebc054d0c459b61f970cd89018eb04cb5b7c` | Fedora Rawhide Release 66 Single-Node |
| AlmaLinux 10.2 x86_64 | `/var/lib/libvirt/images/admiral-validation/seeds/AlmaLinux-10.2-seed-20261023-r66.x86_64.qcow2` | `bcec85910c4ed224d967eb0f696a08af5b24e60d6c3547252bce9dc0a0f02118` | R66 Single-Node and three-guest Multi-Node targeted scenarios; neither cell complete |
| CentOS Stream 10 x86_64 | `/var/lib/libvirt/images/admiral-validation/seeds/CentOS-Stream-10-seed-20261023-r66.x86_64.qcow2` | `2cbea69dd6f99334decc0c89441f54d7d78f1e6370e2ecd7771e9cc51096bf68` | R66 Single-Node and three-guest Multi-Node targeted scenarios; neither cell complete |

Rocky uses the explicitly documented EPEL `python3-pyOpenSSL-25.0.0-1.el10_1` seed pin to avoid the known dependency conflict. This is a lab-seed exception, not an Admiral RPM change. All four seeds have EPEL, CRB (where applicable), Admiral COPR and the local R66 validation repo enabled. The AlmaLinux and CentOS Stream preparation logs and independent final checks are retained in the mode-0600 ignored local directory `packaging/build/validation/rc5-r66/`; SHA-256 values are `8943760b32787765f49fb6d68aba70428ed19dcbf66a96ecb9e2a378e2a6cc2a` (`alma-seed-refresh.log`), `db85311af9ba61427b104ba759d9acc7634c62c4c80e24a36cb6a00ee66fc279` (`centos-seed-refresh.log`) and `9f5b5dfa7c97cf515dabffb6dc5307c8d10b7391776fde005a9205b994272351` (`centos-seed-final-check.log`). The lab host has 8 GiB RAM, 4 GiB swap and 55 GiB free disk at the latest check. The current CentOS Stream Multi-Node topology uses three 2-vCPU/2-GiB guests; its R66 results are in `release66-centos-multinode-targeted.md`.

## Current release decision

The candidate artifacts and selected CI runs are verified. Runtime evidence is scoped: all four operating systems have Single-Node samples; AlmaLinux and CentOS Stream have three-guest Multi-Node samples. Rocky Linux and Fedora Rawhide Multi-Node have no R66 execution. **Release matrix remains 0/8** because none of the eight cells has completed all required scenarios. Targeted #227 failure handling passed in all four Single-Node guests and on the AlmaLinux/CentOS Multi-Node workers. Targeted #228 deprovision-retry regression passed in AlmaLinux and CentOS Multi-Node. Same-key concurrent provision replay passed in CentOS Multi-Node. The #264 central PostgreSQL outage regression passed on both EL10 Multi-Node labs; CentOS W2 also recovered from a guest reboot and a WireGuard partition with its workload SQL marker intact. The hub reboot/peer-recovery scenario passed on AlmaLinux and CentOS Stream; Rocky/Fedora still lack R66 Multi-Node recovery tests. Issues remain open for broader matrix review. See [`release66-single-node-targeted.md`](release66-single-node-targeted.md), [`release66-el10-single-node-targeted.md`](release66-el10-single-node-targeted.md), [`release66-alma-multinode-targeted.md`](release66-alma-multinode-targeted.md) and [`release66-centos-multinode-targeted.md`](release66-centos-multinode-targeted.md).
