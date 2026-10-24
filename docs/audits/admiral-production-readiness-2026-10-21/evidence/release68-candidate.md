# RC5 Release 68 candidate and build record

Audit: `ADM-AUDIT-2026-10-21`
Candidate: Admiral RC5 Release 68 (`0.0.1rc5-68`)
Runtime target: x86_64 only; Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10; Single-Node and Multi-Node. ARM64 remains Tier 2 and non-blocking for this release gate.

## Exact source identity

Package-preparation commit on `origin/main`: `4077c4ddb9d233682961d36c3570c63e70eb6405`. `python3 scripts/validate-release-refs.py` passed against the checked-out source references. The root repository's `Main Regression Tests` run [40030603049](https://github.com/admiral-project/admiral/actions/runs/40030603049) succeeded for that exact commit.

| Component repository | Selected source SHA | Exact-commit CI |
|---|---|---|
| `admiral` (packaging and `admiral-common`) | `4077c4ddb9d233682961d36c3570c63e70eb6405` | [40030603049 — success](https://github.com/admiral-project/admiral/actions/runs/40030603049) |
| `admirald` | `a4d39ae6b5db92bd7e6e5257dc8f6b919af52668` | [40030035439 — success](https://github.com/admiral-project/admirald/actions/runs/40030035439) |
| `admiral-fleet` | `0c805d6293bfb11fd4f015f1b0ccff520481e627` | [39878457179 — success](https://github.com/admiral-project/admiral-fleet/actions/runs/39878457179) |
| `admiralctl` | `fa2a65e866310bd82bea78859804b6c3aea7989a` | [40030034925 — success](https://github.com/admiral-project/admiralctl/actions/runs/40030034925) |
| `admiral-flagship` | `b7325bbc71fc474a521496e593b2967e4d555ac1` | [39795263415 — success](https://github.com/admiral-project/admiral-flagship/actions/runs/39795263415) |
| `admiral-harbor` | `dd39e9a74bf658ecf6fd6e9f8bd30b2ddf82d7db` | [39795262318 — success](https://github.com/admiral-project/admiral-harbor/actions/runs/39795262318) |

These CI results are source-level evidence; they do not replace the runtime matrix.

## RPM sets

All six Admiral RPMs use Release 68. Fedora packages were built with Fedora Rawhide tooling and retain `.fc46`; EL10 packages were built with EL10 tooling and retain `.el10`. The build logs are local and mode `0600`: `packaging/build/validation/rc5-r68/fedora-build.log` (SHA-256 `6d79b779479875f238bf64fdcffd3bce020212e94452de4333333502c99f944c`) and `el10-build.log` (SHA-256 `8e631d2fe032c77c5613e01bac014fe5e35ca9123367fd137e16976a9bd5549b`). Both native build logs show all six package builds finishing and Harbor `%check` passing 350 tests. The two RPM manifests below record each Admiral package's exact NEVRA and SHA-256:

- [EL10 Release 68 RPM manifest](release68-el10-RPM-MANIFEST.tsv)
- [Fedora Release 68 RPM manifest](release68-fedora-RPM-MANIFEST.tsv)
- [EL10 RPM SHA-256 verification list](release68-el10-RPM-SHA256SUMS)
- [Fedora RPM SHA-256 verification list](release68-fedora-RPM-SHA256SUMS)

Verify either checksum list from `/var/lib/libvirt/images/admiral-validation/repo` with `sha256sum -c /root/admiral/docs/audits/admiral-production-readiness-2026-10-21/evidence/release68-{el10,fedora}-RPM-SHA256SUMS` (run separately for each file).

The runtime DNF transactions used only the matching distribution repository and the exact Release 68 candidate. Fedora guests received only `.fc46` packages; EL10 guests received only `.el10` packages. No `--nodeps`, `--force`, cross-distribution binary installation or equivalent dependency bypass was used. Signed repository verification imported the isolated lab key with fingerprint `558A F753 B5F4 8CE8 303F 3F56 688D E7E4 7E3D B9CD`. Clean-installroot resolution and signed-repository transcripts remain in the local mode-0600 `packaging/build/validation/rc5-r68/` directory.

Rocky Linux's updated validation seed includes the documented EPEL `python3-pyOpenSSL-25.0.0-1.el10_1` pin. This is a lab dependency-resolution constraint, not a product dependency change and not runtime pass evidence. The seed preparation and hashes are recorded in [`release66-candidate.md`](release66-candidate.md); those same unchanged updated seeds were used as parents for R68 disposable overlays, with Admiral installed afterward from the exact R68 repository.

## Runtime candidate boundary

R68 runtime work began only after this candidate's native RPM sets and references were checked. Each result applies only to the package NEVRAs/hashes above. Any required source or RPM fix creates a new candidate and invalidates affected R68 runtime credit. Documentation-only changes do not change these RPM payloads; their exact source identity remains the package-preparation commit above.

R68 has targeted Single-Node results on all four OSes. AlmaLinux 10.2 has a real three-guest Multi-Node lab with scoped exact-candidate results for explicit placement/replay/runtime/cleanup on W1 and W2, a three-client same-key idempotency race, the #267 active-worker-removal regression, and same-guest re-enrollment after removal. The race produced one operation/task/instance and converged to healthy/available and HTTP 200; a transient cold-start health observation remains associated with #236. **No cell is complete and matrix status remains 0/8.** See [`release68-single-node-progress.md`](release68-single-node-progress.md), [`release68-alma-multinode-placement.md`](release68-alma-multinode-placement.md), [`release68-alma-multinode-concurrent-idempotency.md`](release68-alma-multinode-concurrent-idempotency.md), [`release68-alma-multinode-node-removal.md`](release68-alma-multinode-node-removal.md), and the current [`TEST_MATRIX.md`](../TEST_MATRIX.md) for scoped outcomes and gaps.
