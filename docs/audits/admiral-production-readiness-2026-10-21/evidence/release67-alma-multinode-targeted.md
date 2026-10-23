# RC5 Release 67 — AlmaLinux 10 Multi-Node targeted evidence

**Result: named scenarios passed; AlmaLinux Multi-Node is not a completed
matrix cell.** This report records runtime evidence for one fresh three-guest
lab. The release matrix remains 0/8.

## Candidate and environment

- Candidate: six Admiral RPMs `0.0.1rc5-67.el10`, source commit
  `833d15aa4f8e96be30d28dad169b9d06a4d9894d`.
- OS: AlmaLinux 10.2 x86_64. Fresh overlays used the updated seed
  `AlmaLinux-10.2-seed-20261023-r66.x86_64.qcow2`, SHA-256
  `bcec85910c4ed224d967eb0f696a08af5b24e60d6c3547252bce9dc0a0f02118`.
- Topology: hub `adm-r67-alma-mn-hub` (`10.77.0.30`, WireGuard
  `10.99.0.1`), W1 `adm-r67-alma-mn-w1` (`10.77.0.31`, `10.99.0.2`),
  W2 `adm-r67-alma-mn-w2` (`10.77.0.32`, `10.99.0.3`). Three disposable
  libvirt guests, 2 vCPU/2 GiB each.
- Repositories: local EL10 candidate repository plus EPEL, CRB and Admiral
  COPR. DNF resolved package dependencies normally. No Fedora-tagged package,
  `--nodeps`, `rpm --force`, or equivalent dependency bypass was used.
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
| `R67-ALMA-MN-BOOT-HUB` | Secure admin/portal bootstrap; installer exit 0, Ansible `ok=239 changed=105 unreachable=0 failed=0 skipped=141`; completed in 444 s. | PASS, scoped |
| `R67-ALMA-MN-BOOT-W1` | Secure worker bootstrap; `ok=155 changed=53 unreachable=0 failed=0 skipped=222`; completed in 357 s. Two heartbeat/metrics retries then convergence; temporary bootstrap key was rejected and pinned validator access remained available. | PASS, scoped, transient retries retained |
| `R67-ALMA-MN-BOOT-W2` | Secure worker bootstrap; `ok=155 changed=53 unreachable=0 failed=0 skipped=222`; completed in 385 s. Two heartbeat/metrics retries then convergence; temporary bootstrap key was rejected and pinned validator access remained available. | PASS, scoped, transient retries retained |
| `R67-ALMA-MN-POSTCHECK-INITIAL` | Exact EL10 candidate NEVRAs, expected Python helper package versions, SELinux Enforcing, firewalld, active hub/worker services, zero failed units, no Fedora-tagged RPMs, 2/1/1 WireGuard handshakes, empty rootless Podman inventories, and all three nodes active/healthy/available. | PASS, scoped |
| `R67-ALMA-MN-POSTCHECK-FINAL` | Repeated the same checks after fault tests and cleanup. | PASS, scoped |

The seven Python helper NEVRAs observed on the hub were `python3-alembic-1.20.1-4.el10`,
`python3-flask-alembic-3.3.0-4.el10`, `python3-flask-login-0.6.3-9.el10`,
`python3-flask-sqlalchemy-3.1.1-10.el10`, `python3-flask-3.1.3-3.el10`,
`python3-mistune-3.4.0-1.el10`, and `python3-typing-extensions-4.16.0-1.el10`.
The local repository also contained the exact six Admiral `.el10` packages.

## Runtime scenarios

| Test ID | Procedure and evidence | Status |
| --- | --- | --- |
| `R67-ALMA-MN-PLACEMENT-W1/W2` | Explicitly placed `e2e-whoami` on each worker. Same-key replay returned the same operation and instance. W1 briefly reported `running/unhealthy/unavailable` (`runtime_not_healthy`) before converging at poll 2; W2 converged at poll 1. PostgreSQL was ready, a SQL marker round-tripped, hub-to-workload HTTP over WireGuard returned 200, deprovision succeeded, and matching containers/pods/volumes/units/files were absent. Instances: W1 `inst_72bf43be0fdcb476`, W2 `inst_4471fedf5310aeda`. | PASS after health convergence, scoped |
| `R67-ALMA-MN-DB-OUTAGE` (#264) | Central PostgreSQL stopped for the controlled outage (~66 s). App HTTP remained 200 in sampled polls; journal contained 77 Fleet HTTP 503 records and zero 401/429. PostgreSQL, worker and instance recovered; post-recovery HTTP was 200 and deprovision cleanup succeeded. Instance `inst_5b7755b79a103579` on W1. | PASS, scoped |
| `R67-ALMA-MN-PARTITION` (#208/#237) | Removed W2's hub WireGuard route. Worker-to-hub request timed out (curl 28 / HTTP 000); the instance became unavailable and the node reached offline/degraded after about 143 s. Restoring the peer returned it to active/healthy/available in 12 s; HTTP returned 200 and cleanup succeeded. Instance `inst_83da887f261982e8`. | PASS, scoped |
| `R67-ALMA-MN-HUB-REBOOT` (#211) | Rebooted the hub with W1 workload active. Hub boot ID changed; services, two worker handshakes and fresh routes returned. Recovery was observed at poll 2, about 70 s after reboot request. Workload HTTP stayed 200, SQL marker persisted, deprovision succeeded and inventories were empty. Instance `inst_73e866e7b705b299`. | PASS, scoped |
| `R67-ALMA-MN-PODMAN-DELETE` (#228) | Injected Podman delete failure during W2 deprovision. First attempt visibly failed with resources present (exit 1); restored the original Podman executable and retried (exit 0). Final instance state was deprovisioned and containers/pods/volumes were empty. Instance `inst_207beee4df293d3e`. | PASS, scoped |

## Evidence and reproduction

The reproducible scripts are in `scripts/r67/r67-alma-multinode-*.sh` and
`scripts/r67/r67-multinode-postcheck.sh`. Installer and probe commands were run
from `/root/admiral`; raw logs are local, ignored, mode 0600 under
`packaging/build/validation/rc5-r67/` and are not included in Git because they
have not undergone full secret-redaction review. Their SHA-256 values:

The guest IPs and domains above are from the isolated libvirt test network.
For a newly created equivalent lab, set `SSH_KEY`, `HUB_KNOWN`, `W1_KNOWN`,
`W2_KNOWN`, and `OUT` to its pinned SSH identity/known-hosts files and a fresh,
unused evidence directory, then run the corresponding script:

```bash
scripts/r67/r67-alma-multinode-placement.sh "$SSH_KEY" "$HUB_KNOWN" "$W1_KNOWN" "$W2_KNOWN" 192.168.122.187 192.168.122.188 192.168.122.189 rerun-01
scripts/r67/r67-alma-multinode-db-outage.sh "$SSH_KEY" "$HUB_KNOWN" "$W1_KNOWN" 192.168.122.187 192.168.122.188 adm-r67-alma-mn-w1 "$OUT/db-outage"
scripts/r67/r67-alma-multinode-partition.sh "$SSH_KEY" "$HUB_KNOWN" "$W2_KNOWN" 192.168.122.187 192.168.122.189 "$OUT/partition"
scripts/r67/r67-alma-multinode-hub-reboot.sh "$SSH_KEY" "$HUB_KNOWN" "$W1_KNOWN" 192.168.122.187 192.168.122.188 adm-r67-alma-mn-hub adm-r67-alma-mn-w1 adm-r67-alma-mn-w1 "$OUT/hub-reboot"
scripts/r67/r67-alma-multinode-podman-removal-failure.sh "$SSH_KEY" "$HUB_KNOWN" "$W2_KNOWN" "$INSTANCE_ID" "$OUT/podman-failure" 192.168.122.187 192.168.122.189
scripts/r67/r67-multinode-postcheck.sh "$SSH_KEY" "$HUB_KNOWN" "$W1_KNOWN" "$W2_KNOWN" 192.168.122.187 192.168.122.188 192.168.122.189 adm-r67-alma-mn-hub adm-r67-alma-mn-w1 adm-r67-alma-mn-w2 "$OUT/postcheck.log"
```

For Podman failure injection, first apply `examples/apps/e2e-whoami.yaml` and
provision a disposable instance explicitly on W2 with
`admiralctl instances provision --app e2e-whoami --tier small --customer <unique-customer> --idempotency-key <unique-key> --node adm-r67-alma-mn-w2 --wait --wait-timeout 10m --quiet --output json`; pass its returned `instance_id` as `INSTANCE_ID`.

| Capture | SHA-256 |
| --- | --- |
| Hub installer | `2f01df7c3c14111c3e20307f18f02b8951ec251a5f6cf65a6b2ebc5722209d57` |
| W1 installer | `5d17bc7cc316481f8b28e08dedb3525130c31d813d224cde9c149791ea2945b1` |
| W2 installer | `e20b9c32d2cb8bb6a08ccabb38f0ce6de9592debc1b11578f8b4129b0a91e5d7` |
| Final postcheck | `9604cb3ee6c66fbd73b297a22fddcc2a8a79b863f047fb77e49e944150256f5b` |
| Placement/replay/SQL/HTTP/cleanup | `5998cb5af526d9a1f2d0ab0779640813669ca2c9c6533aa764f9ae67a105f9d1` |
| PostgreSQL outage top-level run log | `10b2acad69f767bf75cda22d85c6f9fcce4f2667e6e256eb0b489553f27c57ce` |
| Partition/rejoin top-level run log | `e932f33637302e665714207f6deafc6eaee9c188d1b2aabb30db736de40b13d8` |
| Hub reboot top-level run log | `12de9ec07c2e45a994fe5c5d7eca20eaf1dce19e15e8e76f686890d4b06fdb89` |
| Podman failure/retry top-level run log | `2e813d1840b9b48524c487af0f8017328f07168e0f0a1b4b0843e2c9ece7730b` |
| DB outage restricted evidence manifest | `975d044ba6691cda189da054c6040694ac38b76234aa4ee885eb1f4654de8cd5` |
| Partition restricted evidence manifest | `8014847aea5779be3cc71150b331644aac50ae7f0040f838eeeeb713f6f2280d` |
| Hub reboot restricted evidence manifest | `fa9176fe5cabeb7fc0006827ef994b99fcbb59e9a62b7389608b8d870e9d606b` |
| Podman failure restricted evidence manifest | `b6e17ee8ddbb9e05e075bc67d4f6707af7d5a76a373fefcf0d4a9416126d9956` |

One initial partition-helper invocation had an incorrect argument count and
stopped at its usage check before making any guest change; it is excluded. The
correct six-argument run is the recorded result above. No newly actionable
product defect was found in these scoped scenarios. They do not cover the full
Multi-Node catalog, task interruption/replay, broad isolation, external S3,
latency, exhaustion or performance. This is not a completed matrix cell.
