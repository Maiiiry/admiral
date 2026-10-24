# R68 AlmaLinux Multi-Node central PostgreSQL outage

Audit: `ADM-AUDIT-2026-10-21`<br>
Test ID: `R68-ALMA-MN-DB-OUTAGE-01`<br>
Date: 2026-10-24<br>
Result: **PASS, scoped regression for #264; no matrix-cell credit**

## Candidate and environment

- Admiral RC5 Release 68, exact EL10 candidate `0.0.1rc5-68.el10`, package source commit [`4077c4d`](https://github.com/admiral-project/admiral/commit/4077c4ddb9d233682961d36c3570c63e70eb6405). The exact six RPM NEVRAs, SHA-256 values, component SHAs and CI are in [`release68-candidate.md`](release68-candidate.md).
- Three real isolated AlmaLinux 10.2 x86_64 guests: hub `192.168.122.201`, W1 `192.168.122.202`, W2 `192.168.122.203`; each 2 vCPU / 2 GiB. SELinux was Enforcing. The hub had the six exact `.el10` RPMs; both workers had the exact `admiral-common` and `admiral-fleet` `.el10` RPMs. No cross-distro packages or dependency bypasses were used.
- All three system services were active before injection. Both workers were registered and active/healthy/available. The test provisioned `e2e-whoami` explicitly on W1, verified its embedded PostgreSQL and wrote a SQL marker, then confirmed endpoint HTTP 200 before stopping the hub's central PostgreSQL service.

## Procedure and observed result

At `2026-10-24T01:12:50Z`, a transient systemd timer was armed to start the hub's PostgreSQL service after 60 seconds, and the service was stopped. The workload endpoint was sampled 13 times while PostgreSQL moved through `inactive`, `activating`, and `active`; **all 13 responses were HTTP 200**. The service returned active at `01:13:58Z` (68 seconds after the recorded outage start).

During the outage, the hub journal contained **78 HTTP 503** Fleet authentication/database-error records and **zero HTTP 401 or 429** records. Fleet journals independently recorded **46 HTTP 503 on W1** and **32 on W2**, with zero HTTP 401/429 on either worker. The timer's transient service reported `Result=success`, `ExecMainStatus=0`, `ActiveState=inactive`; no restore timer remained pending, and PostgreSQL was active.

After recovery, both workers were active/healthy/available. The workload was `running/healthy/available` on W1, its SQL marker was still present, and the endpoint returned HTTP 200. Deprovision succeeded as operation `op_a9182d5ac49f9f57`; W1 had no matching containers, pods, volumes, Quadlet/systemd units or files. The uploaded test fixture was removed. The run took 94 seconds from start to completed cleanup.

This reproduces the intended #264 behavior on one R68 EL10 Multi-Node topology. It does **not** test all failure windows, direct `Retry-After` response headers, in-flight task side effects, or the other three OS-specific Multi-Node cells. Issue #264 remains open; this is not an entire cell PASS.

## Reproduction and evidence

Run the helper on the isolated three-guest lab after verifying the exact candidate and clean workload state:

```text
docs/audits/admiral-production-readiness-2026-10-21/scripts/r68/r68-alma-multinode-db-outage.sh \
  SSH_KEY HUB_KNOWN_HOSTS W1_KNOWN_HOSTS W2_KNOWN_HOSTS \
  HUB_IP W1_IP W2_IP ABSOLUTE_EMPTY_OUTPUT_DIRECTORY
```

The script performs read-only OS/package/service/node preflight checks before provisioning, refuses an existing evidence directory, automatically restores PostgreSQL on interruption, deprovisions on exit, removes its temporary fixture, and writes a checksum manifest for both successful and failed runs.

The scored raw run is retained locally, ignored by Git, under `packaging/build/validation/rc5-r68/alma-mn-db-outage/run-20261024T011237Z/`; its directory mode is `0700`, files are `0600`, and `sha256sum -c SHA256SUMS` passed. SHA-256 of `SHA256SUMS`: `8eaeaa26143a235e8ed4b8f3e687080cb367508d2717a5669d3d62c15b4de1b9`. Raw captures include exact package inventories, host identities, node state, HTTP samples, PostgreSQL timer status, hub and per-worker journals, SQL marker, operation response, and cleanup inventory.

Two earlier attempts are preserved separately and excluded from the scored result: an initial read-only helper preflight failed because its SSH/RPM query formatting was wrong (`run-20261024T010918Z`; no guest mutation); a pilot outage run completed the workload/recovery checks but preceded the helper's explicit timer-result assertion (`run-20261024T011002Z`). The corrected helper and the scored run above are the reproducible result. These were validation-harness issues, not Admiral findings.
