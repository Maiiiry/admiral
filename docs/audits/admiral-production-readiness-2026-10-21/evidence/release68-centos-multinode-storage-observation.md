# RC5 Release 68 — CentOS Stream storage-limit observation

Audit: `ADM-AUDIT-2026-10-21`
Finding: [#268](https://github.com/admiral-project/admiral/issues/268), open with `bug` and `fix-proposed`
Severity: LOW (temporary inaccurate state/observability; no data loss or quota bypass observed)
Candidate: RC5 Release 68 (`0.0.1rc5-68.el10`), root/package source `4077c4ddb9d233682961d36c3570c63e70eb6405`.

## First observation

During `R68-CENTOS-MN-PLACEMENT-01`, W2 provisioned `e2e-whoami` with tier snapshot `storage: 1G`. Instance `inst_2ee7ed334c1e2804` / provision operation `op_4d5840d2047b928c` reported:

- `storage_limit_bytes=0`
- `storage_state=unknown`
- `storage_message="no storage limit configured"`
- `storage_checked_at=2026-10-24T01:46:25.536611Z`, about three seconds after instance creation

The operation became terminal at `01:47:04.138776Z`; the instance was deprovisioned at `01:47:13.348471Z`. No corrected storage report was observed before deprovision. This is one observed transient mismatch; the first run did not capture `tier.json` at the exact time of the report.

Protected raw evidence: ignored `packaging/build/validation/rc5-r68/centos-mn-placement/run-20261024T014515Z/`, manifest SHA-256 `2a50df5fd4fc68b904d4ab9b3df92776619c044e3b394ae00931d79e5dcb3c53`.

## Same-candidate repeat

`R68-CENTOS-MN-STORAGE-01` provisioned another `e2e-whoami` `small` workload on the same W2 and unchanged Release 68 candidate. Operation `op_e027755ec55f8bbe` / instance `inst_1bd83ffc93e5c51c` completed at `01:51:25.977736Z`. Eighteen API samples over 90 seconds reported `storage_limit_bytes=1073741824` and `storage_state=ok`. `tier.json` was mode 0600, root-owned and contained `storage: 1G`; the Fleet process had no explicit storage-check interval override, so the default 60-second interval applied. The workload remained healthy/available through the observation and was deprovisioned by the helper.

Protected raw evidence: ignored `packaging/build/validation/rc5-r68/centos-mn-storage/run-20261024T015116Z/`, manifest SHA-256 `4dffd27201fd6d33ccbc858d24096d89ec9fc41ee5cbba40859d3336e2ff4a78`. The same-candidate repeat did **not** reproduce the mismatch; its short provision completed before the relevant storage scan.

## Root cause and source fix

**Root-cause hypothesis:** `admiral-fleet` scans generated Quadlet pod files periodically and reads `tier.json`; provision previously rendered the Quadlet before writing the metadata and ignored metadata-directory/write errors. A scan in that interval could report zero/unknown even though the control-plane tier snapshot declared a storage limit. The observed timing is consistent with this ordering, but the first run did not preserve the file state at the exact scan.

The source correction is pushed in [`admiral-fleet@029bb53`](https://github.com/admiral-project/admiral-fleet/commit/029bb53da6c2bef7d567213a5fd6ab106d56d68c): persist tier metadata before rendering workload units and return an explicit provisioning error if metadata cannot be written. A regression injects a tier-file write failure and asserts no Quadlet is rendered and no systemd unit is started. Local `go test -count=1 ./...` and `go vet ./...` passed. Component CI [40052142923](https://github.com/admiral-project/admiral-fleet/actions/runs/40052142923) was in progress when this report was prepared; it must be checked before a root Release 69 build.

The source fix changes the component artifact. Release 68 is therefore **invalidated for matrix credit**; a coordinated six-RPM Release 69 must be built natively for Fedora and EL10, then runtime validation must restart on fresh guests. Neither R68 run counts toward Release 69. No cell is PASS; matrix remains **0/8**.

## Regression criteria

- [ ] With a workload tier that declares 1 GiB storage, every posted storage observation reflects the declared limit or explicitly indicates measurement pending; it must not claim that no limit is configured.
- [ ] Inject tier metadata directory creation and file-write failures; provision must fail visibly before any Quadlet is rendered or service started.
- [ ] Run the exact-candidate regression on fresh CentOS Stream 10 and AlmaLinux 10 Multi-Node guests, then cover the affected Single-Node cells.
- [ ] Verify API state, worker `tier.json`, configured check interval, persistent workload data and cleanup; retain exact candidate identity and hashes.
