# RC5 Release 73 candidate record

**Status: source fix for #272 is pushed and its CI is green; coordinated RPM builds are pending. Matrix: 0/8.** R72 is invalidated; no runtime evidence from another candidate carries forward.

## Scope

Four x86_64 operating systems: Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10. Each must pass both Single-Node and a real three-guest Multi-Node cell. Fedora receives only native `.fc46` RPMs; the three EL10 systems receive native `.el10` RPMs. No `--nodeps` installation is permitted.

## Selected component refs

The root repository fetched every component `origin/main` before preparing R73. Each selected component SHA below matched its `origin/main`; the source fix in `admirald` is included.

| Repository | Selected SHA | CI |
|---|---|---|
| `admirald` | `83b4dd4db8963ac40a51c00fb9e52a9f2081df5c` | [40080443575](https://github.com/admiral-project/admirald/actions/runs/40080443575), success |
| `admiral-fleet` | `fc6909f6c41507d04aa204ebeafbbaaa4ef2c686` | [40069777965](https://github.com/admiral-project/admiral-fleet/actions/runs/40069777965), success |
| `admiralctl` | `fa2a65e866310bd82bea78859804b6c3aea7989a` | [40030034925](https://github.com/admiral-project/admiralctl/actions/runs/40030034925), success |
| `admiral-flagship` | `b7325bbc71fc474a521496e593b2967e4d555ac1` | [39795263415](https://github.com/admiral-project/admiral-flagship/actions/runs/39795263415), success |
| `admiral-harbor` | `dd39e9a74bf658ecf6fd6e9f8bd30b2ddf82d7db` | [39795262318](https://github.com/admiral-project/admiral-harbor/actions/runs/39795262318), success |

## Candidate contents

- Six coordinated Admiral RPMs at `0.0.1rc5-73`.
- #272 fix: controlled worker removal revokes its live and persistent WireGuard peer through a local systemd socket helper before deleting the node record and token. Failed revocation retains the database record/token for retry. Peer addition shares the same lock and confirms the node is still registered.
- `admirald` remains unprivileged; only the root helper service receives `CAP_NET_ADMIN`.
- Every package source ref is pinned to the selected component `origin/main`; the common installer payload is pinned to the root commit recorded after package preparation.

## Checks completed before RPM build

- `go test ./...`, `go test -race ./...` and `go vet ./...` in `admirald`: PASS. The GitHub CI run also passed its PostgreSQL-backed tests.
- All root `scripts/test_*.py` suites: PASS, including installer (76 tests), WireGuard peer add (3), peer revoke (6), and WireGuard role regressions (12).
- `bash -n scripts/install.sh`, Python compilation, Ansible syntax checks for `ansible/site.yml` and `ansible/wireguard-peers.yml`, and staged `systemd-analyze verify`: PASS.
- `python3 scripts/validate-release-refs.py`: pending the final root source-ref commit.
- Six Release 73 RPMs, native EL10 and Fedora Rawhide `%check`, repository signature and NEVRA/SHA-256 manifest: pending.

## Runtime matrix

Every R73 cell starts `NOT TESTED`; matrix **0/8**. All eight cells must use fresh overlays from updated OS seeds and the exact Release 73 package set. Complete the acceptance checklist in master issue [#200](https://github.com/admiral-project/admiral/issues/200), including active-worker refusal, idle-worker revocation, post-removal hub reboot, and negative access checks.

| Platform | Single-Node | Multi-Node |
|---|---|---|
| Fedora Rawhide x86_64 | NOT TESTED | NOT TESTED |
| Rocky Linux 10 x86_64 | NOT TESTED | NOT TESTED |
| AlmaLinux 10 x86_64 | NOT TESTED | NOT TESTED |
| CentOS Stream 10 x86_64 | NOT TESTED | NOT TESTED |
