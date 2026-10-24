# RC5 Release 72 candidate record

**Status: INVALIDATED by #272.** R72 root source commit was `4ee49d836c1012a89af2023893674347e02db2be`. Runtime ended at **4/8 PASS** (the four Single-Node cells), **2/8 PARTIAL** (AlmaLinux 10 and CentOS Stream 10 Multi-Node), and **2/8 NOT TESTED** (Rocky Linux 10 and Fedora Rawhide Multi-Node). Both Multi-Node runs reproduced a stale live and persistent WireGuard peer after worker removal. R72 earns no credit for R73.

## Scope

Four x86_64 operating systems: Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10, in Single-Node and three-guest Multi-Node modes.

## Selected source commits

All five component repositories were fetched from `origin/main` before preparing this release. The chosen refs are their current published main commits.

| Repository | Selected SHA | CI |
|---|---|---|
| `admirald` | `a7829dbf9b22149740813c3190b1aeb1a7389c4f` | [40069613232](https://github.com/admiral-project/admirald/actions/runs/40069613232), success |
| `admiral-fleet` | `fc6909f6c41507d04aa204ebeafbbaaa4ef2c686` | [40069777965](https://github.com/admiral-project/admiral-fleet/actions/runs/40069777965), success |
| `admiralctl` | `fa2a65e866310bd82bea78859804b6c3aea7989a` | prior exact-commit CI green; no source change |
| `admiral-flagship` | `b7325bbc71fc474a521496e593b2967e4d555ac1` | prior exact-commit CI green; no source change |
| `admiral-harbor` | `dd39e9a74bf658ecf6fd6e9f8bd30b2ddf82d7db` | prior exact-commit CI green; no source change |

## Fixes included

- Fleet persists only declared service healthcheck metadata in a root-owned mode-0600 per-instance file; environment values and secrets are excluded. Periodic health reporting now evaluates command, HTTP and TCP checks and suppresses healthy routing when a declared check fails. Provision retries, start/resume and resize refresh the metadata.
- HTTP healthcheck clients refuse redirects so a workload cannot make Fleet probe another host through a redirect. Issue [#271](https://github.com/admiral-project/admiral/issues/271) tracks the security regression and remains open.
- Existing readiness gap [#236](https://github.com/admiral-project/admiral/issues/236) remains open pending exact-RPM and broader topology validation.

R71's Fedora false-availability samples are detailed in [`release71-candidate.md`](release71-candidate.md). They invalidate R71 only; R72 will be evaluated from fresh overlays.

## Local source checks

- `go test ./...` in `admirald`, `admiral-fleet`, and `admiralctl`: PASS. Fleet tests include command/HTTP healthcheck behavior, secret-free mode-0600 metadata, and redirect prevention.
- Fleet `go vet ./...`: PASS.
- Fleet `go build ./...`: PASS.
- `python3 scripts/validate-release-refs.py`: pending after root commit.
- Six Release 72 RPMs, native EL10 and native Fedora Rawhide `%check`, local repository signatures and SHA-256 manifest: pending.

## Runtime outcome

The four Single-Node cells passed the functional checklist on the exact R72 packages. AlmaLinux and CentOS Stream Multi-Node did not pass: controlled idle-worker removal left the removed peer's `/32` route in the live hub interface and persistent configuration; from the removed worker the hub's private admin UI still returned HTTP 200. The Fleet token was rejected with HTTP 401. Rocky Linux and Fedora Rawhide Multi-Node were not tested. Reproduction evidence is retained in `packaging/build/validation/rc5-r72/runtime/artifacts/alma-mn/node-removal-w2-retry1/` and `.../centos-mn/node-removal-w2/wireguard-residual/`.

The defect is tracked by [#272](https://github.com/admiral-project/admiral/issues/272). The follow-up source fix is proposed in `admirald` commit `83b4dd4`; it requires a fresh Release 73 build and all eight new cells. The release checklist remains in master issue [#200](https://github.com/admiral-project/admiral/issues/200).
