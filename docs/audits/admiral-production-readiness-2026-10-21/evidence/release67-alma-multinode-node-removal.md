# R67 AlmaLinux Multi-Node controlled node removal

**Audit ID:** `ADM-AUDIT-2026-10-21`
**Test ID:** `R67-ALMA-MN-NODE-REMOVE-01`
**Date:** 2026-10-23 UTC
**Status:** **FAIL — targeted Release 67 regression; no cell PASS**
**Finding:** [#267](https://github.com/admiral-project/admiral/issues/267), linked to [master tracker #200](https://github.com/admiral-project/admiral/issues/200).

## Candidate and lab

- Candidate: Admiral RC5 Release 67, root runtime source commit `833d15aa4f8e96be30d28dad169b9d06a4d9894d`; exact component pins and RPM manifests are in [`release67-candidate.md`](release67-candidate.md).
- Guest packages: hub `admiral-common`, `admirald`, `admiral-fleet`, `admiralctl`, `admiral-flagship`, `admiral-harbor` all `0.0.1rc5-67.el10`; W2 had `admiral-common` and `admiral-fleet`, both `0.0.1rc5-67.el10`.
- Environment: AlmaLinux 10.2 x86_64, three real isolated libvirt guests (hub, W1, W2), 2 vCPU / 2 GiB RAM each. Hub `192.168.122.187`, W1 `.188`, W2 `.189`; W2 WireGuard endpoint was `10.99.0.3`.
- Preflight: all three nodes active/healthy/available; exact EL10 R67 package roles; SELinux Enforcing; required services active; no failed units; fresh WireGuard handshakes; workers had no rootless containers, pods or volumes.

## Procedure

1. Applied the `e2e-whoami` fixture and provisioned one instance explicitly on W2 using a fresh customer and idempotency key.
2. Confirmed the instance was `running/healthy/available` and the service returned HTTP 200 from the hub over WireGuard.
3. Ran `admiralctl nodes remove adm-r67-alma-mn-w2` without `--force`, answered `y`, and retained the CLI output and daemon journal.
4. The helper's assertion stopped after observing the unexpected response. Its exit trap deprovisioned the test instance; the deprovision operation succeeded. A post-failure three-node check confirmed the node remained registered and healthy and both workers had empty container/pod/volume inventories.

The reproduction helper is [`r67-alma-multinode-node-removal.sh`](../scripts/r67/r67-alma-multinode-node-removal.sh). It requires the isolated validation SSH key/known-host files, the three guest IPs, the disposable W2 ID, and an absolute output directory. Example invocation shape:

```bash
bash docs/audits/admiral-production-readiness-2026-10-21/scripts/r67/r67-alma-multinode-node-removal.sh \
  <SSH_KEY> <HUB_KNOWN_HOSTS> <W2_KNOWN_HOSTS> \
  192.168.122.187 192.168.122.189 adm-r67-alma-mn-w2 \
  "$PWD/packaging/build/validation/rc5-r67/alma-mn-node-removal-02/run"
```

The first direct launch returned exit 126 (`Permission denied`) before the helper started or made SSH connections. That attempt is retained; the actual test was then run with `bash`. The tracked helper now has executable permissions.

## Expected and observed

**Expected:** HTTP 409 with a clear active-instance conflict; one request only; node and assigned workload remain registered until the operator deprovisions or explicitly forces removal.

**Observed:** the client reported `request failed after 3 retries: server error: HTTP 500`. The daemon journal records four failed removal attempts between 21:49:27Z and 21:49:35Z. Each carries the underlying database error `node has 1 active instance(s); use --force to override`. The node-removal call did not delete the node: the test instance's exit-trap deprovision completed successfully against W2, and the subsequent postcheck found all three nodes healthy. The procedure did not re-query the workload HTTP endpoint or SQL data after the rejected request and makes no claim about those checks.

## Cause and impact

The cause is confirmed in the R67 source. `database.DB.RemoveNode` returns an error containing `has 1 active instance(s)`, while `HandleNodeByID` classified it as HTTP 409 only if the text contained `has active instance`. The count between those words prevented the match, so the handler logged the expected refusal as an internal server error and returned HTTP 500. `admiralctl` retried the 5xx request, producing repeated server errors. The CLI's force-removal hint used the same overly specific phrase and was not printed.

Severity is **MEDIUM**: this path refused the destructive operation and preserved the node registration; the observed defect is incorrect error classification, retries, noisy logs and loss of actionable operator guidance. Release 67 is invalidated for active release-gate credit because the candidate requires a source fix. Its prior scoped results remain historical candidate-specific evidence and do not validate the rebuilt candidate. Matrix completion remains **0/8**.

## Evidence and integrity

Restricted raw output is retained locally, ignored by Git, under `packaging/build/validation/rc5-r67/alma-mn-node-removal-02/` with mode 0600. The local manifest verifies with `sha256sum -c` and has SHA-256 `6a14fc250713049856b58d409898cb6bd26fcb96a0dda19ff0180b34cf2f8de1`. It covers the launch attempt, exact RPM inventories, initial and final topology postchecks, provision/instance data, four-attempt CLI output, daemon journal, and successful cleanup result. It contains no credentials.

## Fix and regression

The fix uses an explicit database sentinel for active-instance removal, maps that condition to HTTP 409, and makes the CLI recognize the counted active-instance message. Component tests cover typed status mapping, a one-attempt 409 response and force-removal guidance. Source commits are `admirald@a4d39ae6b5db92bd7e6e5257dc8f6b919af52668` and `admiralctl@fa2a65e866310bd82bea78859804b6c3aea7989a`; upstream CI and a rebuilt-candidate runtime regression must pass before #267 can be considered resolved. The new exact candidate must repeat the three-guest active-removal protection test, then deprovision and remove the idle worker, verify node inventory, and confirm all workers are clean.
