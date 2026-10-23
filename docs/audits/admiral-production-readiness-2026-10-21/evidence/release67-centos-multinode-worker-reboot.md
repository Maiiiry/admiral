# RC5 Release 67 — CentOS Stream Multi-Node worker reboot evidence

**Result: the named W2 reboot/recovery scenario passed on the exact R67
candidate. CentOS Stream Multi-Node is not a completed matrix cell.** The
release matrix remains 0/8.

## Candidate and environment

- Candidate: Admiral `0.0.1rc5-67.el10`, root source commit
  `833d15aa4f8e96be30d28dad169b9d06a4d9894d`.
- OS: CentOS Stream 10 x86_64. The three fresh overlays came from the updated
  seed `CentOS-Stream-10-seed-20261023-r66.x86_64.qcow2`, SHA-256
  `2cbea69dd6f99334decc0c89441f54d7d78f1e6370e2ecd7771e9cc51096bf68`.
- Topology: hub `adm-r67-centos-mn-hub` (`192.168.122.190`), W1
  `adm-r67-centos-mn-w1` (`192.168.122.191`), W2
  `adm-r67-centos-mn-w2` (`192.168.122.192`, WireGuard `10.99.0.3`). Each
  guest had 2 vCPU and 2 GiB RAM. Pinned per-guest known-host files were used
  with strict host-key checking.
- The test procedure installed no packages and made no RPM/source changes. It
  used the exact previously installed R67 `.el10` packages. The postcheck and
  exact package identity for this three-guest R67 lab are recorded in
  [`release67-centos-multinode-targeted.md`](release67-centos-multinode-targeted.md).

## Test `R67-CENTOS-MN-WORKER-REBOOT-01`

The helper provisioned `e2e-whoami` on W2 (`inst_d5aee9a2e21cab16`, provision
operation `op_49bf0810b891b0ba`), confirmed PostgreSQL readiness, inserted and
read back the SQL marker
`r67-centos-worker-reboot-inst_d5aee9a2e21cab16`, and confirmed HTTP 200 before
reboot. At `2026-10-23T20:51:54Z`, `virsh reboot` was issued against W2. The
boot ID changed from `de05fd14-9aaf-490d-afbd-71b2d4b976d4` to
`6eabf257-f0dc-4893-9faa-1ea782a4cacc`.

| Sample | Observed result |
| --- | --- |
| Poll 1, 20:52:40Z | Node `active/healthy`; instance `stopped/stopped/unavailable`; one runtime container; HTTP 000. The hub did not report the workload as ready while it was still restarting. |
| Poll 2, 20:52:46Z | Node `active/healthy`; instance `running/healthy/available`; three runtime containers; PostgreSQL ready; same SQL marker present; HTTP 200. |
| Poll 3, 20:52:52Z | Second consecutive healthy/available sample with all three containers, PostgreSQL ready, marker present and HTTP 200. |

The reboot caused one expected in-flight HTTP connection reset. Subsequent
health samples and the final request succeeded. Deprovision operation
`op_5305e2fc72930d99` returned `succeeded`; final inventory contained no
matching containers, pods, volumes or files. The helper exited 0. This proves
the observed worker reboot and workload recovery path only; it does not test
active-task crash windows, callback interruption, unrelated-resource safety,
or recovery under repeated failures.

## Excluded helper attempt

Attempt 01 provisioned and then successfully deprovisioned a workload, but
stopped **before issuing a reboot**. An adapted R66 helper retained an old W2
node-ID comparison and therefore expected `10.99.0.2` instead of the actual
W2 endpoint `10.99.0.3`. The final inventory check confirmed there were no
remaining resources. This is an excluded harness failure, not a product
failure or a worker-reboot result. The stale guard was corrected before
attempt 02; no data from attempt 01 is counted as PASS.

## Reproduction and evidence integrity

Run from the repository root with the same isolated guests powered on, the
three pinned known-host files, and the validation SSH key available:

```bash
scripts/r67/r67-centos-multinode-worker-reboot.sh \
  "$SSH_KEY" "$HUB_KNOWN" "$W2_KNOWN" \
  192.168.122.190 192.168.122.192 \
  adm-r67-centos-mn-w2 adm-r67-centos-mn-w2 \
  "$OUT/centos-worker-reboot"
```

Raw captures are mode `0600` under the ignored local directory
`packaging/build/validation/rc5-r67/`; they are not committed because they
have not undergone full secret-redaction review. The successful attempt's
SHA-256 manifest verified with `sha256sum -c`:

| Capture | SHA-256 |
| --- | --- |
| Successful attempt manifest | `5a8d0c5d83e521167b59e3a678115f98cac8628f99a4679f7d261830db48f226` |
| Successful attempt top-level log | `8bb5582ed9b683a340851113cd50dc1804f030e206f5f3a953daff8fc0d1c9d9` |
| Excluded attempt manifest | `845fb248fe6f884050bfaa2b676ee4041e30a413aac410e242c26df6a271441d` |

Both test runs left the candidate source and RPMs unchanged. All R67 guests
were shut down after evidence collection. This is scoped resilience evidence,
not a completed cell or a production-readiness declaration.
