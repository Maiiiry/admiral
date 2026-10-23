# RC5 Release 66 candidate record

Audit: `ADM-AUDIT-2026-10-21`  
Candidate: Admiral RC5 Release 66 (`0.0.1rc5-66`)  
Package-preparation root commit: `c5365da267eca6f1f5246c60a26c7875f07a5ffa`  
Current audit/documentation root commit before this evidence update: `11598a5da150d77bca9252358aaba0653334f3ec`  
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
| `admiral` current audit evidence | `11598a5da150d77bca9252358aaba0653334f3ec` | [39930943583](https://github.com/admiral-project/admiral/actions/runs/39930943583) success |

CI success is source/build evidence; it is not runtime validation.

## RPM sets

The local EL10 repository and Fedora 46 repository each contain 14 RPMs: six Admiral packages at Release 66 and eight Python helper RPMs. Both manifests list the complete NEVRA and SHA-256 for every RPM:

- [EL10 RPM manifest](release66-el10-RPM-MANIFEST.tsv)
- [Fedora RPM manifest](release66-fedora-RPM-MANIFEST.tsv)

The six Admiral package NEVRAs are `0.0.1rc5-66.el10` and `0.0.1rc5-66.fc46` respectively. The runtime guests installed the exact six candidate packages from their matching repository. EL10 includes the pinned helper set, including Flask 3.1.3, Flask-Alembic 3.3.0, Flask-Login 0.6.3, Flask-SQLAlchemy 3.1.1, Alembic 1.20.1, SQLAlchemy 2.0.55, Mistune 3.4.0 and typing-extensions 4.16.0.

## Updated seed images

Both seeds had available OS updates applied, enabled the required distribution/COPR/local repositories, and installed package requirements read from the Admiral specs. `dnf check-update` found no pending updates at seed verification.

| OS seed | Guest image | SHA-256 | Runtime use |
| --- | --- | --- | --- |
| Rocky Linux 10.2 x86_64 | `/var/lib/libvirt/images/admiral-validation/seeds/Rocky-10.2-seed-20261023-r66.x86_64.qcow2` | `64d918c2b1b8d69d210372d0e80252798178e3ae9b6b7f4af4dbec2b39b5b3d0` | Rocky Release 66 Single-Node |
| Fedora Rawhide x86_64 | `/var/lib/libvirt/images/admiral-validation/seeds/Fedora-Rawhide-seed-20261023-r66.x86_64.qcow2` | `5e79471888e5e0bbc24a1d410b8cebc054d0c459b61f970cd89018eb04cb5b7c` | Fedora Rawhide Release 66 Single-Node |

Rocky uses the explicitly documented EPEL `python3-pyOpenSSL-25.0.0-1.el10_1` seed pin to avoid the known dependency conflict. This is a lab-seed exception, not an Admiral RPM change. The lab host has 8 GiB RAM, 4 GiB swap and approximately 64 GiB free disk at this report update. Guest VMs use 2 vCPU and 2 GiB RAM. The AlmaLinux three-guest test is documented separately.

## Current release decision

The candidate artifacts and CI are verified. Runtime evidence is scoped to selected scenarios: Rocky and Fedora Rawhide Single-Node, and AlmaLinux Multi-Node. **Release matrix remains 0/8** because none of the eight cells has completed all required scenarios. See [`release66-single-node-targeted.md`](release66-single-node-targeted.md) and [`release66-alma-multinode-targeted.md`](release66-alma-multinode-targeted.md). Issue #264 remains open with `fix-proposed`; its R66 regression passed only on the AlmaLinux Multi-Node test.
