# Admiral Release 53 candidate build record

Audit: `ADM-AUDIT-2026-10-21`
Candidate: Admiral RC5 Release 53, x86_64 RPM set.
Disposition: **BUILT; partial Single-Node runtime probes completed on all four target OSes.** All six RPMs completed their `%check` stages and both isolated repositories expose the same six Release 53 package identities. This build fixes the Release 52 resize/reactivation secret-loss defect (#246) at `admirald@b4b125e`. Fresh Fedora Rawhide, Rocky Linux 10.2, AlmaLinux 10.2 and CentOS Stream 10 Single-Node guests installed R53 and passed named resize/reactivation, concurrent same-key idempotency, local PostgreSQL backup/restore, required-service failure handling, selected process recovery and targeted host reboot with SQL-marker persistence; isolation inspection is partial because direct cross-workload TCP denial was not tested. No complete R53 cell has passed; the release matrix remains **0/8**. See [`release53-initial-single-node-execution.md`](release53-initial-single-node-execution.md) and [`release53-followup-single-node-execution.md`](release53-followup-single-node-execution.md).

## Source identity and CI

The signed root package-preparation commit is [`e149571`](https://github.com/admiral-project/admiral/commit/e149571e6124d1e4223f2c868a2a1c1f685f8d58), with green root CI [39738673606](https://github.com/admiral-project/admiral/actions/runs/39738673606). Before building, all five component submodules were fetched and compared with their current `origin/main`; the selected SHAs matched:

| Component | Selected SHA | CI |
| --- | --- | --- |
| `admirald` | `b4b125ee293ac65a863256666faa22199720de0f` | [39737323015](https://github.com/admiral-project/admirald/actions/runs/39737323015) — success |
| `admiral-fleet` | `740b690fdb49e86fa63c9db2b56a1e576247b162` | [39663860552](https://github.com/admiral-project/admiral-fleet/actions/runs/39663860552) — success |
| `admiralctl` | `5ed381d7d152e1606e78fafe332587cca09bc989` | [39724553667](https://github.com/admiral-project/admiralctl/actions/runs/39724553667) — success |
| `admiral-flagship` | `3911eb784aef732f0bbe4662d1dbc6a5947eb659` | [39654771764](https://github.com/admiral-project/admiral-flagship/actions/runs/39654771764) — success |
| `admiral-harbor` | `92c5ccac6a647cb85da36b056cb3352f391ab8c9` | [39705906726](https://github.com/admiral-project/admiral-harbor/actions/runs/39705906726) — success |

`admirald` includes the #246 correction to preserve workload secrets during resize and reactivation. Root `main`, Makefile pins and corresponding specs select this exact component SHA. `python3 scripts/validate-release-refs.py` passed before the build. All six RPM `Release` fields were incremented to 53, including packages whose source did not change.

## Build host and checks

The build ran on the isolated Rocky Linux 10.2 x86_64 validation host (4 vCPU, 8 GiB RAM, 4 GiB swap, SELinux enforcing, KVM/libvirt available) on 2026-10-22. Disk availability was 89 GiB before and after. No guests were active during the build. The host has Go `1.26.7-2.el10_2`, below the RPM BuildRequires floor `1.26.10`; the build used `--nodeps` with `GOTOOLCHAIN=auto`. This is a documented host package limitation; no `%check` stage was skipped.

Build command:

```bash
GOTOOLCHAIN=auto make rpm-admiral RPM_ARCH=x86_64 RPMFLAGS="--target x86_64 --define '_topdir /root/admiral/packaging/build' --define '_sourcedir /root/admiral/packaging/build/SOURCES' --define '_specdir /root/admiral/packaging/rpm' --define '_builddir /root/admiral/packaging/build/BUILD' --define '_rpmdir /root/admiral/packaging/build/RPMS' --define '_srcrpmdir /root/admiral/packaging/build/SRPMS' --define '_tmppath /root/admiral/packaging/build/tmp' --nodeps"
```

The raw restricted log is retained locally outside Git at `packaging/build/validation/rc5-r53/evidence/build.log`, mode `0600`, SHA-256 `9466bdf851eecdce482a5a0e549fc777aa3692cae3dbdca1a0610aa97b5f4479`. It contains six `Executing(%check)` sections and ends with `=== All 6 Admiral RPMs built ===`. Harbor's RPM check ran 350 tests: **350 passed, 307 warnings** in 207.49 seconds. The warnings are non-fatal and are the known deprecation-warning class tracked in #242.

## RPM identities

| NEVRA | SHA-256 |
| --- | --- |
| `admiral-common-0.0.1rc5-53.el10.noarch` | `7dec4deb08a1a38e69078183886865a8e27847ffe0519d6cb2d1ca3925bfca01` |
| `admirald-0.0.1rc5-53.el10.x86_64` | `8cb69f785f6d2bd9afcde464abeb9bbe364567138d534690208f8f7e9b86022c` |
| `admiral-fleet-0.0.1rc5-53.el10.x86_64` | `35c8eeae92320fa3fe15f7a17a9e264d06c197c89af1cf18916c0ea3ef77f913` |
| `admiralctl-0.0.1rc5-53.el10.x86_64` | `335deea3af9a5bba8cd4e3502b02048d97e14453bcd00457e4438ccfa86553ff` |
| `admiral-flagship-0.0.1rc5-53.el10.noarch` | `edeefbbbc4604d90365b2643255bcb33c4f3b3e28739ebf2fc6b08ed716920f7` |
| `admiral-harbor-0.0.1rc5-53.el10.noarch` | `6dfee94a61dee065f57ec5945829d3caa7ad95dc51ad917af44217f51bb68274` |

Machine-readable checksums are in [`release53-rpm-sha256.txt`](release53-rpm-sha256.txt). The local staged repositories were compared byte-for-byte against these hashes.

## Isolated package repositories

Both local repositories contain 13 RPMs: these six Admiral packages and seven pinned Python support packages. Each `repoquery` returned the six exact Release 53 NEVRAs above; the identical outputs are retained in [`release53-el10-repoquery.txt`](release53-el10-repoquery.txt) and [`release53-fedora-repoquery.txt`](release53-fedora-repoquery.txt). Their repository metadata and config digests are:

| Repository | Metadata endpoint | HTTP | `repomd.xml` SHA-256 | Repo config SHA-256 |
| --- | --- | --- | --- | --- |
| EL10 | `http://192.168.122.1/rc5-r53/el10/x86_64/repodata/repomd.xml` | 200 | `d8593ff3a852b3c22449f8903d6b541d8e39d86a3c5b3081db6512bfd56273c4` | `ee8f99d0699d1f9004df240e1f548cdc37ad95e3b723eb0091a22b38a6862bf9` |
| Fedora Rawhide | `http://192.168.122.1/rc5-r53/fedora/x86_64/repodata/repomd.xml` | 200 | `29a93a13a730849d44627a000b4bbc08c4ee9cdc5b7fbef347206e22d7f36a96` | `4fee2f720ea3ff02773466f9671800b786116dbe8a25880b422927aae529e21e` |

The local repo configurations, RPM copies, full checksums and raw logs remain under the ignored `packaging/build/validation/rc5-r53/` directory. The repositories are lab-only and are not public release publication.

## Runtime disposition

Fresh R53 Fedora Rawhide, Rocky Linux 10.2, AlmaLinux 10.2 and CentOS Stream 10 Single-Node overlays installed the exact package set. Each OS passed named #246 resize/reactivation, concurrent same-key idempotency, local PostgreSQL backup/restore with a marker, failed declared-service reporting, selected process recovery after container/Admirald/Fleet termination, and a targeted real guest reboot with boot-ID change, SQL marker and HTTP recovery. Selected same-host namespace and privilege checks passed, but direct cross-workload TCP denial was not tested. These are targeted scenario passes only; after host reboot all APIs remained unavailable until fresh health reports arrived (Fedora poll 6, Rocky poll 7, Alma poll 7, CentOS poll 6). No complete R53 cell passed. Exact operation evidence and restricted raw-log hashes are recorded in the initial and follow-up Single-Node execution reports. R53 remains active; matrix completion is **0/8**. Stale DHCP lease issue #247 and reboot-harness issue #248 affect lab tooling, not Admiral packages; both fixes are on root main with green CI. Issue #249 records a runbook correction and remains open with `fix-proposed`.
