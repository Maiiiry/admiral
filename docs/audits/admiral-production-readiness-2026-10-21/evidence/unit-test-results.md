# Repository test-suite results

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Source: root `748b703662eafdaf3919bad28787d0264f06bf16`; submodule SHAs in `source-manifest.txt`.<br>
Execution host: Rocky Linux 10.2 x86_64. Tests were run serially with low Go parallelism while the isolated three-VM lab was running.

| Component | Command | Result |
| --- | --- | --- |
| `admirald` | `GOMAXPROCS=1 go test -p 1 ./...` | Exit 0; all packages with tests passed. Packages without test files were reported explicitly by Go. |
| `admiral-fleet` | `GOMAXPROCS=1 go test -p 1 ./...` | Exit 0; all packages with tests passed. Packages without test files were reported explicitly by Go. |
| `admiralctl` | `GOMAXPROCS=1 go test -p 1 ./...` | Exit 0; all packages with tests passed. Packages without test files were reported explicitly by Go. |
| `admiral-flagship` | `python3 -m pytest -q` | Exit 0; 266 passed in 16.37s. |
| `admiral-harbor` | `python3 -m pytest -q` | Exit 0; 342 passed in 185.44s; 301 deprecation warnings (Alembic `path_separator` and SQLAlchemy legacy `Query.get`). |

These are repository test-suite results. They are not counted as deployment E2E, real resilience, tenant-isolation, load or vulnerability-scan evidence. In particular, a green suite did not prevent the runtime findings `ADM-F-001`, `ADM-F-002`, and `ADM-F-006`.

## Release 49 fix-validation suite — 2026-10-22

This run validates the #240 client fix and root audit-helper/documentation changes before the next candidate build. The source commit SHAs were root `9998952426014ea60c8b7d96656abb2f118279d1` plus uncommitted audit documentation/helper changes, `admirald` `d50523f7a75b0a1606c761423de9d1cdc844425e`, `admiral-fleet` `740b690fdb49e86fa63c9db2b56a1e576247b162`, `admiralctl` `5ed381d7d152e1606e78fafe332587cca09bc989`, `admiral-flagship` `3911eb784aef732f0bbe4662d1dbc6a5947eb659`, and `admiral-harbor` `92c5ccac6a647cb85da36b056cb3352f391ab8c9`.

| Component | Command / setup | Result |
| --- | --- | --- |
| Root audit scripts | `python3 -m pytest -q scripts/test_*.py` | Exit 0; **113 passed in 1.37s**. |
| `admirald` | `GOTOOLCHAIN=auto go test ./... && go vet ./... && go build ./...` | Exit 0; all packages with tests passed, vet and build passed. |
| `admiral-fleet` | `GOTOOLCHAIN=auto go test ./... && go vet ./... && go build ./...` | Exit 0; all packages with tests passed, vet and build passed. |
| `admiralctl` | Temporary RPM-equivalent dependency layout (`admiralctl/admirald -> ../admirald`), then `GOTOOLCHAIN=auto go mod tidy`, `go test ./...`, `go vet ./...` and `go build ./...` | Exit 0 for every command; the temporary symlink was removed and no tracked module files changed. A first unprepared invocation failed before tests because `./admirald` was absent; this checkout-layout issue is tracked in #241 and is not an RPM runtime failure. |
| `admiral-flagship` | `python3 -m pytest tests/ -x --tb=short` | Exit 0; **266 passed in 22.58s**. |
| `admiral-harbor` | `python3 -m pytest tests/ -x --tb=short` | Exit 0; **350 passed in 202.03s**, with 307 deprecation warnings (Alembic `path_separator` and SQLAlchemy `Query.get`). No test failed. |
| Shell/Python formatting checks | `bash -n` on audit shell scripts; `py_compile` on release/seed Python scripts; `git diff --check` | Exit 0. `gofmt -w` was applied to the two changed CLI Go files. |

The Harbor warnings are non-fatal and no product behavior failure was observed from them. This remains unit/component-suite evidence only. R49 is invalidated by #240; no result here counts toward any matrix cell. The `admiralctl` CI passed in run 39724553667; root audit CI passed in run 39724727343. Their runner/action migration notices are tracked in #243. Release 50 was later built and recorded in `release50-candidate.md`, then superseded before VM testing by #244.

## Release 50 audit SSH bootstrap follow-up — 2026-10-22

The #239 harness change added five focused tests; `python3 -m pytest -q scripts/test_audit_vm_hostkeys.py` passed 5/5 and `python3 -m pytest -q scripts/test_*.py` passed **118/118**. Fresh Fedora Rawhide and Rocky Linux 10.2 guests booted from the pre-updated seeds and accepted the first SSH connection with `StrictHostKeyChecking=yes` using the host-generated key pin. The guest-reported key fingerprints matched the host's public-key fingerprints. No RPM was installed and no full OS update ran. ISO inspection verified that cloud-init's private-bearing `user-data` and `meta-data` retained mode `0600`. Both guests were shut down and cleaned with the audited helper; overlays, cloud-init ISO/private-key material and matching DHCP reservations were removed. Detailed procedure and results: `ssh-host-key-bootstrap.md`. The root source is signed commit `54d4a6b2e3843cb22f33526c198b32e4ac8e53bf` on `origin/main`; CI run 39726030742 passed. R50 was superseded before VM testing by #244. The check is in `012a571f3ffb2f4bfc58eed82c5778a92d07314c` with green CI run 39727055542; R51 package-preparation CI [39727420397](https://github.com/admiral-project/admiral/actions/runs/39727420397) passed and all six R51 `%check` stages completed successfully. Runtime matrix execution remains 0/8.
