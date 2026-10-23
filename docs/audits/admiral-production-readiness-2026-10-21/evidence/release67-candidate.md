# RC5 Release 67 candidate record

**Status: PACKAGE PREPARATION IN PROGRESS — NOT BUILT, NOT INSTALLED, NO R67 RUNTIME RESULTS.**

Release 66 is invalidated for the active release validation by the fresh Fedora
Multi-Node worker-install failure tracked in [issue #266](https://github.com/admiral-project/admiral/issues/266).
Its RPM and runtime observations remain historical only and do not count as
Release 67 evidence. The source correction is in root commit
`ad4f6caa0572ebeff54d3dfcb51f635cf346b31e`; root CI run
[39967404421](https://github.com/admiral-project/admiral/actions/runs/39967404421)
succeeded. The issue remains open and labeled `fix-proposed` until the exact
R67 packages reproduce successful fresh worker onboarding.

## Source identity

| Source | Selected commit | Evidence |
| --- | --- | --- |
| Root package payload (`admiral-common`) | `ad4f6caa0572ebeff54d3dfcb51f635cf346b31e` | Contains the resolver-policy task ordering fix. |
| `admirald` | `643d203576037a12eba59d534d51d170acae9b5d` | Fetched `origin/main`; equals latest published `origin/main` at candidate preparation. |
| `admiral-fleet` | `0c805d6293bfb11fd4f015f1b0ccff520481e627` | Fetched `origin/main`; equals latest published `origin/main` at candidate preparation. |
| `admiralctl` | `49cf2428c064434c65af9a14f96975c1bb2db637` | Fetched `origin/main`; equals latest published `origin/main` at candidate preparation. |
| `admiral-flagship` | `b7325bbc71fc474a521496e593b2967e4d555ac1` | Fetched `origin/main`; equals latest published `origin/main` at candidate preparation. |
| `admiral-harbor` | `dd39e9a74bf658ecf6fd6e9f8bd30b2ddf82d7db` | Fetched `origin/main`; equals latest published `origin/main` at candidate preparation. |

The specs and source references were prepared in root commit `779391e0be9589339c97cb2cb2255caa8f80cc85`. Its CI run [39968176202](https://github.com/admiral-project/admiral/actions/runs/39968176202) failed because three audit installer helpers still defaulted to Release 66 after the coordinated spec bump. The defaults were corrected in root commit `a89a605c934e0ab23c382f6ff79569879f75e70e`; local `python3 -m pytest -q scripts/test_*.py` passed (131 tests), and root CI run [39968696770](https://github.com/admiral-project/admiral/actions/runs/39968696770) succeeded. Existing issues [#232](https://github.com/admiral-project/admiral/issues/232) and [#238](https://github.com/admiral-project/admiral/issues/238) track the helper defaults; both remain open pending the exact Release 67 guest install-path checks. The candidate build checkout will include `a89a605` and the unchanged Release 67 specs.

The component pins were re-fetched from each `origin/main` immediately before preparation and matched the selected SHAs above. Their latest CI runs for those exact commits succeeded: `admirald` run [39916850987](https://github.com/admiral-project/admirald/actions/runs/39916850987), `admiral-fleet` run [39878457179](https://github.com/admiral-project/admiral-fleet/actions/runs/39878457179), `admiralctl` run [39796863070](https://github.com/admiral-project/admiralctl/actions/runs/39796863070), `admiral-flagship` run [39795263415](https://github.com/admiral-project/admiral-flagship/actions/runs/39795263415), and `admiral-harbor` run [39795262318](https://github.com/admiral-project/admiral-harbor/actions/runs/39795262318). Before the actual RPM builds, fetch and compare all five component `origin/main` refs once more. `python3 scripts/validate-release-refs.py` passed before the package-preparation push and must pass again in the build checkout.

## Coordinated package set

All six Admiral specs are bumped together to `Release: 67%{?dist}`:
`admiral-common`, `admirald`, `admiral-fleet`, `admiralctl`,
`admiral-flagship`, and `admiral-harbor`. The package source is identical across
targets; the RPM binaries are built separately for Fedora Rawhide and EL10.

**Toolchain separation is a release requirement:** Fedora Rawhide RPM binaries
must be compiled in a Fedora Rawhide build environment from these pinned
sources, using Fedora RPM macros, BuildRequires, and test dependencies. EL10
RPM binaries must be compiled in an EL10 environment. Never install or use an
EL10-built binary RPM as a Fedora package, and never bypass Fedora dependency
resolution with `--nodeps`, `--force`, or an equivalent option. Fedora results
must be Fedora-tagged RPMs (for example `.fc46`); EL10 results must be
EL10-tagged RPMs (for example `.el10`). The native-builder rule is also in
[`docs/rpm_packaging.md`](../../../rpm_packaging.md).

| Target | Build environment | Candidate artifact status |
| --- | --- | --- |
| Fedora Rawhide x86_64 | `registry.fedoraproject.org/fedora:rawhide`, image ID `sha256:428f565534c378b103a8ec89b338164726967d88fa562966ed69cf5b3af100aa` (Fedora 46 prerelease) | NOT BUILT |
| EL10 x86_64 | Native EL10 builder; exact image/host identity to be recorded before build | NOT BUILT |

For Fedora BuildRequires, the Fedora builder is provisioned with the Fedora
Rawhide-built Python helper RPMs from the filtered local R66 Fedora repository
`packaging/build/repos/fedora-rawhide46-rc5-r66-x86_64` (only `python3-*.fc46.*.rpm`
files were copied; the six R66 Admiral RPMs were excluded). NEVRAs and hashes
for those helper RPMs are in the historical
[`release66-fedora-RPM-MANIFEST.tsv`](release66-fedora-RPM-MANIFEST.tsv). These
`.fc46` Python packages are build dependencies only; they are not R67 Admiral
artifacts. No `.el10` RPM was copied to or installed in the Fedora builder.

After successful builds, add per-target RPM manifests with package NEVRA and
SHA-256, builder versions, build logs, and local-repository metadata. Do not
reuse R66 binaries as R67 packages.

## Validation state

- Active target remains four x86_64 OSes (Fedora Rawhide, Rocky Linux 10,
  AlmaLinux 10, CentOS Stream 10) × Single-Node/Multi-Node.
- Matrix: **0/8**. No cell is validated by the R67 source change, CI, or build.
- R66 targeted runtime results are historical and invalidated for release-gate
  credit; rerun required scenarios against the exact R67 NEVRAs.
- First required R67 runtime check: fresh Fedora three-node secure install,
  including both workers, resolver policy, LLMNR verification, worker
  enrollment, heartbeat, and cleanup. Then continue the remaining R67 matrix.
- No RPM build, Fedora/EL10 package installation, or R67 runtime test has yet
  been performed at the time this record was created.
