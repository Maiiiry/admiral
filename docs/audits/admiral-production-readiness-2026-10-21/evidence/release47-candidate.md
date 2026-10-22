# Admiral Release 47 candidate build record

Audit: `ADM-AUDIT-2026-10-21`<br>
Candidate: Admiral RC5 Release 47, x86_64 build; package payload architectures are x86_64 and noarch.<br>
Build result: **six coordinated Admiral RPMs built successfully, tested, copied into an isolated local repository, and exposed through both EL10 and Fedora Rawhide repo endpoints.** DNF returned the same six Release 47 Admiral NEVRAs for both endpoints. Two fresh Single-Node diagnostics were then run; a reboot availability defect (#237) invalidated Release 47. None of those partial results count toward the matrix; completion remains **0/8**. See `release47-invalidated-single-node.md`.<br>
Build time: 2026-10-22 UTC.<br>

## Source and CI identity

The package-preparation commit is root `45b7b591b013c957ceeae2fcfd3849bbaeb03ef4` on `main`. All six Admiral spec `Release` fields are `47`. The common RPM payload uses root commit `e0ca76e5c9a5e22fc62becc7d40ef6ff71686f8d`; component archive pins equal their fetched `origin/main` SHAs.

| Component | Exact source SHA | CI |
| --- | --- | --- |
| `admirald` | `7f487d811c4e4ed08e532cca3efaa6a0c6695dcc` | [run 39705903289](https://github.com/admiral-project/admirald/actions/runs/39705903289) — success |
| `admiral-fleet` | `740b690fdb49e86fa63c9db2b56a1e576247b162` | [run 39663860552](https://github.com/admiral-project/admiral-fleet/actions/runs/39663860552) — success |
| `admiralctl` | `2840536316dcd4ae5a038bee9b29334a67a5d7de` | [run 39654766669](https://github.com/admiral-project/admiralctl/actions/runs/39654766669) — success |
| `admiral-flagship` | `3911eb784aef732f0bbe4662d1dbc6a5947eb659` | [run 39654771764](https://github.com/admiral-project/admiral-flagship/actions/runs/39654771764) — success |
| `admiral-harbor` | `92c5ccac6a647cb85da36b056cb3352f391ab8c9` | [run 39705906726](https://github.com/admiral-project/admiral-harbor/actions/runs/39705906726) — success |

Root CI passed for the package-preparation commit at [run 39708464424](https://github.com/admiral-project/admiral/actions/runs/39708464424). The local `validate-release-refs.py` check passed after fetching all five component `main` branches and again in each package build target.

## Build host and verification

- Host: Rocky Linux 10.2 x86_64, 4 vCPU, 8 GiB RAM and 4 GiB swap. There were 82 GiB free before and after the build; no disk pressure was observed.
- Build command: `GOTOOLCHAIN=auto make rpm-admiral RPM_ARCH=x86_64` with the standard explicit RPM build paths and `rpmbuild --nodeps` appended.
- The host RPM database provides Go 1.26.7, below the specs' `BuildRequires: golang >= 1.26.10`. `--nodeps` bypassed the host BuildRequires gate; it did not disable `%check`. Go automatic toolchain selection was enabled. `go version -m` on each extracted packaged binary reports `go1.26.10` with `GOOS=linux`, `GOARCH=amd64`.
- The build log is retained locally at `packaging/build/validation/rc5-r47/build.log` with mode `0600`; SHA-256: `0c973be6dbba7403c3d141ce9c83cc575ef5a1c966b9b9987248a2d901b6a698`.
- `%check` passed for all six specs. The three Go suites passed, Flagship passed 266 tests, and Harbor passed 350 tests (307 warnings, no failures). The full local pre-build suites also passed: root scripts 111, `admirald`, `admiral-fleet`, `admiralctl`, Flagship 266 and Harbor 350; Ruff and audit-script Bash syntax checks passed.

## Exact Admiral packages

| NEVRA | SHA-256 |
| --- | --- |
| `admiral-common-0.0.1rc5-47.el10.noarch` | `d84b6b9d6091dc96c286e0540aa90972056862203d8fcf2d692c99d682db7a59` |
| `admirald-0.0.1rc5-47.el10.x86_64` | `c3d0eef6184e2b1c222006d329805263dbc4bf5a800db225099805fe483b1f49` |
| `admiral-fleet-0.0.1rc5-47.el10.x86_64` | `ef0702caa927bfaea2f0b4e7e3474ab3b90877b3280518f7e56854f65bb2fe7b` |
| `admiralctl-0.0.1rc5-47.el10.x86_64` | `0a68d86b6b65d1e9576fcb633f97efc938acbea09660afbaceeef8785c9efb10` |
| `admiral-flagship-0.0.1rc5-47.el10.noarch` | `9913b52bc786d984efd3c716c5cd85bf768b9b19f41590c23d297e736f68d392` |
| `admiral-harbor-0.0.1rc5-47.el10.noarch` | `29e4d4a6529dafc39869227a4b5b5f4bad061685228a285c93171b52094d43bc` |

Machine-readable hashes and artifact paths are in `release47-rpm-sha256.txt` and the ignored local `packaging/build/validation/rc5-r47/artifacts/` directory.

## Local validation repositories

The isolated repository root is `/var/lib/libvirt/images/admiral-validation/repo/rc5-r47`. The EL10 and Fedora Rawhide repository configurations are in the ignored local validation directory as `admiral-local-el10.repo` and `admiral-local-fedora.repo`; both serve 13 packages: the six Admiral RPMs and seven unchanged Python support RPMs reused from the prior local candidate. The Fedora repo carries `python3-mistune-3.4.0-1.fc46`; EL10 carries `python3-mistune-3.4.0-1.el10`. The Rocky seed separately retains its documented EPEL `python3-pyOpenSSL-25.0.0-1.el10_1` validation pin.

Both `repomd.xml` endpoints returned HTTP 200. A DNF `repoquery` against each isolated endpoint, restricted to the six Admiral package names, returned exactly these six NEVRAs and no prior candidate packages. No public repository was modified.

## Validation status

Release 47 is an invalidated candidate. Fedora and Rocky Single-Node diagnostic runs found stale post-reboot `effective_availability`; the finding is tracked in #237 and the fix is pushed at `admirald@d50523f` with CI green. Release 48 root submodule pins and all six package `Release` fields are prepared in the current local working tree; no R48 RPM has been built yet, and root commit CI must pass before building. The eight-cell matrix remains **0/8**; R47 observations do not count. Any new defect requiring a source fix invalidates candidate evidence and requires a new coordinated Release.
