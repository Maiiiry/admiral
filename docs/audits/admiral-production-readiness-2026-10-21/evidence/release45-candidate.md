# Release 45 candidate build record

Status at 2026-10-21 21:26 UTC: **built and published to the isolated local lab repository; not yet installed in audit guests. Matrix status remains 0/8.** Release 42 and 43 observations are historical only and do not validate this candidate.

## Source identity

- Root commit: `0e4e607a124144c0cfa54912c914d74e3139ac0b` (`main`).
- Admiral source: version `0.0.1rc5`, RPM Release `45`, x86_64 and noarch RPMs.
- Component source pins; all five Git submodules were fetched and compared equal to `origin/main` before the build:
  - `admirald`: `12b5612873cbdb2dd9c3fabd1bb882ef55c30584`
  - `admiral-fleet`: `740b690fdb49e86fa63c9db2b56a1e576247b162`
  - `admiralctl`: `2840536316dcd4ae5a038bee9b29334a67a5d7de`
  - `admiral-harbor`: `4dfce69a13a632f6e49e5168fae99233e0f94314`
  - `admiral-flagship`: `3911eb784aef732f0bbe4662d1dbc6a5947eb659`
- `admiral-common` payload pin: `d01b08c1b8976d9c3d6d6f3cec6f1e01d1230c39`.
- `python3 scripts/validate-release-refs.py`: PASS.
- Harbor CI: [run 39677409482](https://github.com/admiral-project/admiral-harbor/actions/runs/39677409482), success.
- Root CI: [run 39677696619](https://github.com/admiral-project/admiral/actions/runs/39677696619), success.

## Build and package checks

Build host: Rocky Linux 10.2 x86_64. The coordinated `make rpm-admiral RPM_ARCH=x86_64` completed successfully. Because the host RPM database provides Go 1.26.7 while the specs require `golang >= 1.26.10`, local `rpmbuild` was invoked with `--nodeps`; `GOTOOLCHAIN=auto` selected Go 1.26.10, confirmed from all three built Go binaries with `go version -m`. Their embedded root VCS revision is `0e4e607a124144c0cfa54912c914d74e3139ac0b` and `vcs.modified=false`. The RPM BuildRequires preflight was therefore bypassed on this host and remains a documented limitation of this build evidence.

- `admirald`: Go tests passed; x86_64 ELF check passed.
- `admiral-fleet`: Go tests passed; four x86_64 ELF checks passed.
- `admiralctl`: Go tests and CLI version check passed; x86_64 ELF check passed.
- `admiral-flagship`: 266 tests passed.
- `admiral-harbor`: 347 tests passed in 224.75 seconds with host Mistune 3.2.1. Six focused link/route tests also passed with the packaged Mistune 3.4.0 RPM.
- Release 44's Harbor test failure is preserved in `release44-harbor-check-failure.md`.

The local lab repository was created at `/var/lib/libvirt/images/admiral-validation/repo/rc5-r45/`, with separate EL10 and Fedora metadata. Both `repomd.xml` endpoints returned HTTP 200, and `dnf repoquery` returned exactly the six Release 45 NEVRAs. Per-repository hashes, including support RPMs, are in the ignored build directory `packaging/build/validation/rc5-r45/`.

## Exact Admiral RPMs

The six package SHA-256 values are in `release45-rpm-sha256.txt`; `candidate-rpm-sha256.txt` retains the historical Release 42 checksums. Local repo preparation is reproducible with `scripts/publish-candidate-repo.sh 45`; it publishes the six requested Admiral RPMs and local Python support RPMs into a release-specific repository.

No functional VM, integration, resilience, isolation, or performance tests have yet run against Release 45. Do not treat build checks, unit tests, repository metadata, or prior-candidate runtime evidence as a matrix-cell PASS.
