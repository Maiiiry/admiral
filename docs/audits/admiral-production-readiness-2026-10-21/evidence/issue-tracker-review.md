# Review of open issues linked to master tracker #200

Review date: 2026-10-21 UTC<br>
Repository/candidate reviewed: root `748b703662eafdaf3919bad28787d0264f06bf16`, Release 42; component heads and CI evidence are recorded in `source-manifest.txt`.<br>
Authority: current linked-subissue list from GitHub, individual issue acceptance criteria, and the independent consolidated code-review comments posted on 2026-10-21.<br>
Scope: reconcile issue state and close only issue-level work whose acceptance is complete. This review does not declare any OS/topology cell complete or production ready.

## Tracker result

The endpoint returned **50 linked sub-issues**. Five issues were closed in the first pass and five more in the 2026-10-21 17:00 UTC follow-up; **40 remain open**. An earlier interim count of 51 is superseded by the endpoint count.

Closed:

| Issue | Decision and evidence | Boundary |
| --- | --- | --- |
| #193 | Effective external URL is used in return approval/validation and uploaded-restore URL generation. Regression tests cover DB metadata differing from config (`admiral-harbor/tests/test_routes.py:381-403`, `test_client_routes.py:576-616`); Harbor CI passed on `4e1b88b` (run 39517380653). | Confirmation-email URL residual remains separately tracked in #221. No full Harbor matrix claim. |
| #195 | The product decision is settled: staff-to-customer support must be bidirectional. `StaffReply`, migration, routes/templates and tests implement it. | Decision issue closed; implementation/release acceptance remains in #225. |
| #196 | Worker sync safely skips malformed items without an ID and continues processing valid items. Regression coverage is in `admiral-harbor/tests/test_worker.py:195-235` and `test_client_routes.py:552`; Harbor CI passed on `4e1b88b` (run 39517380653). | No malformed remote payload was injected in the live lab. This closes the code-fix issue, not the broader runtime audit. |
| #198 | Restore signature trust boundary is documented; duplicate check removed; paused-pod detection is more specific. Fleet CI passed on `bcd1102` (run 39483715766). | Documentation/cleanup acceptance only; no production-readiness claim. |
| #199 | Shared billing-date presentation helper handles legacy date/datetime values and is registered for the three affected templates; regression tests exist; Harbor CI passed on `4e1b88b` (run 39517380653). | No claim that all views were exercised in all eight cells. |
| #135 | Release 42 RPM `%check` injects the actual CLI version symbol and verifies the packaged binary reports `0.0.1rc5`; the independent code review confirmed the linker target and an installed artifact reported the expected version. | CLI packaging defect only; no matrix or readiness claim. [Closure comment](https://github.com/admiral-project/admiral/issues/135#issuecomment-6321720914). |
| #141 | Release 42 architecture-aware `%check` validates the packaged ELF with `readelf` and avoids executing a foreign-architecture binary; the independent code review confirmed the cross-build path. | Packaging check only. ARM64 remains Tier 2, non-blocking, and no ARM runtime validation is claimed. [Closure comment](https://github.com/admiral-project/admiral/issues/141#issuecomment-6321721935). |
| #203 | Release 42 checks confirmed the Harbor account can read the TLS key while secrets remain `0600 root:root`; the current CentOS Stream Multi-Node package verification also showed no Harbor RPM drift beyond installer-generated `harbor.env`. | TLS permission defect only; full cell validation remains open. [Closure comment](https://github.com/admiral-project/admiral/issues/203#issuecomment-6321723003). |
| #204 | The corrected RPM metadata uses `0700 root:root` for Rocky-owned shared directories; the Release 42 Rocky installation completed its DNF transaction and package checks. | Rocky DNF conflict only; no full matrix claim. [Closure comment](https://github.com/admiral-project/admiral/issues/204#issuecomment-6321724055). |
| #206 | The concurrency-safe metadata initializer and race regression tests passed Harbor CI; a fresh Release 42 CentOS Stream admin/portal hub startup completed without a `harbor_meta_pkey`/`UniqueViolation` in its restricted install log. | Startup-race defect only; the eight-cell audit remains incomplete. [Closure comment](https://github.com/admiral-project/admiral/issues/206#issuecomment-6321725041). |

The corrected closing comments are attached to each GitHub issue. The root master remains open.

## Remaining linked issues

The open issues fall into three groups. “Fixed in tree” means the independent review found an implementation and tests on the current source; it is not a PASS for a fresh candidate cell.

### Product fixes or unresolved residuals — 18

`#207`, `#208`, `#209`, `#210`, `#211`, `#212`, `#213`, `#214`, `#215`, `#216`, `#217`, `#218`, `#219`, `#220`, `#221`, `#222`, `#224`, `#227`.

These still require code changes, a security/dependency disposition, or an explicit missing residual to be addressed. `#227` now has direct Release 42 reproductions on both CentOS Stream topologies: Single-Node and a Multi-Node worker each reported success/healthy with the declared PostgreSQL unit failed and no database container. The normal Multi-Node placements also showed an earlier healthy-than-ready window. `#211` was additionally reproduced on a CentOS Stream hub restart and required manual peer reconstruction.

### Implemented in source; release or affected-cell validation remains open — 20

`#133`, `#136`, `#137`, `#138`, `#139`, `#140`, `#143`, `#144`, `#150`, `#153`, `#155`, `#167`, `#181`, `#182`, `#190`, `#191`, `#201`, `#202`, `#205`, `#225`.

Independent review found fixes or regression tests in the current source for these items, but their own tracker comments require evidence from the packaged candidate, their exact target topology, a distribution matrix, or package metadata/reconciliation checks. Keep them open until those gates are met. In particular, #201 still needs confirmation that the patched Flask RPM is published and installable from the intended public repositories; #205 still needs clean `rpm -V admiral-common` evidence after install and reconciliation.

### Follow-ups with incomplete acceptance — 2

* **#194:** public methods and test mocks were corrected, but `_headers`/`_request` still have optional `customer_id` defaults and the backup route contract is undocumented. Residual work is in #222; the original acceptance is not yet fully satisfied.
* **#197:** the idempotence/error-message portions have fixes, but custom WireGuard subnet behavior and worker/portal firewall rules still need validation/residual cleanup. The hard-coded hub address is tracked in #224.

## Audit interpretation

No issue was closed solely because a source review said “fixed in tree.” The ten closures are limited to issue-level acceptance with regression/CI evidence, current-candidate observations, or a resolved product decision; each closure comment states its boundary. The 40 remaining issues continue to gate release behavior or audit evidence. Single-Node and Multi-Node remain **NOT READY**, and the eight-cell audit remains incomplete.

## Runtime evidence added after the issue sweep

The linked issue count and closure decisions are unchanged: 50 linked sub-issues, 10 closed, 40 open. The AlmaLinux Multi-Node probes add independent Release 42 runtime evidence to two open findings; neither is ready to close:

* **#211 / `ADM-F-005`:** after a hub power-cycle, AlmaLinux 10.2 x86_64 came up with zero configured/runtime WireGuard peers despite two persisted peer fragments. Both workers were offline while their existing workloads remained locally `Up`. Manual reconstruction restored handshakes and node health. See `evidence/alma-multi-execution.md` and raw-log hashes recorded there.
* **#227 / `ADM-F-006`:** on AlmaLinux 10.2 x86_64 Multi-Node, the `/bin/false` required DB service failed five times and had no container, yet provision returned success and the instance remained `running/healthy` for more than three minutes. Deprovision completed and test resources were removed. See test `ALMA-MN-008` in `evidence/alma-multi-execution.md`.

The findings remain open pending product fixes and regression validation. Current root candidate remains Release 42; the audit decision remains **NOT READY** for both topologies.
