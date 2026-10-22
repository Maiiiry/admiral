# Admiral RC5 Release 56 candidate

## State

The coordinated six-RPM x86_64 candidate was built locally from root commit `042e578efe0470124f47c905ddf493aa335d56d0`. All six RPM `%check` stages passed. The artifacts have not been published to COPR. Fresh Fedora Rawhide and Rocky Linux 10 Single-Node guests installed the exact six RPMs and passed the targeted boot-ID recovery regression, but neither full cell is complete. Matrix completion remains **0/8**.

Release 55 remains invalidated by #256. Its guest observations are historical and are not carried forward. The Release 56 source includes the boot-ID health fencing fix.

## Exact source and CI

| Repository | Pinned commit | CI run |
|---|---|---|
| `admiral` | `042e578efe0470124f47c905ddf493aa335d56d0` | [39821103073 — success](https://github.com/admiral-project/admiral/actions/runs/39821103073) |
| `admirald` | `9b8f1299fe43d0540442b4bc05cdbe0c5f4611aa` | [39820151915 — success](https://github.com/admiral-project/admirald/actions/runs/39820151915) |
| `admiral-fleet` | `74e8b0fe3d8278c31d07638f7650b13869e81360` | [39819815054 — success](https://github.com/admiral-project/admiral-fleet/actions/runs/39819815054) |
| `admiralctl` | `49cf2428c064434c65af9a14f96975c1bb2db637` | [39796863070 — success](https://github.com/admiral-project/admiralctl/actions/runs/39796863070) |
| `admiral-flagship` | `b7325bbc71fc474a521496e593b2967e4d555ac1` | [39795263415 — success](https://github.com/admiral-project/admiral-flagship/actions/runs/39795263415) |
| `admiral-harbor` | `dd39e9a74bf658ecf6fd6e9f8bd30b2ddf82d7db` | [39795262318 — success](https://github.com/admiral-project/admiral-harbor/actions/runs/39795262318) |

Each component submodule was fetched and compared with `origin/main` before building; all five pinned SHAs matched. `python3 scripts/validate-release-refs.py` passed before and during the build.

## Build and package checks

- Build command: `make rpm-admiral`.
- Build log: local `packaging/build/validation/rc5-r56/build.log` (SHA-256 `6a1d48e6ea1f28d41ffac32eb647b2dff0448084c13a44e1f8f000be6d8ea531`).
- Six RPM `%check` stages completed successfully. The Go package checks also verify x86-64 ELF machine type; the web package suites passed (Flagship: 266 tests; Harbor: 350 tests).
- Host at preflight: Rocky Linux 10.2, x86_64, 4 vCPU, 7.5 GiB RAM, 4 GiB swap, KVM/libvirt available, SELinux enforcing. There were no active guests and 88 GiB were free on the VM filesystem.
- All four immutable 2026-10-22 seed images passed their recorded SHA-256 checks in `release54-seed-sha256.txt`.

| RPM NEVRA | SHA-256 |
|---|---|
| `admiral-common-0.0.1rc5-56.el10.noarch` | `3d5fea91db7b2a1cd3fa86665343e26dee975c0afeaf1aa3d7cb0b8d99e04962` |
| `admirald-0.0.1rc5-56.el10.x86_64` | `5bc0d36d97686b9d126b7fbc119e1149383fd4e7f23e7357df139376c9631ee4` |
| `admiral-fleet-0.0.1rc5-56.el10.x86_64` | `98b0894663067bc84b080780cf9d9bcfdca07a3a43f4b7c08765506bfe26a039` |
| `admiralctl-0.0.1rc5-56.el10.x86_64` | `16ee2bb1a00008658068bfe55bd16e2fd0eedb8c0120229241206f8d53d7743b` |
| `admiral-flagship-0.0.1rc5-56.el10.noarch` | `85406433bdfc3f106afaf7604dd4aa946004751b14d4ad6390fffd39dde16f65` |
| `admiral-harbor-0.0.1rc5-56.el10.noarch` | `fec5cf0030722793d1770dab71afecab7e14047bac7dd5656bc9093c8341ccfe` |

The same checksums are in `release56-rpm-sha256.txt`. RPMs are local build outputs under `packaging/build/RPMS/`; their hashes were rechecked against the six installed package NEVRAs before guest installation. The candidate was not uploaded to COPR.

## Remaining gates

- Fedora Rawhide and Rocky Linux 10 have partial Single-Node evidence only. AlmaLinux 10 and CentOS Stream 10 have no Release 56 guest runs. All four Multi-Node cells (three guests each) are **NOT TESTED**.
- The clean DNF dependency query against configured distribution repositories and Admiral COPR **FAILED**. With the private candidate repository disabled, Rocky exposed Flask 3.1.2 from EPEL and no COPR Flask; available Mistune was 3.1.3 from EPEL / 3.2.1 from COPR. Fedora exposed Flask 3.1.3 from Rawhide but only Mistune 3.2.1. The Harbor RPM requires Flask >=3.1.3 and Mistune >=3.3.0. The fresh seeds already had Flask 3.1.3 and Mistune 3.4.0 installed, so their successful Admiral transactions did not prove dependency closure. These repository blockers are tracked by [#201](https://github.com/admiral-project/admiral/issues/201) and [#257](https://github.com/admiral-project/admiral/issues/257).
- Targeted host reboot regression: Fedora changed boot ID and returned to available at poll 7; Rocky returned to available at poll 6. Both verified all three containers, PostgreSQL readiness, HTTP 200, the persisted SQL marker `r56-reboot-persisted`, and cleanup. Installer recaps were Fedora `ok=238 changed=99 failed=0` (685 seconds) and Rocky `ok=232 changed=97 failed=0`; host OS update actions during installation are recorded under #235. These are named scenario results, not cell passes.
- Reproducible procedure: `scripts/r56/r56-host-reboot.sh`. Raw install, dependency-query and reboot logs remain mode 0600 under `/var/lib/libvirt/images/admiral-validation/validation/rc5-r56/single/`; their SHA-256 values are in `release56-runtime-log-sha256.txt`.
- Full Single-Node lifecycle, concurrency, security, fault-injection, performance and persistence/backup coverage remains. The four three-guest Multi-Node cells remain **NOT TESTED**.
- Do not count any R55 evidence toward Release 56 or report a matrix cell as PASS until that complete cell's criteria are exercised on these exact artifacts.
