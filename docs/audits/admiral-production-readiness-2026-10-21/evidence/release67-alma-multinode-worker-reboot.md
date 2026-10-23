# RC5 Release 67 — AlmaLinux 10 Multi-Node worker reboot evidence

**Result: the named W2 reboot/recovery scenario passed on the exact R67
candidate. AlmaLinux Multi-Node is not a completed matrix cell; the matrix
remains 0/8.**

## Candidate and environment

- Test ID: `R67-ALMA-MN-WORKER-REBOOT-01`.
- Candidate: six Admiral RPMs `0.0.1rc5-67.el10`, built from root source
  commit `833d15aa4f8e96be30d28dad169b9d06a4d9894d`. The root commit, selected
  component SHAs, package manifests and native build evidence are recorded in
  [`release67-candidate.md`](release67-candidate.md).
- Runtime: AlmaLinux 10.2 x86_64, three isolated libvirt guests, each 2 vCPU
  and 2 GiB RAM. Hub `adm-r67-alma-mn-hub` (`192.168.122.187`), W1
  `adm-r67-alma-mn-w1` (`192.168.122.188`) and W2
  `adm-r67-alma-mn-w2` (`192.168.122.189`, WireGuard `10.99.0.3`).
- Before the test, the hub had all six exact `.el10` R67 packages. W2 had the
  two role-required packages, `admiral-common` and `admiral-fleet`, at exact
  R67 `.el10` NEVRAs. No package was installed or changed during this test.
- SSH used pinned per-guest host keys with strict host-key checking. No
  production system was involved.

## Procedure and observations

The reproducer applied the `e2e-whoami` definition and provisioned
`inst_b0c15c8b966cfb11` explicitly on W2 (operation
`op_0e9253f68c127f2f`, task `task_243ee8120831ba4c`). Before reboot, the
application returned HTTP 200 and a unique SQL marker was written and read
back from its PostgreSQL database. At `2026-10-23T21:25:31Z`, the test issued
`virsh reboot` to W2. The boot ID changed from
`6c768a3a-bbf6-4bc7-bd7c-f22e4d1bdc88` to
`e7abdc1e-c25d-44cc-9ec6-08d3906a3e1e`.

| UTC sample | Node | Instance | Worker runtime | HTTP |
| --- | --- | --- | --- | --- |
| 21:26:10 | active/healthy/available | running/healthy/unavailable | One container; PostgreSQL and marker not ready | 200 |
| 21:26:16 | active/healthy/available | stopped/stopped/unavailable | Three containers; PostgreSQL ready and marker present | 200 |
| 21:26:21 | active/healthy/available | running/healthy/available | Three containers; PostgreSQL ready and marker present | 200 |
| 21:26:26 | active/healthy/available | running/healthy/available | Second consecutive healthy sample; marker present | 200 |

The control plane reported unavailable/stopped while the workload was still
recovering. The SQL marker remained intact, HTTP returned 200 in all sampled
polls, and the instance converged to `running/healthy/available` about 50
seconds after the reboot request. The post-recovery SQL query returned the
same marker. Deprovision operation `op_1b3942b3688ae0f8` succeeded. Final W2
inventory contained no matching containers, pods, volumes or files. The
three-node postcheck then confirmed exact R67 package roles, active required
services, no failed systemd units, SELinux Enforcing, fresh WireGuard
handshakes, empty worker Podman inventories, and all three nodes
active/healthy/available.

**Expected:** W2's boot ID changes; the control plane does not claim
availability before health convergence; the workload and persistent database
data recover; the API and app endpoint become healthy; deprovision removes all
test resources.

**Observed:** all expected results were observed. This is a scoped resilience
PASS for the named scenario, not proof of recovery during an in-flight task,
callback crash window, repeated reboots, node partition, or full Multi-Node
readiness.

## Excluded helper preflight attempt

Attempt `alma-mn-worker-reboot-01` stopped before applying the app, provisioning
anything, or rebooting a guest. Its preflight incorrectly required all six
packages on a worker. The captured package list showed that the worker role
correctly contains `admiral-common` and `admiral-fleet`; the other four
components belong on the hub. The helper now checks all six packages on the
hub and the two role-required packages on the worker. This was a test-helper
precondition error, not an Admiral failure; the attempt is retained and is not
counted as a runtime result.

## Reproduction and evidence integrity

From the repository root, with the isolated guests available and the
validation SSH key plus pinned known-host files:

```bash
docs/audits/admiral-production-readiness-2026-10-21/scripts/r67/r67-alma-multinode-worker-reboot.sh \
  "$SSH_KEY" "$HUB_KNOWN" "$W2_KNOWN" \
  192.168.122.187 192.168.122.189 \
  adm-r67-alma-mn-w2 adm-r67-alma-mn-w2 \
  "$OUT/alma-mn-worker-reboot-02"
```

The helper and generic three-node postcheck are committed with this report.
The raw successful captures and the excluded preflight capture are local,
ignored, mode `0600` under
`packaging/build/validation/rc5-r67/alma-mn-worker-reboot-{02,01}/`; both
manifests verified with `sha256sum -c`. Hashes:

| Evidence | SHA-256 |
| --- | --- |
| Successful raw evidence manifest | `a7991f62dbdc73dfc3a9534ba2e86d4b9c3820764deda0d5f063fcf6effcbf66` |
| Excluded preflight attempt manifest | `f20f3499afc5bbfa93ba4a5fa48cff79a16e19fc037d2a3d0632a4a4e041b7b0` |
| Reproducer script | `46cf0fa4a3ec765b526fe847fc6b959c329453ffbcf348713884a0b05abba084` |

All AlmaLinux R67 guests were shut down after the postcheck. No source or RPM
changed during the scenario, so prior R67 evidence remains tied to the same
candidate.
