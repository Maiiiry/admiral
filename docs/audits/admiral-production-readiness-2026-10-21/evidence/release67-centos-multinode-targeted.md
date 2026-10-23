# RC5 Release 67 — CentOS Stream 10 Multi-Node targeted evidence

**Result: named scenarios passed; CentOS Stream Multi-Node is not a completed
matrix cell.** This report records runtime evidence for one fresh three-guest
lab. The release matrix remains 0/8.

## Candidate and environment

- Candidate: six Admiral RPMs `0.0.1rc5-67.el10`, source commit
  `833d15aa4f8e96be30d28dad169b9d06a4d9894d`.
- OS: CentOS Stream 10 x86_64. Fresh overlays used the updated seed
  `CentOS-Stream-10-seed-20261023-r66.x86_64.qcow2`, SHA-256
  `2cbea69dd6f99334decc0c89441f54d7d78f1e6370e2ecd7771e9cc51096bf68`.
- Topology: hub `adm-r67-centos-mn-hub` (`10.77.0.40`, WireGuard
  `10.99.0.1`), W1 `adm-r67-centos-mn-w1` (`10.77.0.41`, `10.99.0.2`),
  W2 `adm-r67-centos-mn-w2` (`10.77.0.42`, `10.99.0.3`). Three disposable
  libvirt guests, 2 vCPU/2 GiB each.
- Repositories: local EL10 candidate repository plus EPEL, CRB and Admiral
  COPR. The hub removed the seed's Flask/Mistune packages and re-resolved them
  with the exact candidate through ordinary DNF dependency resolution. No
  Fedora-tagged package, `--nodeps`, `rpm --force`, or equivalent dependency
  bypass was used.
- Seed mode skipped the full OS/security update transaction because the
  verified seed was already updated. This proves the candidate against that
  seeded image; it does not prove clean-image dependency closure.

The distribution boundary is deliberate: Fedora's candidate is built with
the Fedora toolchain, tagged `.fc46`, and installed from the Fedora-only repo;
EL10's candidate is built with EL10 tooling, tagged `.el10`, and installed
from the separate EL10 repo. **EL10 binaries must never be forced onto Fedora.**
See [`docs/rpm_packaging.md`](../../../rpm_packaging.md) and
[`release67-candidate.md`](release67-candidate.md).

## Installation and topology checks

| Test ID | Procedure and observed result | Status |
| --- | --- | --- |
| `R67-CENTOS-MN-BOOT-HUB` | Secure admin/portal bootstrap; installer exit 0, Ansible `ok=238 changed=105 unreachable=0 failed=0 skipped=142`; completed in 407 s. DNF resolved all six exact Admiral `.el10` RPMs and the Python support RPMs from the isolated EL10 repo. | PASS, scoped |
| `R67-CENTOS-MN-BOOT-W1` | Secure worker bootstrap; `ok=154 changed=54 unreachable=0 failed=0 skipped=223`; completed in 354 s. Two heartbeat/metrics retries then convergence; temporary bootstrap key was rejected and pinned validator access remained available. | PASS, scoped, transient retries retained |
| `R67-CENTOS-MN-BOOT-W2` | Secure worker bootstrap; `ok=154 changed=54 unreachable=0 failed=0 skipped=223`; completed in 366 s. Two heartbeat/metrics retries then convergence; temporary bootstrap key was rejected and pinned validator access remained available. | PASS, scoped, transient retries retained |
| `R67-CENTOS-MN-POSTCHECK-INITIAL` | Exact EL10 candidate NEVRAs, expected Python helper package versions, SELinux Enforcing, firewalld, active hub/worker services, zero failed units, no Fedora-tagged RPMs, 2/1/1 WireGuard handshakes, empty rootless Podman inventories, and all three nodes active/healthy/available. | PASS, scoped |
| `R67-CENTOS-MN-POSTCHECK-FINAL` | Repeated the same checks after fault tests and cleanup. | PASS, scoped |

The seven Python helper NEVRAs observed on the hub were `python3-alembic-1.20.1-4.el10`,
`python3-flask-alembic-3.3.0-4.el10`, `python3-flask-login-0.6.3-9.el10`,
`python3-flask-sqlalchemy-3.1.1-10.el10`, `python3-flask-3.1.3-3.el10`,
`python3-mistune-3.4.0-1.el10`, and `python3-typing-extensions-4.16.0-1.el10`.

## Runtime scenarios

| Test ID | Procedure and evidence | Status |
| --- | --- | --- |
| `R67-CENTOS-MN-PLACEMENT-W1/W2` | Explicitly placed `e2e-whoami` on each worker. Same-key replay returned the same operation and instance. W1 briefly reported `running/unhealthy/unavailable` (`runtime_not_healthy`) before converging at poll 2; W2 converged at poll 1. PostgreSQL was ready, a SQL marker round-tripped, hub-to-workload HTTP over WireGuard returned 200, deprovision succeeded, and matching containers/pods/volumes/units/files were absent. Instances: W1 `inst_af8a2fa2289fdadd`, W2 `inst_75e7894aa5cd26a4`. | PASS after health convergence, scoped |
| `R67-CENTOS-MN-DB-OUTAGE` (#264) | Central PostgreSQL stopped for the controlled outage (~66 s). App HTTP remained 200 in sampled polls; journal contained 78 Fleet HTTP 503 records and zero 401/429. PostgreSQL, worker and instance recovered; post-recovery HTTP was 200 and deprovision cleanup succeeded. Instance `inst_46089262e1d0402d` on W1. | PASS, scoped |
| `R67-CENTOS-MN-PARTITION` (#208/#237) | Removed W2's hub WireGuard route. Worker-to-hub request timed out (curl 28 / HTTP 000); the instance became unavailable, then the node reached offline/degraded at poll 13 (~140 s). Restoring the peer returned it to active/healthy/available at poll 2 (~12 s); HTTP returned 200 and cleanup succeeded. Instance `inst_985ed18dc389e468`. | PASS, scoped |
| `R67-CENTOS-MN-HUB-REBOOT` (#211) | Rebooted the hub with W1 workload active. Hub boot ID changed; services, two worker handshakes and fresh routes returned. Recovery was observed at poll 3, about 81 s after reboot request. Workload HTTP stayed 200, SQL marker persisted, deprovision succeeded and inventories were empty. Instance `inst_5280b6b7cbbe122b`. | PASS, scoped |
| `R67-CENTOS-MN-PODMAN-DELETE` (#228) | Injected Podman delete failure during W2 deprovision. First attempt visibly failed with resources present (exit 1); restored the original Podman executable and retried (exit 0). Final instance state was deprovisioned and containers/pods/volumes were empty. Instance `inst_47702dbad3a38df6`. | PASS, scoped |

## Evidence and reproduction

The reproducible scripts are in `scripts/r67/r67-centos-multinode-*.sh` and
`scripts/r67/r67-multinode-postcheck.sh`. Installer and probe commands were run
from `/root/admiral`; raw logs are local, ignored, mode 0600 under
`packaging/build/validation/rc5-r67/` and are not included in Git because they
have not undergone full secret-redaction review. Their SHA-256 values:

The guest IPs and domains above are from the isolated libvirt test network.
For a newly created equivalent lab, set `SSH_KEY`, `HUB_KNOWN`, `W1_KNOWN`,
`W2_KNOWN`, and `OUT` to its pinned SSH identity/known-hosts files and a fresh,
unused evidence directory, then run the corresponding script:

```bash
scripts/r67/r67-centos-multinode-placement.sh "$SSH_KEY" "$HUB_KNOWN" "$W1_KNOWN" "$W2_KNOWN" 192.168.122.190 192.168.122.191 192.168.122.192 rerun-01
scripts/r67/r67-centos-multinode-db-outage.sh "$SSH_KEY" "$HUB_KNOWN" "$W1_KNOWN" 192.168.122.190 192.168.122.191 adm-r67-centos-mn-w1 "$OUT/db-outage"
scripts/r67/r67-centos-multinode-partition.sh "$SSH_KEY" "$HUB_KNOWN" "$W2_KNOWN" 192.168.122.190 192.168.122.192 "$OUT/partition"
scripts/r67/r67-centos-multinode-hub-reboot.sh "$SSH_KEY" "$HUB_KNOWN" "$W1_KNOWN" 192.168.122.190 192.168.122.191 adm-r67-centos-mn-hub adm-r67-centos-mn-w1 adm-r67-centos-mn-w1 "$OUT/hub-reboot"
scripts/r67/r67-centos-multinode-podman-removal-failure.sh "$SSH_KEY" "$HUB_KNOWN" "$W2_KNOWN" "$INSTANCE_ID" "$OUT/podman-failure" 192.168.122.190 192.168.122.192
scripts/r67/r67-multinode-postcheck.sh "$SSH_KEY" "$HUB_KNOWN" "$W1_KNOWN" "$W2_KNOWN" 192.168.122.190 192.168.122.191 192.168.122.192 adm-r67-centos-mn-hub adm-r67-centos-mn-w1 adm-r67-centos-mn-w2 "$OUT/postcheck.log"
```

For Podman failure injection, first apply `examples/apps/e2e-whoami.yaml` and
provision a disposable instance explicitly on W2 with
`admiralctl instances provision --app e2e-whoami --tier small --customer <unique-customer> --idempotency-key <unique-key> --node adm-r67-centos-mn-w2 --wait --wait-timeout 10m --quiet --output json`; pass its returned `instance_id` as `INSTANCE_ID`.

| Capture | SHA-256 |
| --- | --- |
| Hub installer | `35a3ba20b32c47ce098017aca0ae96c2baa2635d05f55346c7b5613b609c2360` |
| W1 installer | `181a534ff6d70b8bbec9ff1ca7a359a2529ef8da4e590bd7bc9917ff075da52d` |
| W2 installer | `5e59a5c5ef3d2ec7a3e412cd9dd0bbc218a5954b500e6aa5966f6c8975ab2113` |
| Final postcheck | `e26435111a94c164b6f4842fbb0fefd8bc128644f0915c860a317e1d0bdca2af` |
| Placement/replay/SQL/HTTP/cleanup | `ac802ead974bf24bbed12643c5e288a91094cd80e5c27692b7b6ea5e3fe04d2a` |
| PostgreSQL outage top-level run log | `abce2d5d4c1b03be5fc6a87ea101b7f2486edd8968c8ffac2d9ad76ec6d21226` |
| Partition/rejoin top-level run log | `3bd755ed1b5fccaaaee7968bfba73eaf10540cc6eff07ce9a94401dfa209182f` |
| Hub reboot top-level run log | `ba384ff14640058df296f0c4c6241b2a1185f6d262dc97f675fc50cbf05fd08f` |
| Podman failure/retry top-level run log | `87baa7f3c27fc5f237f0badfa80dd1cdfd1baff2203f1e7ec8b233647180f492` |
| DB outage restricted evidence manifest | `f44daeaed805668fdd61d132e3236d82e22eee48bfba5fb645c1ff80390d623a` |
| Partition restricted evidence manifest | `9fc7802e85cf97bccaeb4c0355243c16fcce67bf42e4aff88b29313473800f19` |
| Hub reboot restricted evidence manifest | `ba2d92d55996fb89334cf2f0854b33277fdcf2cb530767a9d947257b9f5e75c0` |
| Podman failure restricted evidence manifest | `2130e770ace81a6ada2c373743a02a75ceb190dea9ff8b164a60b32e7a8c0ede` |

No newly actionable product defect was found in these scoped scenarios. They
do not cover the full Multi-Node catalog, task interruption/replay, broad
isolation, external S3, latency, exhaustion or performance. This is not a
completed matrix cell.
