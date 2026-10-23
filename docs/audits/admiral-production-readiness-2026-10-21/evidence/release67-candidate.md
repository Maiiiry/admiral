# RC5 Release 67 candidate record

**Status: SIX RPMs BUILT FOR BOTH NATIVE TARGETS; LOCAL REPOSITORIES READY; SCOPED FEDORA AND ROCKY SINGLE-NODE, AND FEDORA MULTI-NODE, RUNTIME SCENARIOS PASSED. Matrix: 0/8.**

Release 66 is invalidated for active release-gate credit by the Fedora fresh
Multi-Node worker-install failure tracked in [issue #266](https://github.com/admiral-project/admiral/issues/266).
R66 observations remain historical only. The source fix is in root commit
`ad4f6caa0572ebeff54d3dfcb51f635cf346b31e`; root CI run
[39967404421](https://github.com/admiral-project/admiral/actions/runs/39967404421)
succeeded. The exact R67 packages are now built, but #266 remains open until a
fresh Fedora three-node install reproduces successful worker onboarding.

## Source identity

The RPM candidate was built from root commit
`833d15aa4f8e96be30d28dad169b9d06a4d9894d` on `origin/main`. Its root CI run
[39969149164](https://github.com/admiral-project/admiral/actions/runs/39969149164)
succeeded. Before each native build, all five component submodules were fetched
and compared with `origin/main`; `python3 scripts/validate-release-refs.py`
passed. The pins were unchanged and equal to published `origin/main` at the
time of build:

| Source | Selected commit |
| --- | --- |
| Root payload (`admiral-common`) | `ad4f6caa0572ebeff54d3dfcb51f635cf346b31e` |
| `admirald` | `643d203576037a12eba59d534d51d170acae9b5d` |
| `admiral-fleet` | `0c805d6293bfb11fd4f015f1b0ccff520481e627` |
| `admiralctl` | `49cf2428c064434c65af9a14f96975c1bb2db637` |
| `admiral-flagship` | `b7325bbc71fc474a521496e593b2967e4d555ac1` |
| `admiral-harbor` | `dd39e9a74bf658ecf6fd6e9f8bd30b2ddf82d7db` |

All six specs use `Release: 67%{?dist}`. The initial R67 package-preparation CI
run [39968176202](https://github.com/admiral-project/admiral/actions/runs/39968176202)
found stale Release 66 defaults in the three audit installer helpers. The
defaults were corrected in `a89a605c934e0ab23c382f6ff79569879f75e70e`; all 131
local helper tests passed and root CI run
[39968696770](https://github.com/admiral-project/admiral/actions/runs/39968696770)
succeeded. Issues #232 and #238 remain open pending exact R67 guest-path
validation. No issue was closed for this build.

## Native build environments

Builds were run in separate containers from the same selected source pins.
No EL10 RPM was copied to or installed in Fedora. No dependency bypass such as
`--nodeps` or `--force` was used. This separation is required by
[`docs/rpm_packaging.md`](../../../rpm_packaging.md).

| Target | Builder and toolchain | Result | Build log |
| --- | --- | --- | --- |
| Fedora Rawhide x86_64 | Fedora Linux 46 prerelease; base image `registry.fedoraproject.org/fedora:rawhide`, image SHA `428f565534c378b103a8ec89b338164726967d88fa562966ed69cf5b3af100aa`; builder image `localhost/admiral-r67-fedora-buildenv:rawhide`, SHA `3fbc282eb01de8881d6ed5fa06627d2d3ac844a158f7b7f7ff2d8a4b6713281a`; RPM 6.1.0, Go 1.27.3, Python 3.15.0, `%{dist}=.fc46`, x86_64 | All six `.fc46` RPMs built. Three Go component test suites ran; Harbor `%check` reported 350 passed in 229.76 s. | Local mode-0600 log `/tmp/admiral-r67-fedora-native/packaging/build/validation/rc5-r67/fedora-in-container-build.log`; SHA-256 `62afcd8eb3709a8438bce12ecb578df6ba8e7f787fbc9415a4f9fa4ef737dc87`. |
| EL10 x86_64 | Rocky Linux 10.2 image `quay.io/rockylinux/rockylinux:10.2`, SHA `0b5329d806d053ad65ab6b21fc3e49f1025e970cd826547a01a93b3ce9012796`; RPM 4.19.1.1, Go 1.26.10, Python 3.12.15, `%{dist}=.el10`, x86_64 | All six `.el10` RPMs built. Three Go component test suites ran; Harbor `%check` reported 350 passed in 197.34 s. | Local mode-0600 log `/tmp/admiral-r67-el10/packaging/build/validation/rc5-r67/el10-in-container-build.log`; SHA-256 `12cff500a41033724b98eaaf19d20c2c426e4800abe907445e6381ff9402c644`. |

The Fedora helper build dependencies came only from Fedora-tagged helper RPMs;
the EL10 helper build dependencies came only from EL10-tagged RPMs. Each
filtered source contained eight Python helper packages and no Admiral Release
66 binaries. Both logs end with `All 6 Admiral RPMs built`.

### Excluded accidental host build attempt

An earlier command was accidentally run on the Rocky Linux 10.2 host instead of
inside the Fedora builder. It produced only a partial `.el10` `admiral-common`
RPM/SRPM and was stopped. The artifacts and mode-0600 log are retained under
`/tmp/admiral-r67-fedora/packaging/build/validation/rc5-r67/invalid-host-el10-partial/`.
The partial RPM SHA-256 is
`b4a0aa34c83f2cd64af90c4c585f637d46abe15fc00ca36fe6e7232d2e78e671`; the
aborted log SHA-256 is
`3a58bc0e706ee814aa2027ba133def822f000bf11b08396008cf4d22d9bee3545`.
Those files are excluded from both R67 repositories and all validation. No
RPM was installed during this attempt.

## Candidate packages and local repositories

Each repository has exactly 14 RPMs: six Release 67 Admiral packages and eight
Python helper RPMs carrying that target's distribution tag. The generated
manifests record package name, epoch, version, release, architecture, filename
and SHA-256:

| Target | Admiral NEVRAs | RPM manifest SHA-256 | Repository endpoint | `repomd.xml` SHA-256 |
| --- | --- | --- | --- | --- |
| EL10 x86_64 | `admiral-common-0.0.1rc5-67.el10.noarch`, `admirald-0.0.1rc5-67.el10.x86_64`, `admiral-fleet-0.0.1rc5-67.el10.x86_64`, `admiralctl-0.0.1rc5-67.el10.x86_64`, `admiral-flagship-0.0.1rc5-67.el10.noarch`, `admiral-harbor-0.0.1rc5-67.el10.noarch` | [`release67-el10-RPM-MANIFEST.tsv`](release67-el10-RPM-MANIFEST.tsv), `786ac354b6c5dbdb51e51a70cabe77f7706080b864dfc2089cec8a9ccc094e80` | `http://192.168.122.1/rc5-r67/el10/x86_64/` (HTTP 200) | `1adbd99476d2995ff25f1afb8a26f326304e0bd955839ab7a301dcd08371d6a3` |
| Fedora Rawhide x86_64 | `admiral-common-0.0.1rc5-67.fc46.noarch`, `admirald-0.0.1rc5-67.fc46.x86_64`, `admiral-fleet-0.0.1rc5-67.fc46.x86_64`, `admiralctl-0.0.1rc5-67.fc46.x86_64`, `admiral-flagship-0.0.1rc5-67.fc46.noarch`, `admiral-harbor-0.0.1rc5-67.fc46.noarch` | [`release67-fedora-RPM-MANIFEST.tsv`](release67-fedora-RPM-MANIFEST.tsv), `9f4e70e1b2b6eb4ea950a76816d96daa7f224374c49b607cf18ddc2f0147acdb` | `http://192.168.122.1/rc5-r67/fedora/x86_64/` (HTTP 200) | `4016374de0c03a0e4596ff080295cca6bf53f41908bd302cb7022ce17dcab8e5` |

The local repository root is
`/var/lib/libvirt/images/admiral-validation/repo/rc5-r67/`. Repo configs for
the guest helpers are in the ignored local build directory
`packaging/build/validation/rc5-r67/`. The two distro repositories are
separate; each package filename and manifest release tag was checked before
publication. No public RPM service was modified.

## Scoped R67 Fedora Multi-Node bootstrap result

A fresh Fedora three-guest test used the exact R67 `.fc46` packages and local
Fedora repo. Hub and both workers completed their secure installers with zero
failed/unreachable tasks. The corrected `admiral-common`-before-resolver order
passed on both fresh workers; each enrolled with an active/healthy heartbeat,
metrics, a WireGuard handshake, LLMNR disabled, and no temporary bootstrap
credential still accepted. Hub and workers ran with SELinux Enforcing. This
validates the targeted #266 regression only; no workload scenario ran and it
does not complete a Fedora Multi-Node release cell. Full steps, IDs, recaps,
timings and log hashes are recorded in
[`release67-fedora-multinode-bootstrap.md`](release67-fedora-multinode-bootstrap.md).

## Scoped R67 Fedora Multi-Node workload result

On the same fresh three-guest topology, the exact `.fc46` candidate then passed
one small `e2e-whoami` workload lifecycle on each worker in turn. Both explicit
placements returned `succeeded` and `running/healthy/available`; sequential
same-key replay returned the original operation and instance. PostgreSQL was
ready on poll 2, each SQL marker was inserted/read back, and the hub received
HTTP 200 from each worker over WireGuard. Both deprovisions succeeded and left
no matching containers, pods, volumes, user units or files. A post-check found
all three nodes active/healthy/available, zero active pods, and the exact R67
`.fc46` package set on hub and workers. This is scoped workload evidence, not
a complete Multi-Node cell. The procedure, operation/instance IDs, raw-log
hashes, and one failed harness attempt are recorded in
[`release67-fedora-multinode-placement.md`](release67-fedora-multinode-placement.md).

## Repository helper correction discovered during R67 staging

Reviewing the existing `publish-candidate-repo.sh` exposed a latent cross-distro
staging defect: it copied EL10 Python helper RPMs into the Fedora candidate
repository (with a special Fedora Mistune exception). R67 was staged only after
replacing this with explicit distro-specific source paths and checks that
reject the wrong tag and require all eight helper RPMs. The new Release 67 repos
were generated by that corrected script and were verified as 14-package repos
with HTTP 200 metadata for each target. This is related to open issue
[#261](https://github.com/admiral-project/admiral/issues/261), which tracks
candidate repository correctness. A fresh Fedora hub installed the six exact
`.fc46` Admiral RPMs from this repo through DNF; fresh workers also installed
exact `.fc46` common/Fleet packages. Equivalent fresh-guest DNF install
validation for EL10 remains pending. The issue remains open.

## Scoped R67 Fedora and Rocky Single-Node results

Fresh Fedora Rawhide 46 and Rocky Linux 10.2 guests installed the exact
Release 67 packages from the matching local repositories. Both secure
installers completed with `failed=0` and `unreachable=0`; their workers were
active, healthy and available, with SELinux Enforcing and no failed systemd
units. Fedora contained only `.fc46` Admiral RPMs; Rocky contained only
`.el10` Admiral RPMs. Neither installation used a dependency bypass.

Both guests passed a scoped `e2e-whoami` lifecycle: same-key replay returned
the original operation/instance, PostgreSQL accepted connections, SQL markers
were written/read, the loopback HTTP endpoint returned 200, and deprovision
left no matching containers, pods, volumes, units or files. Both then passed a
real host reboot/data recovery probe: boot IDs changed, the API remained
unavailable while runtime services were absent, and returned to
healthy/available only after all three containers and PostgreSQL were ready;
HTTP and marker data persisted, and cleanup succeeded. Full IDs, seed hashes,
per-step statuses, harness failures and mode-0600 raw-log hashes are in
[`release67-single-node-targeted.md`](release67-single-node-targeted.md).

These results are targeted regressions, not completed Single-Node cells.
AlmaLinux and CentOS Stream have not yet run R67 Single-Node tests. The updated
seeds already contain support packages, so fresh-image dependency closure is
also not proven. Backup/restore, external storage, tenant isolation, conflicting
concurrency, failure injection, resource pressure and performance scenarios
remain outstanding.

## Validation state

- Active target: Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream
  10 x86_64 × Single-Node/Multi-Node.
- Matrix: **0/8**. RPM builds, CI and repository metadata do not count as a
  runtime cell pass.
- Scoped fresh Fedora and Rocky Single-Node install/lifecycle/reboot scenarios
  passed on exact R67 packages. Fedora additionally passed fresh three-node
  secure bootstrap and one workload placement/replay/HTTP/SQL/deprovision
  cycle on each worker. These results do not give complete matrix cell credit.
- Continue remaining Single-Node and Multi-Node scenarios across the four
  x86_64 OSes using only exact Release 67 RPMs built for each distro.
- Broad isolation, stress/performance, resource-exhaustion, interruption and
  failure-injection scenarios remain outstanding.
