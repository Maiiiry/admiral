# RC5 Release 69 candidate record

Audit: `ADM-AUDIT-2026-10-21`
Candidate: Admiral RC5 Release 69 (`0.0.1rc5-69`)
Active runtime scope: Rocky Linux 10 x86_64; Single-Node and Multi-Node (two functional cells).

## Exact source identity

The package source is root commit `bc1cd97acdafba043eca17180fdf2961049a46ad` on `origin/main`. `python3 scripts/validate-release-refs.py` passed and confirmed the RPM source references match the selected component commits.

| Repository | Selected SHA | Exact-commit CI |
|---|---|---|
| `admiral` packaging/root | `bc1cd97acdafba043eca17180fdf2961049a46ad` | [40052741102 — success](https://github.com/admiral-project/admiral/actions/runs/40052741102) |
| `admirald` | `a4d39ae6b5db92bd7e6e5257dc8f6b919af52668` | [40030035439 — success](https://github.com/admiral-project/admirald/actions/runs/40030035439) |
| `admiral-fleet` | `029bb53da6c2bef7d567213a5fd6ab106d56d68c` | [40052142923 — success](https://github.com/admiral-project/admiral-fleet/actions/runs/40052142923) |
| `admiralctl` | `fa2a65e866310bd82bea78859804b6c3aea7989a` | [40030034925 — success](https://github.com/admiral-project/admiralctl/actions/runs/40030034925) |
| `admiral-flagship` | `b7325bbc71fc474a521496e593b2967e4d555ac1` | [39795263415 — success](https://github.com/admiral-project/admiral-flagship/actions/runs/39795263415) |
| `admiral-harbor` | `dd39e9a74bf658ecf6fd6e9f8bd30b2ddf82d7db` | [39795262318 — success](https://github.com/admiral-project/admiral-harbor/actions/runs/39795262318) |

These CI runs validate their exact source commits; they do not validate runtime behavior.

## Native RPM artifacts

The active Rocky gate uses the six Admiral RPMs with coordinated Release 69 and `.el10` release tags, built with the EL10 toolchain. The Rocky guest installed only the native signed EL10 repository packages through normal DNF dependency resolution. No cross-distribution RPM, `--nodeps`, `--force`, vendor override or equivalent dependency bypass was used.

The signed EL10 repository contains 14 RPMs: six Admiral packages and eight Python helper packages. The [EL10 manifest](release69-el10-RPM-MANIFEST.tsv) records exact NEVRA and SHA-256; [checksums](release69-el10-RPM-SHA256SUMS) were verified against served artifacts, and all package signatures validated with the lab RPM key. The helper RPM set includes Flask 3.1.3, Flask-Alembic 3.3.0, Flask-Login 0.6.3, Flask-SQLAlchemy 3.1.1, Alembic 1.20.1, SQLAlchemy 2.0.55, Mistune 3.4.0 and typing-extensions 4.16.0.

## Validation seeds and dependency exception

The Rocky R69 overlay was created from the updated Rocky seed documented in [`release66-candidate.md`](release66-candidate.md). Seed preparation pins EPEL `python3-pyOpenSSL-25.0.0-1.el10_1` and excludes the incompatible newer EPEL build, whose cryptography requirement cannot be met by the EL10 base. This is a validation-environment dependency constraint and does not alter Admiral RPM requirements. The initial no-pin DNF attempt failed; the failure was preserved, then a fresh normal DNF transaction with the documented pin resolved the exact candidate package set. Issue #269 tracks the reproducible seed setup; it remains open.

## Candidate boundary and current state

R69 package source identity remains the commit above; audit report/script commits do not change the RPM payload. Any required product source or spec fix invalidates this candidate's runtime evidence and requires a coordinated rebuild with all six Release fields incremented. The Rocky Single-Node functional cell is **PASS** on its checklist; the Rocky Multi-Node functional cell is **NOT TESTED**. Matrix status is **1/2**. Production security, exhaustive isolation, public DNS/certificate deployment and performance are outside this functional gate and are not certified by these results.
