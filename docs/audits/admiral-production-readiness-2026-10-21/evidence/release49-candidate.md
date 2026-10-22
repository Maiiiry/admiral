# Admiral Release 49 candidate build record

Audit: `ADM-AUDIT-2026-10-21`  
Candidate: Admiral RC5 Release 49, x86_64; RPM payload architectures are x86_64 and noarch.  
Build result: **six coordinated Admiral RPMs built with package `%check` enabled, staged in isolated EL10 and Fedora Rawhide local repositories, and queried from both endpoints.** Both DNF queries returned exactly the same six R49 Admiral NEVRAs. No Release 49 VM execution has started; matrix completion remains **0/8**.  
Build date: 2026-10-22 UTC. RPM build timestamps: 03:20:52–03:22:21 UTC.

## Source and CI identity

The package-preparation commit is root `6661bb779dd197d24cf565e7e5bb85c99ef809ed` on `main`; its GitHub CI passed in [run 39714539551](https://github.com/admiral-project/admiral/actions/runs/39714539551). All six Admiral RPM specs have `Release: 49`. The `admiral-common` RPM payload uses root source commit `be2054559a4835f8860e067345224b9dbe2c705f`. Before building, all five component submodules were fetched and their pins matched `origin/main` exactly.

| Component | Exact source SHA | GitHub CI |
| --- | --- | --- |
| `admirald` | `d50523f7a75b0a1606c761423de9d1cdc844425e` | [run 39711773654](https://github.com/admiral-project/admirald/actions/runs/39711773654) — success |
| `admiral-fleet` | `740b690fdb49e86fa63c9db2b56a1e576247b162` | [run 39663860552](https://github.com/admiral-project/admiral-fleet/actions/runs/39663860552) — success |
| `admiralctl` | `2840536316dcd4ae5a038bee9b29334a67a5d7de` | [run 39654766669](https://github.com/admiral-project/admiralctl/actions/runs/39654766669) — success |
| `admiral-flagship` | `3911eb784aef732f0bbe4662d1dbc6a5947eb659` | [run 39654771764](https://github.com/admiral-project/admiral-flagship/actions/runs/39654771764) — success |
| `admiral-harbor` | `92c5ccac6a647cb85da36b056cb3352f391ab8c9` | [run 39705906726](https://github.com/admiral-project/admiral-harbor/actions/runs/39705906726) — success |

`python3 scripts/validate-release-refs.py` passed before the build and during the RPM targets. The open #234 Ansible facts fix is in common source commit `be20545`; the #238 bootstrap-helper fix is present in root commit `6661bb7`. Both issues remain open for exact-candidate verification and retain the `fix-proposed` label. #235 and #236 remain open for measurement during fresh guest runs. No issue was closed, and no new product defect was found while preparing this candidate.

## Build host and checks

- Host: Rocky Linux 10.2 x86_64, 4 vCPU, 8 GiB RAM, 4 GiB swap, KVM available, SELinux enforcing. Before build: 90 GiB free disk and 5.4 GiB available memory. After build and repository staging: 89 GiB free disk and 5.4 GiB available memory. No virtual machines were running at the start of the build.
- Build command: `GOTOOLCHAIN=auto make rpm-admiral RPM_ARCH=x86_64 RPMFLAGS="--target x86_64 --define '_topdir /root/admiral/packaging/build' --define '_sourcedir /root/admiral/packaging/build/SOURCES' --define '_specdir /root/admiral/packaging/build/SPECS' --define '_builddir /root/admiral/packaging/build/BUILD' --define '_rpmdir /root/admiral/packaging/build/RPMS' --define '_srcrpmdir /root/admiral/packaging/build/SRPMS' --define '_tmppath /root/admiral/packaging/build/tmp' --nodeps"`.
- The host has Go 1.26.7, below the specs' `BuildRequires: golang >= 1.26.10`; `--nodeps` bypassed this host dependency gate. `GOTOOLCHAIN=auto` was enabled, all RPM `%check` recipes remained enabled, and no `--nocheck` was used.
- All six package builds and `%check` recipes exited successfully. The three Go test suites passed; Harbor reported **350 passed**. Flagship's pytest `%check` exited successfully; its complete console output was not retained, so its exact count is not asserted here. The root audit script suite passed **113/113** before the R49 preparation commit; Ansible syntax checks, local fact-availability assertion, Ruff, shell syntax and `git diff --check` passed for the relevant fixes.
- Full `rpmbuild` stdout was not retained as a logfile. The exact reproducible command, source SHAs, CI runs, RPM metadata, checksums, repository metadata responses and DNF query results are recorded here; raw build-log review is therefore limited.

## Exact Admiral RPMs

| NEVRA | SHA-256 |
| --- | --- |
| `admiral-common-0.0.1rc5-49.el10.noarch` | `81f2483f659cdfc176ecf7d070fe7089eac5af0cad455406e5695c468f1945df` |
| `admirald-0.0.1rc5-49.el10.x86_64` | `5d1858b579bb122385259fb7382944df9ec02263665a9229adac57720d9b317e` |
| `admiral-fleet-0.0.1rc5-49.el10.x86_64` | `e7aafd86b0d39728bd3191001c68de151fb7743982f79e180ad7e2321b2d5232` |
| `admiralctl-0.0.1rc5-49.el10.x86_64` | `d955b497c5bdad8b4fb125e3c3e69bb48950794c37a1f20876e207ee7958a9ee` |
| `admiral-flagship-0.0.1rc5-49.el10.noarch` | `2b5a61b9c50b2d00c2196c601e6559c86506a0c422052355bd98fd84aa592635` |
| `admiral-harbor-0.0.1rc5-49.el10.noarch` | `9e4ee039a279c79fb9f14b411b6ffba148e58b36f530ffd463fc227e972ce0ba` |

Machine-readable hashes are in `release49-rpm-sha256.txt`. The local RPMs are in ignored `packaging/build/RPMS/` and in the isolated repositories below.

## Isolated local repositories

The repository root is `/var/lib/libvirt/images/admiral-validation/repo/rc5-r49`. EL10 is served at `http://192.168.122.1/rc5-r49/el10/x86_64/`; Fedora Rawhide is served at `http://192.168.122.1/rc5-r49/fedora/x86_64/`. Both `repomd.xml` requests returned HTTP 200. DNF repoquery restricted to the six Admiral package names returned exactly these six Release 49 NEVRAs from each endpoint. Each candidate repository contains 13 packages: six Admiral RPMs and seven Python support RPMs. EL10 uses `python3-mistune-3.4.0-1.el10`; Fedora uses `python3-mistune-3.4.0-1.fc46`. Rocky's seed retains the documented EPEL `python3-pyOpenSSL-25.0.0-1.el10_1` pin.

The local per-repository checksums and generated `.repo` files are in ignored `packaging/build/validation/rc5-r49/`. No public package repository was modified.

## Validation status

Release 49 is the active candidate. Its package build and local repository checks passed. No R49 VM has installed it and no R49 runtime scenario has run; matrix completion remains **0/8**. Start with fresh Fedora Rawhide and Rocky Linux 10 Single-Node overlays in parallel, then continue through all four x86_64 OSes and both topologies. R47 and R48 runtime evidence remains invalidated/superseded and does not count toward R49. Issues stay open until the candidate-specific verification is complete.
