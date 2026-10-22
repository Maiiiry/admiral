# Admiral Release 48 candidate build record

Audit: `ADM-AUDIT-2026-10-21`<br>
Candidate: Admiral RC5 Release 48, built for x86_64; RPM payload architectures are x86_64 and noarch.<br>
Build result: **six coordinated Admiral RPMs built with package checks enabled, staged in an isolated local repository, and queried from both EL10 and Fedora Rawhide endpoints.** Each endpoint returned exactly the same six R48 Admiral NEVRAs. No Release 48 guest execution has started; matrix completion remains **0/8**.<br>
Build date: 2026-10-22 UTC. `admirald` RPM build timestamp: 2026-10-22 02:42:14 UTC.<br>

## Source and CI identity

The package-preparation commit is root `5bb18b17cddce3c1a50e3bd19fe6b0ac4cae36b7` on `main`; its GitHub CI passed in [run 39712768068](https://github.com/admiral-project/admiral/actions/runs/39712768068). All six Admiral RPM specs have `Release: 48`. The common RPM payload uses root source commit `d68dfa0a82ae6c2035c566260e0be2be27c0e200`. Each component pin matched fetched `origin/main` before the build.

| Component | Exact source SHA | GitHub CI |
| --- | --- | --- |
| `admirald` | `d50523f7a75b0a1606c761423de9d1cdc844425e` | [run 39711773654](https://github.com/admiral-project/admirald/actions/runs/39711773654) — success |
| `admiral-fleet` | `740b690fdb49e86fa63c9db2b56a1e576247b162` | [run 39663860552](https://github.com/admiral-project/admiral-fleet/actions/runs/39663860552) — success |
| `admiralctl` | `2840536316dcd4ae5a038bee9b29334a67a5d7de` | [run 39654766669](https://github.com/admiral-project/admiralctl/actions/runs/39654766669) — success |
| `admiral-flagship` | `3911eb784aef732f0bbe4662d1dbc6a5947eb659` | [run 39654771764](https://github.com/admiral-project/admiral-flagship/actions/runs/39654771764) — success |
| `admiral-harbor` | `92c5ccac6a647cb85da36b056cb3352f391ab8c9` | [run 39705906726](https://github.com/admiral-project/admiral-harbor/actions/runs/39705906726) — success |

The local `python3 scripts/validate-release-refs.py` check passed before commit and during each package target. After the build, the root-only audit-helper fix for #238 was pushed in `11c6c6861e81293148d4220c266305d6146375c`; CI passed in [run 39713868071](https://github.com/admiral-project/admiral/actions/runs/39713868071). This did not alter the R48 RPM payload.

## Build host and package checks

- Host: Rocky Linux 10.2 x86_64, 4 vCPU, 8 GiB RAM and 4 GiB swap. It had 90 GiB free disk and 5.5 GiB available memory before the build; 90 GiB remained free afterward.
- Build command: `GOTOOLCHAIN=auto make rpm-admiral RPM_ARCH=x86_64 RPMFLAGS="--target x86_64 --define '_topdir /root/admiral/packaging/build' --define '_sourcedir /root/admiral/packaging/build/SOURCES' --define '_specdir /root/admiral/packaging/build/SPECS' --define '_builddir /root/admiral/packaging/build/BUILD' --define '_rpmdir /root/admiral/packaging/build/RPMS' --define '_srcrpmdir /root/admiral/packaging/build/SRPMS' --define '_tmppath /root/admiral/packaging/build/tmp' --nodeps"`.
- The host provides Go 1.26.7, below the specs' `BuildRequires: golang >= 1.26.10`; `--nodeps` bypassed that host dependency gate. `GOTOOLCHAIN=auto` was enabled and the package `%check` recipes remained enabled; no `--nocheck` was used.
- Package checks succeeded: Go test recipes for `admirald`, Fleet and `admiralctl`; Flagship 266/266; Harbor 350/350. The full local suites passed for all five components and root scripts. Root script tests passed 111/111 before packaging and 112/112 after the #238 harness regression was added. Flagship and Harbor Ruff checks and audit shell syntax checks passed.
- The rpmbuild console output was not saved as a complete local logfile. The reproducible command, source SHAs, package checks, RPM metadata, checksums, repository metadata responses and DNF query results are retained here; this limits raw build-log review.

## Exact Admiral RPMs

| NEVRA | SHA-256 |
| --- | --- |
| `admiral-common-0.0.1rc5-48.el10.noarch` | `7f93b10ead3ecca40dd0ae3c0dd426bea749522c268ad8f622fdf0028326a770` |
| `admirald-0.0.1rc5-48.el10.x86_64` | `9b56f01beb1dd28f52618e457aa6e14d1a99854f660831db369b26614e7bc39c` |
| `admiral-fleet-0.0.1rc5-48.el10.x86_64` | `7633f73870b3e21d36b3c7affe1254f156ef6b0d0486808300a43a5cbec0f664` |
| `admiralctl-0.0.1rc5-48.el10.x86_64` | `98ca7bf20cfcfb73bed5c2292654f9c6ec2e89ee917c3eddec7369696703be6e` |
| `admiral-flagship-0.0.1rc5-48.el10.noarch` | `56b0656ec161fd42bb826da332f8f5022a3ef2acbbb19dd85dc37b9f5c992d01` |
| `admiral-harbor-0.0.1rc5-48.el10.noarch` | `6b97a74a03417c04853a9ceb66871e654ddba8ecbab7e27ff3a916195cd59197` |

Machine-readable hashes are in `release48-rpm-sha256.txt`. The local RPM copies are in ignored `packaging/build/validation/rc5-r48/artifacts/` and in the isolated repository below.

## Isolated local repositories

The local repository root is `/var/lib/libvirt/images/admiral-validation/repo/rc5-r48`. The EL10 endpoint is `http://192.168.122.1/rc5-r48/el10/x86_64/`; the Fedora Rawhide endpoint is `http://192.168.122.1/rc5-r48/fedora/x86_64/`. Both `repomd.xml` requests returned HTTP 200. DNF repoquery restricted to the six Admiral package names returned exactly the six NEVRAs above from each endpoint. Each repository contains 13 packages: six Admiral RPMs and seven Python support RPMs. Fedora uses `python3-mistune-3.4.0-1.fc46`; EL10 uses `python3-mistune-3.4.0-1.el10`. Rocky's prepared seed has the documented EPEL `python3-pyOpenSSL-25.0.0-1.el10_1` validation pin. No public RPM repository was modified.

The per-repository SHA-256 lists, including the seven support RPMs, and generated `.repo` files are in ignored `packaging/build/validation/rc5-r48/`.

## Validation status

Release 48 is built and staged, but no VM has installed it and no matrix scenario has run. The set was superseded before testing because issue #234's Ansible facts fix is absent from its pinned common payload (`d68dfa0`). The fix is pushed at root `be2054559a4835f8860e067345224b9dbe2c705f`, with CI success in [run 39714180234](https://github.com/admiral-project/admiral/actions/runs/39714180234). Release 49 package preparation is in progress; its RPMs are not built. The matrix remains **0/8**. Release 47 remains invalidated by #237; neither R47 nor R48 runtime observations count toward R49. Issues remain open; no issue was closed.
