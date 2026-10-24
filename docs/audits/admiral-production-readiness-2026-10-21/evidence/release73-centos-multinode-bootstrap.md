# Release 73 CentOS Stream 10 Multi-Node bootstrap — historical snapshot

> Snapshot captured before the second worker and R73 workload/recovery probes were completed. The current CentOS Stream Multi-Node progress is in [`release73-centos-multinode-progress.md`](release73-centos-multinode-progress.md).

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Candidate: six coordinated `0.0.1rc5-73` RPMs; see [`release73-candidate.md`](release73-candidate.md).<br>
Execution date: 2026-10-24 UTC. The audit has run across **three calendar days** (2026-10-21 through 2026-10-24), not hours.<br>
Result: **PARTIAL**. One clean worker installed and registered; the second worker and all workload scenarios remain outstanding.

## Environment and seed

- CentOS Stream 10 (Coughlan), x86_64; guest kernel `6.12.0-278.el10.x86_64`.
- Seed: `/var/lib/libvirt/images/admiral-validation/seeds/CentOS-Stream-10-seed-20261024-r71.x86_64.qcow2`.
- Seed SHA-256: `1d8ec7ee74a69ae22d2957440add7e218befa58dd42bd8cb063219860791c15b`.
- Fresh-clone `dnf --refresh check-update` returned 0 at 2026-10-24T13:29:03Z. A second check on W2 immediately before install returned 0 at 13:58:37Z.
- The seed has EPEL, CRB, Admiral COPR and CentOS Stream repositories. The signed Release 73 local candidate repository was added to W2 before install; DNF resolved `admiral-common-0.0.1rc5-73.el10.noarch` from that repository. Fedora or cross-distribution RPMs were not used.
- Freshness logs are protected mode `0600` under the ignored `packaging/build/validation/rc5-r73/runtime/seed-freshness/` tree. The captured W2 pre-install check SHA-256 is `820b45a163ab3cfa8ba0933d6cb5d1c28c77c1b3893998ed1cce924577bb40f2`.

## Topology and worker install

The R73 admin/portal hub is `adm-r73-centos-mn-hub` (`10.77.0.31`, WireGuard `10.99.0.1`). W2 is `adm-r73-centos-mn-w2` (`10.77.0.33`, WireGuard `10.99.0.3`). Both use the CentOS seed above. The prior W1 attempt is retained as a failed setup attempt but shut off; this is currently a two-guest running cluster, not the required three-guest topology.

The supported secure `admiral-install --worker-node` command completed on W2 from the R73 hub between 13:50:19Z and 13:55:07Z (288 seconds). Ansible recap: `ok=152 changed=52 unreachable=0 failed=0 skipped=224`; installer/SSH exit code 0.

Post-checks recorded in the protected local file `packaging/build/validation/rc5-r73/runtime/multi/centos/setup/w2-postinstall.txt` (SHA-256 `4e07f4959431a5a051be7ea70d94999fcdf66ac0980bcfdf8b00864cba707d59`):

- W2 has exact `admiral-common-0.0.1rc5-73.el10.noarch` and `admiral-fleet-0.0.1rc5-73.el10.x86_64` packages.
- The package owns `/usr/lib/systemd/system/admiral-wireguard-peer-revoke.socket`; it is disabled on the spoke as expected.
- Fleet, firewalld, Fail2ban and auditd are active; SELinux is `Enforcing`.
- Public firewalld zone exposes SSH and `51820/udp` only.
- The hub reports W2 `active/healthy/available` at WireGuard `10.99.0.3` and underlay `10.77.0.33`.
- The temporary test bootstrap key was removed from W2, the hub and the host after installation.

Raw installer logs remain local and mode `0600`: `install-w2.log` SHA-256 `12a1568edabf8c575d37bb14a5c2ebe5b48abfc90642b8c0ffc4682dcd2cf03a`; wrapper metadata SHA-256 `a6d993524d311afb93a69c80fb40db7e7dc602d5c8d676b8617c7fdbb5208689`.

## Excluded first attempt and diagnosis

W1's first secure installer attempt stopped with `failed=1` when the R73 playbook tried to disable `admiral-wireguard-peer-revoke.socket`. Inspection confirmed that the exact R73 RPM contains the unit, but W1 still had `admiral-common-0.0.1rc5-57.el10` from COPR. The W1 enabled-repository list did not include the signed local R73 candidate repository, although the hub did. The hub had not registered W1, and the failed attempt had not reached worker registration.

This is an invalid candidate-install attempt caused by incomplete lab repository setup; it is **not counted as a product failure or a pass**, and it did not justify a new Admiral defect issue. The diagnosis and raw-log hashes are in the protected local file `packaging/build/validation/rc5-r73/runtime/multi/centos/setup/w1-attempt-diagnosis.txt` (SHA-256 `4948a5691399b797c3a466567fff4e19f8c697c02543eb65335c16db7c1e1f48`). W2 was then prepared with the signed candidate repository and installed successfully.

## Cell status

`R73-CENTOS-MN-W2-BOOT` is **PASS — scoped installation and registration only**. The CentOS Stream 10 Multi-Node cell remains **PARTIAL**. The cell requires a third clean guest, a second worker, placement and lifecycle checks on both workers, plus recovery, security and consistency scenarios. No workload, outage, reboot, removal, concurrency, isolation or performance result is inferred from this bootstrap.

The active R73 matrix is now **4/8 PASS, 3/8 PARTIAL, 1/8 NOT TESTED**: all four Single-Node cells passed; Rocky, AlmaLinux and CentOS Stream Multi-Node have scoped evidence but remain incomplete; Fedora Multi-Node is not tested. Full production readiness remains **NOT VALIDATED**.
