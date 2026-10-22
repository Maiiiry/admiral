# Release 55 candidate record

Recorded: 2026-10-22 UTC  
Status: **BUILT, PARTIALLY EXECUTED, INVALIDATED BY #256.** No R55 result counts toward the active matrix.

## Candidate identity

- Root source commit: `d5654ac776617154e2d63cb745d81c8d2ac9ee22`.
- `admiral-common`: `3888e28a77a0e81a0e7c7fb8ddbf636bcce181a4`.
- `admirald`: `afcf02f094cf7c572cd0e135a280ebb48c0202d5`.
- `admiral-fleet`: `3cb2bf83d9787947d3b3212f6c1f92bf3fa81fda`.
- `admiralctl`: `49cf2428c064434c65af9a14f96975c1bb2db637`.
- `admiral-flagship`: `b7325bbc71fc474a521496e593b2967e4d555ac1`.
- `admiral-harbor`: `dd39e9a74bf658ecf6fd6e9f8bd30b2ddf82d7db`.
- Version/release: `0.0.1rc5-55.el10`; all six root package specs declared Release 55.
- Host: Rocky Linux 10 x86_64, 4 vCPU, 7.5 GiB RAM, 4 GiB swap; 85 GiB free at candidate review.
- Builder validation: all six RPM `%check` stages passed. Root CI [39813630228](https://github.com/admiral-project/admiral/actions/runs/39813630228) and `admirald` CI [39813463149](https://github.com/admiral-project/admirald/actions/runs/39813463149) passed for the exact source revisions.
- Build-log SHA-256 recorded at build time: `df27c52845219b0163d2dc6b59f51205925ad7778396e5834dfd33e393cc2026`.
- Candidate RPMs were staged in the isolated local repositories under `http://192.168.122.1/rc5-r55/{el10,fedora}/x86_64`. Both repository metadata endpoints returned HTTP 200. This staging does not prove a clean dependency transaction from published repositories.
- Seed images were the SHA-verified 2026-10-22 images recorded in `release54-seed-sha256.txt`; R55 used new disposable overlays.

## Exact RPM NEVRA and SHA-256

| Package | NEVRA | SHA-256 |
| --- | --- | --- |
| `admiral-common` | `admiral-common-0.0.1rc5-55.el10.noarch` | `d9ae38b5062a1b0e524f8de143b5ec49ead5a2a69332348b299f22795cda1547` |
| `admirald` | `admirald-0.0.1rc5-55.el10.x86_64` | `38771d633ff405afaf4c51b5967416fd04fe56a75d5f62d30ed59fd2e6e02b35` |
| `admiral-fleet` | `admiral-fleet-0.0.1rc5-55.el10.x86_64` | `dcaaa197df266a9779c0d188a39faf9dd8ff542fe536d26eae2c785bd8811b54` |
| `admiralctl` | `admiralctl-0.0.1rc5-55.el10.x86_64` | `978483da5d440e8ad99e6384368b44f5aee1e40b262ad1646cf0487987bb6474` |
| `admiral-flagship` | `admiral-flagship-0.0.1rc5-55.el10.noarch` | `0c542b87b69a6d5d0395ea7033824554e21ce1333b621861bfb8e833b6f47b10` |
| `admiral-harbor` | `admiral-harbor-0.0.1rc5-55.el10.noarch` | `673638c2d11a842921310c58928b723f19c0445c429673d841b24cfa633875b6` |

The machine-readable digest list is `release55-rpm-sha256.txt`.

## Fresh Single-Node install subset

Two fresh seed overlays installed these exact six RPMs with the supported installer:

| OS | Guest | Installer result | Package transaction notes |
| --- | --- | --- | --- |
| Fedora Rawhide x86_64 | `adm-r55-fedora-single`, `192.168.122.244` | Exit 0; installer elapsed 10m34s; Ansible `failed=0`; `admiralctl status` healthy; SELinux enforcing | Installer applied 15 packages including a 93 MiB kernel update from then-current Rawhide metadata. |
| Rocky Linux 10.2 x86_64 | `adm-r55-rocky-single`, `192.168.122.245` | Exit 0; installer elapsed 9m50s; Ansible `ok=232 changed=97 failed=0`; `admiralctl status` healthy; SELinux enforcing | Installer updated `crun`; exact seed contained `python3-pyOpenSSL-25.0.0-1.el10_1`. |

These installs and targeted scenarios did not complete the full Single-Node criteria and did not prove a clean package solve from the published repositories.

## Targeted outcomes on the exact R55 set

All results below are **scenario evidence only**. R55 is invalidated, so none is accepted toward a matrix cell.

| Scenario | Fedora Rawhide | Rocky Linux 10 |
| --- | --- | --- |
| Three simultaneous provision calls with same idempotency key | PASS; one operation/instance; cleanup succeeded | PASS; one operation/instance; cleanup succeeded |
| Resize and reactivate with SQL marker and persisted secrets | PASS; marker preserved; cleanup succeeded | PASS; marker preserved; cleanup succeeded |
| Fail a required declared DB service | PASS; operation failed and instance unavailable; cleanup succeeded | PASS; same result |
| Local DB backup/restore | PASS; checksum and marker restoration verified; cleanup succeeded | PASS; checksum and marker restoration verified; cleanup succeeded |
| Same-host isolation sample, run twice | PARTIAL; namespaces, privilege, NoNewPrivs, socket, host-published port checks passed; container-IP denial NOT TESTED | Same partial result |
| Kill workload app container, `admirald` and Fleet | PASS; systemd recovery, API/workload healthy, cleanup succeeded | PASS; same result |
| Full guest reboot with SQL marker | **FAIL — false available state**; details in `release55-invalidation-reboot-health.md` | PASS for this sampled reboot; stayed unavailable until all containers and PostgreSQL were ready, then HTTP/SQL marker passed |

Protected logs are stored mode `0600` under `/var/lib/libvirt/images/admiral-validation/validation/rc5-r55/single/`. Their exact SHA-256 values are in `release55-runtime-log-sha256.txt` and the invalidation record. The private SSH key and cloud-init credentials remain outside Git.

## Candidate disposition

Fedora's reboot failure is an actionable release defect in effective availability. The source correction is implemented and pushed in `admirald@a816f47` and `admiral-fleet@74e8b0f`; the component CI/run state and regression evidence are tracked in #256. The next candidate must increment all six RPM Release fields, pin the corrected component SHAs, rebuild all six packages, and restart all eight matrix cells from fresh overlays. Matrix remains **0/8**.
