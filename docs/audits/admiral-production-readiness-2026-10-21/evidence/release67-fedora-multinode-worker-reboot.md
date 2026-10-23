# RC5 Release 67 — Fedora Rawhide Multi-Node worker reboot evidence

**Result: the named W2 reboot/recovery scenario passed on the exact R67
candidate. Fedora Rawhide Multi-Node is not a completed matrix cell; the
matrix remains 0/8.**

## Candidate and environment

- Test ID: `R67-FEDORA-MN-WORKER-REBOOT-01`.
- Candidate: six Admiral RPMs `0.0.1rc5-67.fc46`, built from root source
  commit `833d15aa4f8e96be30d28dad169b9d06a4d9894d` using the Fedora-native
  builder. The exact source pins, native toolchain and package manifests are
  recorded in [`release67-candidate.md`](release67-candidate.md).
- Runtime: Fedora Linux 46 (Rawhide seed) x86_64, three isolated libvirt
  guests, each 2 vCPU and 2 GiB RAM. Hub `adm-r67-fedora-mn-hub`
  (`192.168.122.176`), W1 `adm-r67-fedora-mn-w1` (`192.168.122.177`) and W2
  `adm-r67-fedora-mn-w2` (`192.168.122.178`, WireGuard `10.99.0.3`).
- Before the test, RPM queries confirmed all six `.fc46` packages on the hub
  and the role-required `admiral-common` and `admiral-fleet` `.fc46` packages
  on W2. The Fedora-specific three-node postcheck independently verified the
  same package roles and zero `.el10` packages. No EL10 binary was installed
  on Fedora; no package was installed or changed during the test.
- SSH used pinned per-guest host keys with strict host-key checking.

## Procedure and observations

The reproducer applied `e2e-whoami` and provisioned
`inst_bbf4104134ef24b9` explicitly on W2 (operation
`op_9d3fa6bd4451b9c5`, task `task_d77c9be335dc2b28`). Before reboot, HTTP
returned 200 and a unique SQL marker was written to and read from the
workload's PostgreSQL database. At `2026-10-23T21:37:33Z`, the test issued
`virsh reboot` to W2. Its boot ID changed from
`f88cb4dc-6be5-4a0b-9602-29670197f3b4` to
`40954d27-669d-4a0a-b2ce-cd369b86332c`.

| UTC sample | Node | Instance | Worker runtime | HTTP |
| --- | --- | --- | --- | --- |
| 21:38:14 | active/healthy/available | stopped/stopped/unavailable | Three containers; PostgreSQL ready and marker present | 200 |
| 21:38:20 | active/healthy/available | running/healthy/available | Three containers; PostgreSQL ready and marker present | 200 |
| 21:38:26 | active/healthy/available | Second consecutive healthy/available sample | Three containers; PostgreSQL ready and marker present | 200 |

The control plane did not report availability while the instance was stopped.
The first healthy/available sample arrived about 47 seconds after the reboot
request; two consecutive healthy samples were recorded by about 53 seconds.
The SQL marker was readable after recovery. Deprovision operation
`op_7270dc1b0258ed70` succeeded, and the worker's final inventory contained no
matching containers, pods, volumes or files. The Fedora-specific three-node
postcheck confirmed all nodes active/healthy/available, exact `.fc46` package
roles, zero `.el10` packages, active services, no failed units, SELinux
Enforcing, fresh WireGuard handshakes and empty worker inventories.

**Expected:** W2's boot ID changes; Admiral reports stopped/unavailable while
recovery is incomplete; the workload and SQL data recover; HTTP returns 200;
cleanup removes the test resources.

**Observed:** all expected results were observed. This scoped scenario does
not validate task interruption/callback replay, repeated failures, or the
complete Fedora Multi-Node catalog.

## Retained helper metadata-label error

The helper source used during this run contained a copied hardcoded
`candidate=0.0.1rc5-67.el10` string in `metadata.txt`. That field was not used
for package selection. The raw `candidate-hub.txt` and `candidate-worker.txt`
captures show `.fc46` NEVRAs, and the Fedora-specific postcheck independently
confirmed the exact `.fc46` set and zero `.el10` packages. The raw mismatch is
preserved in the evidence manifest and described in `candidate-review.txt`;
it is not rewritten or hidden. The committed helper derives the metadata field
from the verified expected release. The helper hash at execution was
`96b3216c661234769a37b63a9d9d82a323647878c482ed7b855c9922e15ab55c`; the
corrected reproducer hash is
`e439b0449a74a9cd567fb50951dca2846b739494901a8dbb39e3f672ca09df74`. The
correction affects only the printed metadata label; the reboot, polling,
runtime checks and cleanup are unchanged.

## Reproduction and evidence integrity

From the repository root, with the guests available, the validation SSH key
and pinned per-guest known-host files:

```bash
docs/audits/admiral-production-readiness-2026-10-21/scripts/r67/r67-fedora-multinode-worker-reboot.sh \
  "$SSH_KEY" "$HUB_KNOWN" "$W2_KNOWN" \
  192.168.122.176 192.168.122.178 \
  adm-r67-fedora-mn-w2 adm-r67-fedora-mn-w2 \
  "$OUT/fedora-mn-worker-reboot-01"
```

Raw captures are local, ignored and mode `0600` under
`packaging/build/validation/rc5-r67/fedora-mn-worker-reboot-01/`; the SHA-256
manifest verified with `sha256sum -c`.

| Evidence | SHA-256 |
| --- | --- |
| Raw evidence manifest | `ee833382d9518842a4b045394cccf0e574b5da531a465ac6c1b5ebd8230f3990` |
| Corrected reproducer script | `e439b0449a74a9cd567fb50951dca2846b739494901a8dbb39e3f672ca09df74` |

All Fedora R67 guests were shut down after the postcheck. The candidate and
RPMs remained unchanged throughout this scenario.
