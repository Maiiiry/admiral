# Admiral Release 50 build record — superseded before VM testing

Audit: `ADM-AUDIT-2026-10-21`
Candidate: Admiral RC5 Release 50, x86_64 RPM build.
Build result: **six RPMs built and staged in both isolated local repositories**. No VM installed R50 and no R50 runtime evidence was collected. A build review found that `admiral-common.spec` had no package `%check`; issue [#244](https://github.com/admiral-project/admiral/issues/244) was opened, and R50 was superseded before starting the matrix. Matrix completion remains **0/8**.

Build ran 2026-10-22 05:07:47–05:12:55 UTC on the Rocky Linux 10.2 x86_64 lab host. No VM was running. Disk availability was 89 GiB before the build and remained 89 GiB afterward.

## Source and CI identity

The package-preparation commit was root `fa5d5850dedebb00b8a3c99368fba33e81d72bef`; root CI [39726163045](https://github.com/admiral-project/admiral/actions/runs/39726163045) passed. All six RPM specs were Release 50. The `admiral-common` source archive was pinned to root `54d4a6b2e3843cb22f33526c198b32e4ac8e53bf`, containing the #239 SSH host-key pin fix. The five component submodules matched their fetched `origin/main` at build preparation:

| Component | Exact source SHA | GitHub CI |
| --- | --- | --- |
| `admirald` | `d50523f7a75b0a1606c761423de9d1cdc844425e` | [run 39711773654](https://github.com/admiral-project/admirald/actions/runs/39711773654) — success |
| `admiral-fleet` | `740b690fdb49e86fa63c9db2b56a1e576247b162` | [run 39663860552](https://github.com/admiral-project/admiral-fleet/actions/runs/39663860552) — success |
| `admiralctl` | `5ed381d7d152e1606e78fafe332587cca09bc989` | [run 39724553667](https://github.com/admiral-project/admiralctl/actions/runs/39724553667) — success |
| `admiral-flagship` | `3911eb784aef732f0bbe4662d1dbc6a5947eb659` | [run 39654771764](https://github.com/admiral-project/admiral-flagship/actions/runs/39654771764) — success |
| `admiral-harbor` | `92c5ccac6a647cb85da36b056cb3352f391ab8c9` | [run 39705906726](https://github.com/admiral-project/admiral-harbor/actions/runs/39705906726) — success |

The root #239 fix commit `54d4a6b` passed CI in [run 39726030742](https://github.com/admiral-project/admiral/actions/runs/39726030742). The later `fa5d585` package-preparation commit changed release references and audit documentation; `scripts/validate-release-refs.py` confirmed the packaged common installer/Ansible payload was identical to `54d4a6b`.

## Build and checks

Build command:

```bash
GOTOOLCHAIN=auto make rpm-admiral RPM_ARCH=x86_64 RPMFLAGS="--target x86_64 --define '_topdir /root/admiral/packaging/build' --define '_sourcedir /root/admiral/packaging/build/SOURCES' --define '_specdir /root/admiral/packaging/build/SPECS' --define '_builddir /root/admiral/packaging/build/BUILD' --define '_rpmdir /root/admiral/packaging/build/RPMS' --define '_srcrpmdir /root/admiral/packaging/build/SRPMS' --define '_tmppath /root/admiral/packaging/build/tmp' --nodeps"
```

The build log ended with `=== All 6 Admiral RPMs built ===`; `rpm -qp` reported the six expected R50 NEVRAs. `%check` ran for five packages: the three Go components, Flagship (266 passed) and Harbor (350 passed, 307 deprecation warnings). The Go test outputs were cached for unchanged pinned component sources; those exact component suites had already been run locally and their CI runs are listed above. `admiral-common.spec` had no `%check` section, which is the LOW coverage issue #244. `--nodeps` bypassed the host's unmet Go `BuildRequires`; `GOTOOLCHAIN=auto` was set and no `--nocheck` flag was used.

The restricted raw build log is retained outside Git at `packaging/build/validation/rc5-r50/build.log` with mode `0600`; SHA-256: `4d456ca97ac408141d9d680704bff7b72e1d1d9424434db246ae1d8a136f47db`. `scripts/validate-release-refs.py` passed during the build. The root audit suite passed 118/118; the #239 host-key bootstrap checks passed 5/5 and strict SSH integration passed on fresh Fedora Rawhide and Rocky Linux 10.2 guests. Those harness guests did not install an RPM and do not count as matrix cells.

## Exact RPMs

| NEVRA | SHA-256 |
| --- | --- |
| `admiral-common-0.0.1rc5-50.el10.noarch` | `590f7da4b3ca3bb2531210575f27de9bd69e8546b613ee46a863825e6de28e04` |
| `admirald-0.0.1rc5-50.el10.x86_64` | `1221e112e3eae33067ff9baa0be814d7a9aca00d2b0a7149cc584f597ddb3bd1` |
| `admiral-fleet-0.0.1rc5-50.el10.x86_64` | `3815fbbf0c3002b6911f13e1793a6052b37fdecb8ea0e8a2131ba31fc992c943` |
| `admiralctl-0.0.1rc5-50.el10.x86_64` | `23f10c5892f062c81ba1146015a01c20d8d9b46660035ba0d1e45efdc059f4ac` |
| `admiral-flagship-0.0.1rc5-50.el10.noarch` | `770f865505d94022d3513ff506855b6afde5ff596aada9068e1d0c070930d79b` |
| `admiral-harbor-0.0.1rc5-50.el10.noarch` | `56e92bff726aa3074ec6fc9019b44fe74b4230a88c37e14f8fc5ff85e50cf631` |

Machine-readable hashes are in [`release50-rpm-sha256.txt`](release50-rpm-sha256.txt). The isolated repository contained 13 RPMs per distribution: six Admiral packages and seven Python support packages. `repomd.xml` returned HTTP 200 from both EL10 and Fedora Rawhide endpoints. DNF repoquery returned exactly the same six Release 50 NEVRAs from both endpoints; local repository checksums are retained under ignored `packaging/build/validation/rc5-r50/`.

## Disposition

R50 is **superseded before VM testing** because #244 exposed the missing common-package `%check`. No single-node or multi-node scenario ran on R50; it contributes no matrix evidence. The proposed syntax checks are in root commit `012a571f3ffb2f4bfc58eed82c5778a92d07314c`, CI [39727055542](https://github.com/admiral-project/admiral/actions/runs/39727055542) passed, and the issue remains open with `fix-proposed`. Release 51 must be built from the updated coordinated six-spec set and must pass the common payload `%check` before any matrix cell starts.
