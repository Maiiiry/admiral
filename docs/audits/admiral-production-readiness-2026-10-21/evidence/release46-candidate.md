# Admiral Release 46 candidate build record

Audit: `ADM-AUDIT-2026-10-21`<br>
Candidate: Admiral RC5 Release 46, x86_64 host RPM build; payload architectures are x86_64 and noarch.<br>
Build result: **six coordinated Admiral RPMs built successfully and published to the isolated local candidate repository. Fresh Fedora Rawhide and Rocky Linux 10 Single-Node installations and targeted runtime probes completed; fresh AlmaLinux 10 and CentOS Stream 10 installs are in progress. No full matrix cell has passed; matrix remains 0/8.**<br>
Build time recorded by host: 2026-10-21 UTC.<br>

## Source and CI identity

- Package-preparation commit: root `7223561646b60d3c24e8bfb257d544a5eb6dea04` (`main`), with all six package `Release` fields set to 46.
- Build invocation commit: root `d9eb9514951230af5f0202d8b125c85ea6bde392` (`main`). The delta from the package-preparation commit is audit documentation/evidence only; package specs, Makefile pins and product inputs are unchanged.
- Component origin/main pins were fetched and compared immediately before build; `python3 scripts/validate-release-refs.py` passed both before and during the build.

| Component | Exact source SHA | CI |
| --- | --- | --- |
| `admirald` | `e2b4fcee8fcd63d3c66b9f659156874d2a1bbb09` | [run 39685965525](https://github.com/admiral-project/admirald/actions/runs/39685965525) — success |
| `admiral-fleet` | `740b690fdb49e86fa63c9db2b56a1e576247b162` | [run 39663860552](https://github.com/admiral-project/admiral-fleet/actions/runs/39663860552) — success |
| `admiralctl` | `2840536316dcd4ae5a038bee9b29334a67a5d7de` | [run 39654766669](https://github.com/admiral-project/admiralctl/actions/runs/39654766669) — success |
| `admiral-flagship` | `3911eb784aef732f0bbe4662d1dbc6a5947eb659` | [run 39654771764](https://github.com/admiral-project/admiral-flagship/actions/runs/39654771764) — success |
| `admiral-harbor` | `4dfce69a13a632f6e49e5168fae99233e0f94314` | [run 39677409482](https://github.com/admiral-project/admiral-harbor/actions/runs/39677409482) — success |

Root CI passed for package preparation at [run 39686130018](https://github.com/admiral-project/admiral/actions/runs/39686130018) and for the pushed audit evidence at [run 39686636491](https://github.com/admiral-project/admiral/actions/runs/39686636491).

## Build host and procedure

- Host: Rocky Linux 10.2 x86_64, 4 vCPU, 8 GiB RAM, 4 GiB swap, KVM/libvirt lab host.
- Space before and after package build: 29 GiB available on the filesystem; no disk exhaustion observed.
- The host `golang` RPM is 1.26.7, while the specs require `golang >= 1.26.10`. To allow the build to use Go's declared toolchain auto-selection, the local `rpmbuild` invocation used `--nodeps`; this bypassed the host RPM dependency check only. `GOTOOLCHAIN=auto` was set. **All three packaged Go binaries were extracted and `go version -m` confirmed `go1.26.10`.** This is recorded as a build-host limitation, not a change to the package's declared requirement.
- Build log (restricted local file, mode 0600): `packaging/build/validation/rc5-r46/rpm-build.log`.
- Repository publication log (mode 0600): `packaging/build/validation/rc5-r46/repo-publish.log`.
- Reproduction: `GOTOOLCHAIN=auto make rpm-admiral RPM_ARCH=x86_64 RPMFLAGS="--target x86_64 --define '_topdir /root/admiral/packaging/build' --define '_sourcedir /root/admiral/packaging/build/SOURCES' --define '_specdir /root/admiral/packaging/build/SPECS' --define '_builddir /root/admiral/packaging/build/BUILD' --define '_rpmdir /root/admiral/packaging/build/RPMS' --define '_srcrpmdir /root/admiral/packaging/build/SRPMS' --define '_tmppath /root/admiral/packaging/build/tmp' --nodeps"`.
- `make rpm-admiral` built all six target packages with `%check` enabled. `admirald` and `admiral-fleet` `go test ./...` passed; `admiralctl` `go test ./...` passed; Flagship passed 266/266 pytest tests; Harbor passed 347/347 pytest tests (304 deprecation/legacy API warnings were reported). RPM architecture assertions passed for the Go binaries.

## Exact packages

| NEVRA | SHA-256 |
| --- | --- |
| `admiral-common-0.0.1rc5-46.el10.noarch` | `66730035e1de020dfb57b9030d65ef18687d64889d424d8c73ae7e94bbb03019` |
| `admirald-0.0.1rc5-46.el10.x86_64` | `3ab7ce20564f0923e520298e0aa01b158b23777020ea1bc4fcc1f79a3ac6762f` |
| `admiral-fleet-0.0.1rc5-46.el10.x86_64` | `e64f0bdf9c0077cb8db86690f3b479bcbba22194baa6b03489fb96ef412163f0` |
| `admiralctl-0.0.1rc5-46.el10.x86_64` | `58440f5a25d7ed100055dc33bac4d354e2937ffb06c8d1064e6de9b45ef517b6` |
| `admiral-flagship-0.0.1rc5-46.el10.noarch` | `8fc217e66168c37cc358772ccbf6654010b75868c8fda9b78d66dd7f441f3317` |
| `admiral-harbor-0.0.1rc5-46.el10.noarch` | `c82ec54b299e034a781ce269ace575d101a155ea646d4d32dd89b367c5ab8f34` |

Machine-readable hashes are in `release46-rpm-sha256.txt`. `rpm -qp` confirmed exactly these six Release 46 NEVRAs. DNF repository queries for both EL10 and Fedora Rawhide metadata returned exactly the same six Admiral NEVRAs. Both local `repomd.xml` endpoints returned HTTP 200. The local lab repo uses `gpgcheck=0` and is reachable only on the isolated validation network; it is not a production distribution repository.

## Validation status

Release 46 was installed on fresh Fedora Rawhide and Rocky Linux 10 Single-Node guests. The Fedora failed-provision/deprovision/reboot regression passed on that named scenario; Rocky completed an HTTP 200 whoami lifecycle and cleanup probe. Exact results and restricted raw-log hashes are in [the initial Single-Node evidence](release46-initial-single-node-execution.md). These probes do not complete either full OS cell. Fresh AlmaLinux and CentOS Stream installations are underway; no Release 46 Multi-Node scenario has run. The matrix remains **0/8** until a whole cell's required scenarios complete on the exact candidate. Release 45 remains invalidated by the reboot replay in [its Fedora evidence](fedora-r45-stale-task-replay.md); issue [#229](https://github.com/admiral-project/admiral/issues/229) stays open pending the fresh Multi-Node regression.
