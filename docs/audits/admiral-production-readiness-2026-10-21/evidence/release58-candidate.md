# Admiral RC5 Release 58 local candidate

## State

Release 58 was built locally on Rocky Linux 10.2 x86_64. The six Admiral RPMs and the eight Python RPMs used by Flagship/Harbor are staged in `packaging/build/repos/el10-rc5-r58-x86_64/`; their hashes are in `release58-rpm-sha256.txt`. The repo is local only, with no COPR publication. The exact six-package Release 58 set was installed on fresh disposable Rocky Linux 10.2, AlmaLinux 10.2 and CentOS Stream 10 overlays, followed by the named targeted scenarios in `release58-el10-single-node-execution.md`. One intermittent false-availability observation during user-systemd manager restart invalidated R58 for release validation (#259). No full matrix cell passed; matrix remains **0/8** and R58 is not validated.

The exact Python RPM set is Flask `1:3.1.3-3.el10`, SQLAlchemy `2.0.55-2.el10`, Alembic `1.20.1-2.el10`, Flask-Alembic `3.3.0-2.el10`, Flask-Login `0.6.3-8.el10`, Flask-SQLAlchemy `3.1.1-8.el10`, Mistune `3.4.0-1.el10`, and typing-extensions `4.16.0-1.el10`. SQLAlchemy's native extension build used the x86_64-v2 baseline.

## Source pins

Before building, the root and five component repositories were fetched from `origin/main`; each selected SHA matched its `origin/main` SHA. `python3 scripts/validate-release-refs.py` passed.

| Repository | SHA |
|---|---|
| root | `321e968` |
| admirald | `9b8f129` |
| admiral-fleet | `74e8b0f` |
| admiralctl | `49cf242` |
| admiral-flagship | `b7325bb` |
| admiral-harbor | `dd39e9a` |

## Local validation performed

| Check | Result | Evidence |
|---|---|---|
| Flagship unit suite with the staged Python RPM stack | PASS — 266 passed in 19.87 s | `python3 -m pytest tests/ -x --tb=short` in `admiral-flagship`, with staged RPM site-packages first in `PYTHONPATH` |
| Harbor unit suite with the staged Python RPM stack | PASS — 350 passed in 223.05 s | Same command in `admiral-harbor` |
| `go test ./...` in `admirald` | PASS | `packaging/build/validation/go-admirald-tests.log` |
| `go test ./...` in `admiral-fleet` | PASS | `packaging/build/validation/go-fleet-tests.log` |
| `go test ./...` in `admiralctl` | PASS | `packaging/build/validation/go-admiralctl-tests.log` |
| SQLAlchemy RPM build and C-extension smoke check | PASS | `packaging/build/validation/python-sqlalchemy-rpm-v2.log` |
| DNF install transaction for all six R58 Admiral RPMs, with the Admiral COPR disabled | PASS — solver selected R58 and the exact local Python RPM set; transaction intentionally declined with `--assumeno` | `packaging/build/validation/dnf-install-r58-local-only.log` |
| DNF BuildRequires resolution for Flagship and Harbor, with the Admiral COPR disabled | PASS — exact local Flask and Harbor stack resolved; transactions intentionally declined with `--assumeno` | `packaging/build/validation/dnf-builddep-admiral-flagship-r58.log`, `packaging/build/validation/dnf-builddep-admiral-harbor-r58.log` |

The six Admiral RPMs were packaged with `make rpm-admiral-no-test RPMFLAGS_EXTRA=--nodeps`. That bypassed the builder's installed BuildRequires versions and skipped RPM `%check`; the builder's system Python RPMs are older than the pinned candidate. The two application suites were run separately against the exact staged Python RPM contents, and DNF resolved the candidate's pinned runtime and build dependency metadata. The COPR build and clean-guest install remain required.

## Pending release validation

The recorded guest execution used the private local RPM repo, not COPR. Build the exact SRPMs in the target COPR and inspect every build result. Then complete the full required scenario set on fresh Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 guests, including three-guest Multi-Node topologies. Only targeted R58 scenarios have run on three EL10 Single-Node guests; none of the eight full matrix cells has passed. Production readiness remains **NOT VALIDATED**.
