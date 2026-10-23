# Release 64: Fedora DNF5 resolver invalidation

**Disposition: INVALIDATED before runtime testing. Matrix: 0/8.** No Release 64 package was installed on a validation guest, and no R64 runtime result counts toward any cell.

## Candidate identity

- Root source commit: `22f2fba1894d00c383dfa48b2413c05685050ec2` (`fix(packaging): include Fedora SQLAlchemy metadata`), root CI green in [run 39890178668](https://github.com/admiral-project/admiral/actions/runs/39890178668).
- Component pins matched each submodule's `origin/main`: common `f7118329c23a75ef36b0cd6067f30a82617d9ac9`, admirald `351a713dec3a3672a22707c1e15a7f77f827e1c5`, fleet `0c805d6293bfb11fd4f015f1b0ccff520481e627`, admiralctl `49cf2428c064434c65af9a14f96975c1bb2db637`, flagship `b7325bbc71fc474a521496e593b2967e4d555ac1`, harbor `dd39e9a74bf658ecf6fd6e9f8bd30b2ddf82d7db`.
- Target: x86_64 only; EL10 and Fedora Rawhide 46 / Python 3.15 builders.
- Each local repo contained six Admiral RPMs and eight Python helper RPMs. The six Admiral NEVRAs were `0.0.1rc5-64.el10` and `0.0.1rc5-64.fc46` respectively.
- EL10 `repomd.xml` SHA-256: `f4ba034776803a439cdcbf9acde059cfe9dcd7b355daa20acda1b816d045d8b3`.
- Fedora `repomd.xml` SHA-256: `cc23a5db29f83c487e5f91d8c968183747e49eb9e5f0fccd7d4222e55e9609f4`.
- Per-RPM NEVRA and SHA-256 manifests: [`release64-rpm-manifest-el10.tsv`](release64-rpm-manifest-el10.tsv), [`release64-rpm-manifest-fc46.tsv`](release64-rpm-manifest-fc46.tsv), and corresponding [`EL10 checksums`](release64-rpm-sha256-el10.txt) / [`Fedora checksums`](release64-rpm-sha256-fc46.txt).

## Build results

- EL10: six Admiral packages and eight helper packages were built. All package `%check` stages completed; Admiral Harbor reported 350 tests passing in 203.97 seconds. The first aggregate attempt stopped at Harbor because the builder lacked four helper BuildRequires; those exact helper RPMs were installed through DNF and Harbor was rebuilt successfully. The captured build log is [`release64-el10-build.log`](release64-el10-build.log).
- Fedora: six Admiral packages and eight helper packages were rebuilt on Fedora 46 so the RPMs carry `.fc46` metadata. All package `%check` stages completed; Admiral Harbor reported 350 tests passing in 389.79 seconds. The builder used normal dependency installation; no `--nodeps` build was used. The logs are [`release64-fedora-admiral-rpmbuild.log`](release64-fedora-admiral-rpmbuild.log) and [`release64-fedora-python-rpmbuild.log`](release64-fedora-python-rpmbuild.log).
- The tracked Fedora build-log copies have trailing whitespace removed for repository hygiene; original raw logs remain under the ignored local `packaging/build/validation/rc5-r64/` directory.
- Package-build tests do not constitute guest runtime validation.

## Resolver defect

On a fresh Fedora 46 x86_64 seed with Fedora Rawhide and Admiral COPR enabled, `dnf5 install --assumeno admiral-common admirald admiral-fleet admiralctl admiral-flagship admiral-harbor` failed under the normal vendor policy. Exact package NEVRA requirements demanded local Fedora RPM releases and prevented use of compatible installed Fedora/COPR providers. The exact reproduction and observed resolver errors are tracked in [issue #263](https://github.com/admiral-project/admiral/issues/263).

Retrying with `--allow-vendor-change` produced a transaction only by downgrading three packages:

- Flask `1:3.1.3-6.fc45` to `1:3.1.3-3.fc46`;
- Flask-Login `0.6.3-13.fc45` to `0.6.3-8.fc46`;
- typing-extensions `4.16.0-4.fc46` to `4.16.0-1.fc46`.

The output of that override dry-run is preserved in [`release64-fedora-dnf-resolver-vendor.log`](release64-fedora-dnf-resolver-vendor.log). DNF printed “Operation aborted by the user”; no transaction was applied. The normal resolver failure was observed interactively and is documented in issue #263; its complete raw terminal transcript was not retained. No production repository was changed.

The EL10 local RPM repository also completed a dependency dry-run on a fresh Rocky Linux 10.2 overlay, but that diagnostic transcript was not retained. It did not install packages and did not complete a matrix cell.

## Current follow-up

Issue #263 remains open and has `fix-proposed`. The local source fix expresses exact application module versions with `python3dist(...)` capabilities and removes distro-specific RPM Release pins; compatible transitive minimums replace unnecessary exact package builds. All six coordinated Admiral specs are now Release 65. Local audit tests (129), admiralctl tests, source-reference validation, spec parsing, and `git diff --check` passed. R65 is not built, the DNF resolver has not yet been rechecked, and the matrix remains **0/8**. No issue was closed.
