# Admiral Release 51 candidate build record

Audit: `ADM-AUDIT-2026-10-21`
Candidate: Admiral RC5 Release 51, x86_64 RPM build.
Build result: **six coordinated Admiral RPMs built with all six `%check` stages passing, staged in isolated EL10 and Fedora Rawhide repositories, and queried from both endpoints.** Two fresh Single-Node guests installed R51. Fedora lifecycle testing exposed #245, invalidating the candidate; no result counts as a matrix pass and completion remains **0/8**. Runtime detail and raw-log hashes are in [`release51-initial-lifecycle.md`](release51-initial-lifecycle.md).

Build ran 2026-10-22 05:20:38–05:25:20 UTC on the Rocky Linux 10.2 lab host. Preflight recorded 4 vCPU, 8 GiB RAM, 4 GiB swap, KVM available, SELinux enforcing, no active guests, and 89 GiB free disk. Disk remained at 89 GiB after the build and staging.

## Source and CI identity

The package-preparation commit is root `59e6eeb553ac38d7fa995863202a1180f50c02c5`; its root CI passed in [run 39727420397](https://github.com/admiral-project/admiral/actions/runs/39727420397). All six Admiral spec files use `Release: 51`. Before building, root and all five component repositories were fetched and compared against `origin/main`:

| Component | Exact source SHA | `origin/main` at build | GitHub CI |
| --- | --- | --- | --- |
| `admirald` | `d50523f7a75b0a1606c761423de9d1cdc844425e` | same | [run 39711773654](https://github.com/admiral-project/admirald/actions/runs/39711773654) — success |
| `admiral-fleet` | `740b690fdb49e86fa63c9db2b56a1e576247b162` | same | [run 39663860552](https://github.com/admiral-project/admiral-fleet/actions/runs/39663860552) — success |
| `admiralctl` | `5ed381d7d152e1606e78fafe332587cca09bc989` | same | [run 39724553667](https://github.com/admiral-project/admiralctl/actions/runs/39724553667) — success |
| `admiral-flagship` | `3911eb784aef732f0bbe4662d1dbc6a5947eb659` | same | [run 39654771764](https://github.com/admiral-project/admiral-flagship/actions/runs/39654771764) — success |
| `admiral-harbor` | `92c5ccac6a647cb85da36b056cb3352f391ab8c9` | same | [run 39705906726](https://github.com/admiral-project/admiral-harbor/actions/runs/39705906726) — success |
| `admiral-common` source | `012a571f3ffb2f4bfc58eed82c5778a92d07314c` | root `main` was package-prep commit `59e6eeb` | [run 39727055542](https://github.com/admiral-project/admiral/actions/runs/39727055542) — success |

The root common source pin intentionally selects `012a571`, which contains the #244 common RPM `%check` fix. Newer root `main` commit `59e6eeb` is the coordinated release-preparation commit; the packaged installer/Ansible payload matches the pinned source exactly, as verified by `python3 scripts/validate-release-refs.py`. That validator passed before and during the build. This preserves the exact source fix while the package-preparation commit updates release metadata and audit helpers.

## Build and checks

Build command:

```bash
GOTOOLCHAIN=auto make rpm-admiral RPM_ARCH=x86_64 RPMFLAGS="--target x86_64 --define '_topdir /root/admiral/packaging/build' --define '_sourcedir /root/admiral/packaging/build/SOURCES' --define '_specdir /root/admiral/packaging/build/SPECS' --define '_builddir /root/admiral/packaging/build/BUILD' --define '_rpmdir /root/admiral/packaging/build/RPMS' --define '_srcrpmdir /root/admiral/packaging/build/SRPMS' --define '_tmppath /root/admiral/packaging/build/tmp' --nodeps"
```

The build log contains six `Executing(%check)` sections and ends with `=== All 6 Admiral RPMs built ===`. The new common-package `%check` executed `bash -n` on four staged shell scripts and compiled five staged Python scripts in memory; it completed with `RPM_EC=0`. Flagship passed 266 tests and Harbor passed 350 tests with 307 deprecation warnings tracked in #242. The three Go package checks completed for the pinned component sources; their results were cached in this build and those exact sources had already passed the local suites and green component CI listed above. The root audit suite passed 118/118 before the build. No `--nocheck` flag was used.

The host provides Go 1.26.7 while RPM `BuildRequires` expects at least 1.26.10, so `--nodeps` bypassed that host package gate; `GOTOOLCHAIN=auto` was enabled. This does not suppress `%check`. The restricted build log is retained outside Git at `packaging/build/validation/rc5-r51/build.log`, mode `0600`, SHA-256 `9e01c0ff4cf8443233799cd5be69eecfe0ca7d06ed1c610ffcd437b899e530fe`. The generic `find-debuginfo` helper emitted a non-fatal missing `debug` directory message for the no-binary common package; `rpmbuild` and all package checks continued successfully.

## Exact RPMs

| NEVRA | SHA-256 |
| --- | --- |
| `admiral-common-0.0.1rc5-51.el10.noarch` | `fc30bb6ba8e98f6331953b5eede4471fc87a6388c6db0118d044f40203d90430` |
| `admirald-0.0.1rc5-51.el10.x86_64` | `ab6d66618e2645688059d0b1653136567d18e1f7281259ff1f41b67cf5af2549` |
| `admiral-fleet-0.0.1rc5-51.el10.x86_64` | `b3a7e4f01b33211e7efdb5cd344b5ca8f8e424c47ad6dea9d6116ee02f16f70c` |
| `admiralctl-0.0.1rc5-51.el10.x86_64` | `f2644900c5e2b1311bf8d1adcb2df653dbf14eeaed518a0e580717634b1b4d43` |
| `admiral-flagship-0.0.1rc5-51.el10.noarch` | `723c2dbf64b2b875a5753ff8b576d2143390cebc23538383c842787991739132` |
| `admiral-harbor-0.0.1rc5-51.el10.noarch` | `3dfdd2d903f123b9d677c1f090e2c4a24a0fb7b7222217b220f4666218f7730e` |

Machine-readable hashes are in [`release51-rpm-sha256.txt`](release51-rpm-sha256.txt). The local R51 repositories each contain 13 RPMs: six Admiral packages and seven Python support packages. EL10 `repomd.xml` at `http://192.168.122.1/rc5-r51/el10/x86_64/repodata/repomd.xml` and Fedora Rawhide `repomd.xml` at `http://192.168.122.1/rc5-r51/fedora/x86_64/repodata/repomd.xml` both returned HTTP 200. DNF repoquery returned exactly the same six R51 NEVRAs from both endpoints. Repository checksums and `.repo` files are retained under ignored `packaging/build/validation/rc5-r51/`.

## Runtime matrix status

Release 51 was eligible for runtime testing after the #244 package-check gap was corrected and verified in `%check`, but the Fedora lifecycle probe exposed #245: `effective_availability` remained `available` when the instance was stopped or deprovisioned. R51 is **INVALIDATED**; no matrix cell passed. The fix is pushed as `admirald@0baf488` with green CI and is included in the coordinated Release 52 RPM set. R52 build and repository evidence are recorded in [`release52-candidate.md`](release52-candidate.md); use fresh overlays from the preserved updated seeds, and do not carry R51 observations into a matrix cell.
