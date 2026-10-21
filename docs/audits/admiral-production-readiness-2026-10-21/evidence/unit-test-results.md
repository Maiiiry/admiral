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
