# Release 61 Rocky Linux Single-Node invalidation

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Candidate: Admiral RC5 Release 61, x86_64<br>
Guest: fresh Rocky Linux 10.2 overlay `adm-r61-rocky-single`, 2 vCPU / 2 GiB<br>
Root source commit: `6b55f7510aef822a6bf34c6e639f2a410fb19204`<br>
`admirald`: `9b8f1299fe43d0540442b4bc05cdbe0c5f4611aa`<br>
`admiral-fleet`: `c902a2895c1b12c18f4607b92f13c83515b3da25`<br>
`admiralctl`: `49cf2428c064434c65af9a14f96975c1bb2db637`<br>
`admiral-flagship`: `b7325bbc71fc474a521496e593b2967e4d555ac1`<br>
`admiral-harbor`: `dd39e9a74bf658ecf6fd6e9f8bd30b2ddf82d7db`

Release 61 is invalidated by a reproduced #259 false-healthy state during a rootless user-systemd manager restart. The result is a targeted failure, not a completed Single-Node cell; the matrix remains 0/8. The clean install subset passed, but recovery persistence was not tested after the false-health assertion stopped the harness.

## Candidate identity

The six exact Admiral RPMs below were installed from the local Release 61 EL10 x86_64 repository. The local build used `RPMFLAGS_EXTRA=--nodeps`; RPM `%check` ran, but this did not establish a clean COPR BuildRequires transaction.

| Package | NEVRA | SHA-256 |
| --- | --- | --- |
| admiral-common | `admiral-common-0.0.1rc5-61.el10.noarch` | `373ee90b7defbe7894857e1ef215cb5e32a63816bc385058dacec4adc4f63e17` |
| admiral-fleet | `admiral-fleet-0.0.1rc5-61.el10.x86_64` | `3c8b24e9c5d3f52b479240310719fb677bab1e574a2d0edeb4e934c38a45be87` |
| admiral-flagship | `admiral-flagship-0.0.1rc5-61.el10.noarch` | `5c5b16fcedb12c985da13bad338ac664c82c00a941036b9ea9023aabc695ab4f` |
| admiral-harbor | `admiral-harbor-0.0.1rc5-61.el10.noarch` | `4863d2c36b6f6c1e897b01fa355686825e2074c5edee088b4e37d07d6e945c97` |
| admiralctl | `admiralctl-0.0.1rc5-61.el10.x86_64` | `f9ac9e0a2ebef159ed986e4036a565ab52f4eda1a7733702d88b61f86e3bdd66` |
| admirald | `admirald-0.0.1rc5-61.el10.x86_64` | `ffbb8bd240a38c7ea4d91208e91ed70d99025eefe45c47cd00a5cbc98e352ef9` |

The complete 14-package Admiral/Python RPM checksum manifest is `packaging/build/repos/el10-rc5-r61-x86_64/SHA256SUMS`, SHA-256 `f70c73e70f691857a0c6e88af52eeb4e0a5b54c1a0067dcce53e56f2b9fec9e3`. The exact guest installation used the updated Rocky seed recorded in `evidence/release54-seed-sha256.txt`; no full OS update transaction was run. The Ansible installer completed in 458 seconds with `ok=231 changed=97 unreachable=0 failed=0 skipped=149`.

## Executed scenarios

| Test ID | Procedure and observed result | Status | Evidence |
| --- | --- | --- | --- |
| `R61-ROCKY-SN-INSTALL` | Fresh Rocky overlay; installed the six exact R61 RPMs, ran the secure single-node installer, and checked the services. Ansible reported zero failed tasks. | PASS — install subset only | Restricted local `packaging/build/validation/rc5-r61/install-rocky.log`, SHA-256 `892b3affea8dab7b2827b7de817b5762fc93e02f6392e5286b6e57b7f36f37e9` |
| `R61-ROCKY-SN-USER-MANAGER-RESTART` | Provisioned a PostgreSQL-backed workload, then restarted `user@991.service` while sampling Fleet/API health at roughly 100 ms intervals. Three API samples remained `running/healthy/available` while the manager was `deactivating` or `inactive`. Fleet invalidated health only after the new manager PID appeared. Runtime later recovered, but the false-health assertion failed before SQL persistence verification. The EXIT cleanup deprovisioned the instance; a follow-up check found no matching Podman resources. | **FAIL — candidate invalidated; #259** | Restricted raw archive `packaging/build/validation/rc5-r61/rocky-manager-restart-failure/evidence.tar.gz`, SHA-256 `fa69a524185d9d0256dc799943e6e9989fe482c5bc69f8d3f4f774130a0bad73`; harness SHA-256 `1e7fbac471b2ac5bd01f06514637e3055e69644d066032e9c9a2f84fa3cbdb81` |

The three false-healthy API samples occurred at `00:25:45.720Z`, `00:25:46.194Z`, and `00:25:46.934Z`. The first two had manager PID `5020` and state `deactivating`; the third had PID `5020` and state `inactive`. Each reported `running healthy available`. systemd began stopping `user@991.service` at `00:25:45Z`, deactivated and stopped it at `00:25:47Z`, then started it again. Fleet logged PID `5020 → 24610` at `00:25:47.704Z`, after those false-health samples. At recovery poll 5 (`00:25:55Z`), the manager and pod were active, PostgreSQL accepted connections, HTTP returned 200, and the API returned healthy/available.

Confirmed cause: Fleet observed only `MainPID`; it could not detect the manager entering `deactivating` while the old PID remained. The candidate therefore left a previously healthy observation effective until the manager replacement was observed. This is a real guest/API observation, not a unit-test inference.

## Correction and next validation

Fleet commit `0c805d6293bfb11fd4f015f1b0ccff520481e627` reads both `ActiveState` and `MainPID`, invalidates workload health as soon as the manager is non-active, and waits for the normal fresh runtime reconciliation after the manager returns. Regression coverage models `deactivating → inactive → activating → active`. Local Fleet `go test ./...`, `go vet ./...`, and `go build ./...` pass; three repeated runs of the targeted manager-restart tests pass. GitHub CI run [39878457179](https://github.com/admiral-project/admiral-fleet/actions/runs/39878457179) completed successfully.

Do not reuse Release 61 as passing evidence. After Fleet CI is green, pin the exact fix in a new coordinated six-RPM release, run `make validate-release-refs`, and repeat this regression on a fresh Rocky guest with that exact new candidate before progressing through the remaining OS/topology cells. Issue #259 remains open.
