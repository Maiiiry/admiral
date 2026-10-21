# Review of open issues linked to master tracker #200

Review date: 2026-10-21 UTC<br>
Repository/candidate reviewed: root `748b703662eafdaf3919bad28787d0264f06bf16`, Release 42; component heads and CI evidence are recorded in `source-manifest.txt`.<br>
Authority: current linked-subissue list from GitHub, individual issue acceptance criteria, and the independent consolidated code-review comments posted on 2026-10-21.<br>
Scope: reconcile issue state and close only issue-level work whose acceptance is complete. This review does not declare any OS/topology cell complete or production ready.

## Tracker result

The linked-subissue endpoint contained **50 open issues** before this review. Five were closed with per-issue rationale and evidence; **45 remain open**. An earlier interim count of 51 was incorrect and is superseded by this endpoint count.

Closed:

| Issue | Decision and evidence | Boundary |
| --- | --- | --- |
| #193 | Effective external URL is used in return approval/validation and uploaded-restore URL generation. Regression tests cover DB metadata differing from config (`admiral-harbor/tests/test_routes.py:381-403`, `test_client_routes.py:576-616`); Harbor CI passed on `4e1b88b` (run 39517380653). | Confirmation-email URL residual remains separately tracked in #221. No full Harbor matrix claim. |
| #195 | The product decision is settled: staff-to-customer support must be bidirectional. `StaffReply`, migration, routes/templates and tests implement it. | Decision issue closed; implementation/release acceptance remains in #225. |
| #196 | Worker sync safely skips malformed items without an ID and continues processing valid items. Regression coverage is in `admiral-harbor/tests/test_worker.py:195-235` and `test_client_routes.py:552`; Harbor CI passed on `4e1b88b` (run 39517380653). | No malformed remote payload was injected in the live lab. This closes the code-fix issue, not the broader runtime audit. |
| #198 | Restore signature trust boundary is documented; duplicate check removed; paused-pod detection is more specific. Fleet CI passed on `bcd1102` (run 39483715766). | Documentation/cleanup acceptance only; no production-readiness claim. |
| #199 | Shared billing-date presentation helper handles legacy date/datetime values and is registered for the three affected templates; regression tests exist; Harbor CI passed on `4e1b88b` (run 39517380653). | No claim that all views were exercised in all eight cells. |

The corrected closing comments are attached to each GitHub issue. The root master remains open.

## Remaining linked issues

The open issues fall into three groups. “Fixed in tree” means the independent review found an implementation and tests on the current source; it is not a PASS for a fresh candidate cell.

### Product fixes or unresolved residuals — 18

`#207`, `#208`, `#209`, `#210`, `#211`, `#212`, `#213`, `#214`, `#215`, `#216`, `#217`, `#218`, `#219`, `#220`, `#221`, `#222`, `#224`, `#227`.

These still require code changes, a security/dependency disposition, or an explicit missing residual to be addressed. `#227` is now additionally supported by the CentOS Stream Multi-Node timing observation in `centos-multi-execution.md`: both API instances were reported healthy before PostgreSQL readiness. The failed-service injection remains the stronger direct reproduction from Single-Node.

### Implemented in source; release or affected-cell validation remains open — 25

`#133`, `#135`, `#136`, `#137`, `#138`, `#139`, `#140`, `#141`, `#143`, `#144`, `#150`, `#153`, `#155`, `#167`, `#181`, `#182`, `#190`, `#191`, `#201`, `#202`, `#203`, `#204`, `#205`, `#206`, `#225`.

Independent review found fixes or regression tests in the current source for these items, but their own tracker comments require evidence from the packaged candidate, their exact target topology, a distribution matrix, or package metadata/reconciliation checks. Keep them open until those gates are met. In particular, #201 still needs confirmation that the patched Flask RPM is published and installable from the intended public repositories; #205 still needs clean `rpm -V admiral-common` evidence after install and reconciliation; #206 needs the original fresh multi-node first-start path on the corrected candidate.

### Follow-ups with incomplete acceptance — 2

* **#194:** public methods and test mocks were corrected, but `_headers`/`_request` still have optional `customer_id` defaults and the backup route contract is undocumented. Residual work is in #222; the original acceptance is not yet fully satisfied.
* **#197:** the idempotence/error-message portions have fixes, but custom WireGuard subnet behavior and worker/portal firewall rules still need validation/residual cleanup. The hard-coded hub address is tracked in #224.

## Audit interpretation

No open issue was closed solely because a source review said “fixed in tree.” The five closures above are limited to issue-level acceptance with current regression/CI evidence or a resolved product decision; their comments explicitly preserve the scope boundary. The 45 remaining issues continue to gate release behavior or audit evidence. Single-Node and Multi-Node remain **NOT READY**, and the eight-cell audit remains incomplete.
