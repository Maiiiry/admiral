# RC5 Release 67 — Fedora Rawhide Multi-Node targeted recovery evidence

**Result: named recovery scenarios passed; Fedora Multi-Node is not a
completed matrix cell.** This report extends the exact-candidate bootstrap and
placement evidence in [`release67-fedora-multinode-bootstrap.md`](release67-fedora-multinode-bootstrap.md)
and [`release67-fedora-multinode-placement-recheck.md`](release67-fedora-multinode-placement-recheck.md).
The full release matrix remains 0/8.

## Candidate and environment

- Candidate: six Admiral RPMs `0.0.1rc5-67.fc46`, source commit
  `833d15aa4f8e96be30d28dad169b9d06a4d9894d`.
- OS: Fedora Rawhide 46 x86_64. Fresh guests are overlays from
  `Fedora-Rawhide-seed-20261023-r66.x86_64.qcow2`, SHA-256
  `5e79471888e5e0bbc24a1d410b8cebc054d0c459b61f970cd89018eb04cb5b7c`.
- Topology: hub `adm-r67-fedora-mn-hub` (`10.77.0.10`, WireGuard `10.99.0.1`),
  W1 `adm-r67-fedora-mn-w1` (`10.77.0.11`, `10.99.0.2`), W2
  `adm-r67-fedora-mn-w2` (`10.77.0.12`, `10.99.0.3`). Each guest is 2 vCPU
  and 2 GiB RAM.
- The Fedora-only local repo supplied the exact `.fc46` candidate and helper
  RPMs via normal DNF resolution. No `.el10` RPM was copied or installed on
  Fedora; no `--force`, `--nodeps` or dependency bypass was used.
- Seed mode skipped the full OS/security update transaction because the
  verified seed was already updated. This does not prove clean-image dependency
  closure.

The native build boundary is explicit: Fedora binaries must be built by the
Fedora toolchain and installed only from the `.fc46` repository. EL10 binaries
must not be forced or installed into Fedora. See
[`docs/rpm_packaging.md`](../../../rpm_packaging.md) and
[`release67-candidate.md`](release67-candidate.md).

## Baseline and final postchecks

The Fedora-specific postcheck verified the exact six `.fc46` NEVRAs on the hub,
the expected `admiral-common` and `admiral-fleet` `.fc46` NEVRAs on both
workers, Fedora helper RPMs, SELinux Enforcing, firewalld running, all required
services active, no failed units, zero `.el10` RPMs, 2/1/1 fresh WireGuard
handshakes, empty rootless Podman inventories, and three nodes
`active/healthy/available`. The same postcheck passed after all injections and
cleanup.

| Test ID | Scenario and result | Status |
| --- | --- | --- |
| `R67-FEDORA-MN-POSTCHECK-INITIAL` | Exact candidate/package boundary, host security, services, peers, node inventory and empty worker resources. | PASS, scoped |
| `R67-FEDORA-MN-DB-OUTAGE` (#264) | Stop central PostgreSQL for the controlled outage (~66 s). All 13 app polls returned HTTP 200; journal recorded 81 Fleet HTTP 503s and zero 401/429. PostgreSQL recovered, the instance recovered, a SQL marker persisted, post-recovery HTTP was 200, and deprovision cleanup succeeded. Instance `inst_705bc153e2e21323`, placed on W1. | PASS, scoped |
| `R67-FEDORA-MN-PARTITION` (#208/#237) | Remove W2's hub WireGuard route. Worker-to-hub request timed out (curl exit 28 / HTTP 000); instance became unavailable and W2 became offline/degraded at poll 13, 141 s after partition. Restoring the peer returned W2 and its instance to active/healthy/available at poll 2, 12 s after restore. SQL marker and HTTP 200 persisted; cleanup succeeded. Instance `inst_3daf576100272682`. | PASS, scoped |
| `R67-FEDORA-MN-HUB-REBOOT` (#211) | Reboot the hub with W1 workload active. Boot ID changed; all hub services returned; two routes/handshakes and both workers recovered. Workload returned HTTP 200, SQL marker persisted, recovery was observed at poll 2 (~58 s after reboot request), and deprovision left empty inventories. Instance `inst_bbf9ddc0542e8361`. | PASS, scoped |
| `R67-FEDORA-MN-PODMAN-DELETE` (#228) | Inject Podman delete failure during W2 deprovision. First attempt failed visibly with resources present (exit 1); original Podman was restored and retry succeeded (exit 0). Final instance state was deprovisioned; containers, pods, volumes and files were empty. Instance `inst_ef2785932bbd46f5`. | PASS, scoped |
| `R67-FEDORA-MN-POSTCHECK-FINAL` | Repeated package, service, security, peer, topology and empty-inventory checks after all probes. | PASS, scoped |

These are recovery probes, not a complete Fedora Multi-Node scenario catalog.
They do not exercise an in-flight task/callback during a crash, node removal,
all conflicting concurrent operations, cross-workload isolation attacks,
resource exhaustion, external storage or performance under controlled load.

## Reproduction

The bootstrap and placement procedures remain in the linked Fedora reports.
Recovery scripts added for this run are
`scripts/r67/r67-fedora-multinode-{db-outage,partition,hub-reboot,podman-removal-failure}.sh`;
the package/topology verifier is `scripts/r67/r67-fedora-multinode-postcheck.sh`.
Set `SSH_KEY`, `HUB_KNOWN`, `W1_KNOWN`, `W2_KNOWN`, and a fresh unused `OUT`
directory to the isolated lab's pinned SSH inputs, then run:

```bash
scripts/r67/r67-fedora-multinode-db-outage.sh "$SSH_KEY" "$HUB_KNOWN" "$W1_KNOWN" 10.77.0.10 10.77.0.11 adm-r67-fedora-mn-w1 "$OUT/db-outage"
scripts/r67/r67-fedora-multinode-partition.sh "$SSH_KEY" "$HUB_KNOWN" "$W2_KNOWN" 10.77.0.10 10.77.0.12 "$OUT/partition"
scripts/r67/r67-fedora-multinode-hub-reboot.sh "$SSH_KEY" "$HUB_KNOWN" "$W1_KNOWN" 10.77.0.10 10.77.0.11 adm-r67-fedora-mn-hub adm-r67-fedora-mn-w1 adm-r67-fedora-mn-w1 "$OUT/hub-reboot"
scripts/r67/r67-fedora-multinode-podman-removal-failure.sh "$SSH_KEY" "$HUB_KNOWN" "$W2_KNOWN" "$INSTANCE_ID" "$OUT/podman-failure" 10.77.0.10 10.77.0.12
scripts/r67/r67-fedora-multinode-postcheck.sh "$SSH_KEY" "$HUB_KNOWN" "$W1_KNOWN" "$W2_KNOWN" 10.77.0.10 10.77.0.11 10.77.0.12 adm-r67-fedora-mn-hub adm-r67-fedora-mn-w1 adm-r67-fedora-mn-w2 "$OUT/postcheck.log"
```

For Podman failure injection, first apply `examples/apps/e2e-whoami.yaml` and
provision a disposable instance explicitly on W2 with
`admiralctl instances provision --app e2e-whoami --tier small --customer <unique-customer> --idempotency-key <unique-key> --node adm-r67-fedora-mn-w2 --wait --wait-timeout 10m --quiet --output json`; pass the returned `instance_id` as `INSTANCE_ID`.

## Evidence integrity

Raw logs and structured captures are ignored local artifacts with mode 0600
under `packaging/build/validation/rc5-r67/`; they are not in Git because they
have not undergone full secret-redaction review. The four structured directories
contain `SHA256SUMS`; each manifest was verified with `sha256sum -c` after the
run. Hashes:

| Capture | SHA-256 |
| --- | --- |
| Final topology postcheck | `174cfccb6081e46964d17ea0251a6fc3e934933e38c4960c1db574ea4f7c0267` |
| PostgreSQL outage top-level log | `d70c2e15b07a56577cd34591e46eb10e870d48747a14bcb980be5be8b1bd0804` |
| Partition/rejoin top-level log | `98f97a0e448689c5d828d1925ff122d62f9541fc43ad9786b9a68016204b37c9` |
| Hub reboot top-level log | `cfe141d300b1be5dee67b775fb7d83dd73df910aaa25b2b402896b2b947f0adf` |
| Podman failure/retry top-level log | `5eeb49bf169ec5525d3731f7017748364b4d15d279db9ef08aa5c534532c0839` |
| DB outage evidence manifest | `023421d1d614ae4907b4e30f860e6bfd2fbc7ef47ec82f7152b89f441f6fb5cf` |
| Partition evidence manifest | `cf5e4efbfcd02f48003fe1dd47866aa31be033a764c4f4a2a90cb3376bc1193d` |
| Hub reboot evidence manifest | `676881c231e3ec8dfa59be8583bd27f353566d3e64fe6c5784f23173dbfad3bd` |
| Podman failure evidence manifest | `9cc9e0610daf8e9770220d1ea4ad5015914d91c20760106a5866ca32d048c045` |

No new actionable product defect was found in these scoped probes. Fedora's
Multi-Node cell remains incomplete; no matrix PASS is claimed.
