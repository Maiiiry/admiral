# Triage of open `fix-confirmed` issues (2026-10-24)

Scope: the 48 open issues labeled `fix-confirmed` after the 2026-10-24 bulk
triage. This review decides, per issue, whether it can move to `fixed` and be
closed or must return to `needs-work`. **Applied on 2026-10-24:** the 26
eligible issues were labeled `fixed` and closed; the 22 retained issues stay
`fix-confirmed`; none returned to `needs-work`.

Method: each issue was checked against the current component heads pinned by
root `ae46bdc` (`admirald@83b4dd4`, `admiral-fleet@fc6909f`,
`admiral-harbor@dd39e9a`, `admiralctl@fa2a65e`, `admiral-flagship@b7325bb`),
the green component/root CI runs, the issue's own acceptance criteria, and the
R66–R73 audit evidence.

Result:

| Disposition | Count |
|---|---|
| Eligible for `fixed` + close | 26 |
| Keep `fix-confirmed` (specific gate outstanding) | 22 |
| Return to `needs-work` | 0 |

No issue is code-incomplete. Every one of the 48 has its fix merged in `main`,
green CI on the fix commit or component head, and either regression tests or
local/guest evidence. The remaining work in the 22 retained issues is
issue-specific E2E evidence, not missing implementation.

## Eligible for `fixed` and closure (26)

Tooling, CI, and audit-harness issues whose acceptance is local and already
met:

| Issue | Evidence |
|---|---|
| #230 | `e0ca76e` removes the unused `local_ips` lookup; `ruff check scripts` is clean. |
| #232 | Helper defaults follow the coordinated Release; `test_audit_helpers_default_to_the_coordinated_rpm_release` plus R67 helper run pass. |
| #233 | `cleanup-audit-vm.sh` removes verified powered-off guest artifacts and the matching DHCP reservation; manual lab checks and CI 39724727343 pass. |
| #238 | All three audit helpers default to the coordinated Release; equality test covers all six specs; CI green. |
| #239 | `54d4a6b` generates per-guest host keys out-of-band and writes pinned `known_hosts`; CI 39726030742 and fresh Fedora/Rocky guests pass strict first contact. |
| #241 | `make test-admiralctl-local` / `scripts/test-admiralctl-local.sh` stages the pinned sibling module without touching either checkout. |
| #243 | All five component workflows use Ubuntu 24.04 and current Node 24 actions; component and root CI green. |
| #244 | `admiral-common.spec` has `%check` with `bash -n` and in-memory Python compile; R51 build entered `%check` with `RPM_EC=0`. |
| #247 | `verify-audit-vm-lease.py` runs before success; R71 stale-lease preflight failed closed without touching the unexpected guest. |
| #248 | `dd5eca4` records the pre-reboot boot ID and waits for a changed ID; R53 Fedora and Rocky reboot probes pass. |
| #252 | `623083f` provides per-worker SSH identity, pinned host keys and cleanup; later R66/R67 three-guest bootstraps use it. |
| #253 | `d7899ed` gives each isolation run unique IDs and idempotency keys; R54 Fedora/Rocky reruns pass. |

Product issues whose issue-specific verification is complete:

| Issue | Evidence |
|---|---|
| #211 | R67 Multi-Node hub reboot passes on all four OSes with peers, handshakes and workloads restored; Fleet persists `[Peer]` blocks in `wg-admiral.conf`. |
| #217 | WireGuard role re-asserts forwarding after `wg-quick` and asserts both sysctls; R66 partition/rejoin confirms handshakes with forwarding disabled. |
| #218 | SSH tunnel key is `admiral:admiral 0600` before the `User=admiral` service starts. |
| #225 | `StaffReply`, admin reply route, CSRF token and tests for CSRF/HTML escaping/isolation exist in Harbor HEAD (`test_admin.py:29`). |
| #227 | R66 failing-service fixture passes on all four Single-Node OSes and both EL10 Multi-Node labs. |
| #245 | `admirald@0baf488` prioritizes `stopped`, `paused_for_storage`, `deprovisioning` and `deprovisioned` with lifecycle reason codes and regression tests. |
| #254 | `admirald@bedcecc` replays the committed operation before a capacity rejection; R68 AlmaLinux same-key race passes. |
| #261 | R67 stages distro-native repos and fresh Fedora/Rocky guests install the exact six RPMs with normal DNF; manifests carry NEVRA/SHA-256. |
| #262 | SQLAlchemy spec covers Fedora lowercase `.dist-info`; focused Fedora 46/Python 3.15 build and `%check` pass in `22f2fba`. |
| #263 | R66 Fedora installs the six RPMs through normal DNF5 resolution without vendor override or downgrade. |
| #264 | R66 AlmaLinux/CentOS and R68 AlmaLinux database-outage probes return 503/`Retry-After` without 401/429 lockout; workers recover. |
| #265 | `c5365da` updates every Makefile/spec source reference; `validate-release-refs.py` and CI 39916175033 pass. |
| #266 | R67 fresh Fedora hub plus two workers complete secure bootstrap, resolver checks, registration and workload HTTP/SQL checks. |
| #268 | R70 Rocky Multi-Node retains `storage=1G` on both workers; root-owned mode-0600 `tier.json` is present. |

## Keep `fix-confirmed` (22)

The fix is merged, but the issue's own acceptance requires a specific probe
that has not run yet. These are not `needs-work`: no code or test gap was
found.

| Issue | Outstanding gate |
|---|---|
| #181 | Revalidate UI hiding plus API rejection for a real customer in Multi-Node. |
| #190 | Repeat the packaged `admiral-harbor-worker` sync with a cancelled subscription. |
| #191 | Record a clean `rpm -V admiral-harbor` after install and a second Ansible reconciliation on all three EL10 distributions. |
| #202 | Run the post-fix volume-backup runtime probe and assert `0600` plus matching checksum. |
| #205 | Record clean `rpm -V admiral-common` after install and reconciliation. |
| #213 | Execute the documented `dev→single` certificate reconvergence and verify trust/SAN. |
| #216 | Boot a guest whose persistent SELinux config is permissive and confirm enforcing after reboot. |
| #228 | Inject Podman cleanup failures on Single-Node (the R66 injections covered Multi-Node only). |
| #229 | Run the Multi-Node terminal-task/queue-recovery scenario (Single-Node coverage exists). |
| #236 | Validate the R72 declared-health fix on an exact rebuilt RPM candidate. |
| #237 | Complete the remaining stale/no-report and OS/topology cells. |
| #240 | Run the capacity-rejection regression against an exact rebuilt RPM. |
| #242 | Record RPM `%check` plus clean migration/startup for the deprecation fix. |
| #246 | Repeat resize/reactivation secret preservation in Multi-Node. |
| #250 | Confirm the WireGuard overlay and handshakes after the underlay/overlay correction. |
| #255 | Run the task-race fix on a live VM candidate. |
| #256 | Repeat the post-reboot availability probe on a Multi-Node worker. |
| #259 | Repeat the user-manager restart probe on the remaining target OSes. |
| #260 | Repeat the declared-service outage probe on Fedora and Multi-Node. |
| #267 | Repeat active-node removal refusal on the remaining OSes (Alma R68 and Rocky R70 pass). |
| #271 | Validate redirect rejection on the exact rebuilt RPM candidate. |
| #272 | Revalidate on Fedora and run helper-failure rollback/retry on Rocky. Rocky, AlmaLinux and CentOS Stream passed scoped removed-peer persistence over hub reboot and private-UI denial checks on the exact R73 RPMs; AlmaLinux and CentOS Stream also passed helper-failure rollback/retry. Issue remains open for broader cross-OS coverage. |

## Follow-up

`FINDINGS.md` and `TEST_MATRIX.md` still describe several of these issues as
`fix-proposed`. The 26 eligible issues are now `fixed` and closed on GitHub;
those status lines should be updated in the next audit-documentation change so
the audit record and GitHub do not diverge.
