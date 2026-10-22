# Admiral RC5 Release 55 preparation — pre-build checkpoint

- Recorded: 2026-10-22 UTC.
- Status: **PREPARED, NOT BUILT**. No Release 55 RPM or VM result exists yet.
- Active matrix: Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10, x86_64, Single-Node and Multi-Node (8 cells).
- Matrix status: **0/8**; all cells remain NOT TESTED for Release 55.

## Why Release 54 was invalidated

Release 54 built and completed its RPM checks, but a real CentOS Stream 10 x86_64 Single-Node test found that one of three simultaneous same-key provision calls returned a capacity rejection instead of replaying the operation. The finding is open as [#254](https://github.com/admiral-project/admiral/issues/254), labeled `fix-proposed`, and detailed in `release54-invalidation-concurrent-idempotency.md`. All Release 54 runtime probes are candidate-specific and do not count toward Release 55.

## Selected source references

Immediately before preparing this package set, the root repository and all five component remotes were fetched. Each component checkout matched its current `origin/main`:

| Component | Selected `origin/main` SHA |
| --- | --- |
| `admirald` | `afcf02f094cf7c572cd0e135a280ebb48c0202d5` |
| `admiral-fleet` | `3cb2bf83d9787947d3b3212f6c1f92bf3fa81fda` |
| `admiralctl` | `49cf2428c064434c65af9a14f96975c1bb2db637` |
| `admiral-flagship` | `b7325bbc71fc474a521496e593b2967e4d555ac1` |
| `admiral-harbor` | `dd39e9a74bf658ecf6fd6e9f8bd30b2ddf82d7db` |

The `admiral-common` RPM uses root source snapshot `3888e28a77a0e81a0e7c7fb8ddbf636bcce181a4`. The packaged Ansible/installer payload matches the current root tree; `python3 scripts/validate-release-refs.py` verified this exception and all component/spec/Makefile references.

The #254 fix was pushed in `admirald` commit `bedcecccb4d001a30da815c5471567a82714a31a`. Its first CI run [39811936913](https://github.com/admiral-project/admirald/actions/runs/39811936913) failed in the migration cutover test; analysis identified #255, a post-publish `queued` update racing with task completion. That transition and the test were fixed in current `admirald@afcf02f094cf7c572cd0e135a280ebb48c0202d5`. Focused tests, the full Go suite, vet and build pass locally against isolated PostgreSQL. CI run [39813463149](https://github.com/admiral-project/admirald/actions/runs/39813463149) is pending.

## Package version preparation

All six Admiral spec files now declare Release 55. The RPM build must wait for green component CI and green root CI for the signed Release 55 preparation commit. No package has been built at this checkpoint.

| RPM | Expected NEVRA after successful build |
| --- | --- |
| `admiral-common` | `admiral-common-0.0.1rc5-55.el10.noarch` |
| `admirald` | `admirald-0.0.1rc5-55.el10.x86_64` |
| `admiral-fleet` | `admiral-fleet-0.0.1rc5-55.el10.x86_64` |
| `admiralctl` | `admiralctl-0.0.1rc5-55.el10.x86_64` |
| `admiral-flagship` | `admiral-flagship-0.0.1rc5-55.el10.noarch` |
| `admiral-harbor` | `admiral-harbor-0.0.1rc5-55.el10.noarch` |

After the build, record the exact root commit, build host, all six RPM SHA-256 values, build/test logs, and repository metadata before starting fresh Release 55 VM overlays. No Release 54 evidence will be reused as a Release 55 pass.
