# RC5 Release 66 targeted Single-Node validation

Audit: `ADM-AUDIT-2026-10-21`  
Candidate: RC5 Release 66, package-preparation commit `c5365da267eca6f1f5246c60a26c7875f07a5ffa`  
Result: **PARTIAL — named scenarios passed on Rocky Linux 10.2 and Fedora Rawhide; 0/8 matrix cells complete.**

## Environment and candidate

Two fresh disposable libvirt guests were cloned from the exact updated R66 seeds. Each guest had 2 vCPU/2 GiB RAM, SELinux Enforcing and x86_64. The guests installed the six matching EL10 or Fedora Release 66 Admiral RPMs and ran the packaged secure `admiral-install --single-node` path. The installer returned zero failed tasks on each guest:

| OS / guest | Guest IP | Seed SHA-256 | Install recap |
| --- | --- | --- | --- |
| Rocky Linux 10.2 / `adm-r66-rocky-validation` | `192.168.122.250` | `64d918c2b1b8d69d210372d0e80252798178e3ae9b6b7f4af4dbec2b39b5b3d0` | `ok=232 changed=97 unreachable=0 failed=0 skipped=148` |
| Fedora Rawhide / `adm-r66-fedora-validation` | `192.168.122.251` | `5e79471888e5e0bbc24a1d410b8cebc054d0c459b61f970cd89018eb04cb5b7c` | `ok=238 changed=100 unreachable=0 failed=0 skipped=142` |

Both reported all six candidate NEVRAs, active PostgreSQL/Admiral/Caddy services, healthy control plane, rootless Podman and SELinux Enforcing. Full package identities and SHA-256 values are in [`release66-candidate.md`](release66-candidate.md) and its copied RPM manifests.

## Named scenarios

| Test ID | Procedure | Observed result | Status |
| --- | --- | --- | --- |
| `R66-SN-ROCKY-INSTALL-01` / `R66-SN-FEDORA-INSTALL-01` | Fresh-seed baseline, install exact RPM set, secure Single-Node initialization and service baseline | Installer had zero failed/unreachable tasks; services active; API/control plane healthy; rootless Podman | PASS, scoped |
| `R66-SN-ROCKY-E2E-01` / `R66-SN-FEDORA-E2E-01` | Apply `examples/apps/e2e-whoami.yaml`; provision app + PostgreSQL; inspect containers, pod, volume, readiness and HTTP | Operations succeeded; app HTTP 200; DB accepted connections; app, DB and infra containers were up | PASS, scoped |
| `R66-SN-ROCKY-IDEMP-01` / `R66-SN-FEDORA-IDEMP-01` | Replay provision with the same stable idempotency key; deprovision; inspect state and resources | Replay returned the same operation and instance (`op_5057db2aac0dd809` / `inst_f9770911cfd74ce0` Rocky; `op_fc9db017502de11c` / `inst_3baf3db801c26426` Fedora). Cleanup left zero matching containers, pods, volumes and artifacts | PASS, scoped |
| `R66-SN-ROCKY-FLEET-01` / `R66-SN-FEDORA-FLEET-01` | Restart `admiral-fleet` while workload is active | Instance remained `running/healthy/available`, DB marker persisted, HTTP 200; recovery observed in about 2 seconds | PASS, scoped |
| `R66-SN-ROCKY-REBOOT-01` / `R66-SN-FEDORA-REBOOT-01` | Provision fresh instance, insert SQL marker, reboot the guest, confirm boot ID change, service/workload recovery, marker and HTTP; deprovision and inventory resources | Both boot IDs changed. All six system services were active; instance `running/healthy/available`; three containers up; PostgreSQL accepted connections; SQL marker remained `r66-{rocky,fedora}-boot-id-20261023 / pre-reboot`; dynamic host port returned HTTP 200. Deprovision succeeded and left zero containers, pods, volumes and user units | PASS, scoped |
| `R66-SN-ROCKY-FAILED-SVC-01` / `R66-SN-FEDORA-FAILED-SVC-01` | Apply `fixtures/e2e-failing-db.yaml`; provision the app with PostgreSQL `/bin/false`; inspect operation, instance, DB unit/container; deprovision and verify cleanup | Both operations terminated `failed` with the DB-readiness error. Instance state was `failed/stopped/unavailable` on Rocky and `failed/unhealthy/unavailable` on Fedora. After failure, the DB unit was not loaded and no matching DB container remained. Deprovision succeeded; inventories had zero containers, pods, volumes, matching user units or artifacts | PASS for #227 regression, scoped |

The exact reboot test operation/instance IDs were Rocky `op_72e8c61b019647aa` / `inst_9bd91be79dc63659` and Fedora `op_f150aec8fb56a835` / `inst_84b1c06f0a536428`. Deprovision operations were `op_b928d18fe9cb90b4` and `op_4034986a124b95d7` respectively. Before/after boot IDs and complete outcome are in the final raw logs below.

## Reboot probe harness corrections

Two early post-reboot probes were not counted as product failures: the SSH session started in a validator home directory that was inaccessible to `sudo`, so the check was rerun from `/tmp`; a subsequent query used the wrong table name `admiral_reboot_marker`. The pre-reboot setup had inserted into `public.admiral_audit_marker`; querying that exact table after reboot returned the expected marker on both guests. The failed harness attempts remain preserved in the local ignored validation directory. A prior HTTP probe also initially assumed port 40000; the actual dynamically assigned port was obtained with `podman port` and returned HTTP 200. These are harness corrections, not product defects.


### R66 failed declared-service evidence (#227)

This exact-candidate probe ran against the same clean Rocky/Fedora Single-Node guests after the lifecycle/reboot checks. It used the tracked `scripts/r66/r66-single-failed-service.sh` with unique customer IDs and idempotency keys. Provision operations were Rocky `op_496dbdf593ec19fd` / instance `inst_8151d8ae75820074` and Fedora `op_68658456802ea47e` / instance `inst_55a0ecaa91eccc0c`; both failed with `service "db" failed readiness after provision`. The failed instances were unavailable and never reported healthy or available in the terminal snapshot. The failed DB unit had already been unloaded (`LoadState=not-found`) and no DB container was present before explicit deprovision. Deprovision operations `op_8acab55e137b5bdf` and `op_33d108b356933218` succeeded; final state was `deprovisioned/unavailable`, with zero matching containers, pods, volumes, user units or artifacts. Detailed captures are mode 0600 under `packaging/build/validation/rc5-r66/`.

| Capture | SHA-256 |
| --- | --- |
| `rocky-single-failed-service-final.log` | `bc19f660b15649e84e9e5f4fe6ca7a7285e29925941e357a61f33ac13f15cfe8` |
| `fedora-single-failed-service-final.log` | `1d23badda727bccd68702d071fad5296ec5e134bd79e63da075a24d33a127613` |

An initial draft of the harness assumed the DB unit would remain loaded as `failed`. Both guests had already unloaded the service by the time the failed provision returned. That first capture is preserved; the corrected tracked script accepts a failed or removed unit only when no DB container remains, performs deprovision, and verifies all final inventories. This is a harness correction, not a product defect.

## Evidence and boundaries

Raw files are under ignored local path `packaging/build/validation/rc5-r66/`. Hashes:

| Capture | SHA-256 |
| --- | --- |
| `rocky-single-fresh-baseline.log` | `a5e1c04fdd6421a438a0149fcbd2ef1bd8e143a951f7023868a9505472064e9b` |
| `fedora-single-fresh-baseline.log` | `d69c90d88a4403cf45f9f4d54fd1a6e1d55cf90d94fd95fe14d6666a16f84e90` |
| `rocky-single-rpm-install.log` | `49554fb1ef8aeb2ea82f9b26244101fa9268249930f13257303f055c20360741` |
| `fedora-single-rpm-install.log` | `3ffc13e769635fb2e7e93c98cf24d296f24228404b6df5dd78c9a54792b68256` |
| `rocky-single-install.log` | `86d986885afeab00226f2c8b34198994f7db5e842b45f11f74c3f446d359bc4d` |
| `fedora-single-install.log` | `9f02ce5b0a2b4112f6691e750ec52d2f462521fbf76e743c0e2001f87eeff2c7` |
| `rocky-single-runtime-e2e.log` | `e504b1371709d2234604df76945f528cb96a699c07fadef24ebaf713450ccbfa` |
| `fedora-single-runtime-e2e.log` | `39d6b9348e1398b58415d35b000e41c8fa70544023745c6061fa6cc99e591013` |
| `rocky-single-idempotency-lifecycle-final.log` | `5c22b988963933a4cbf82da40bd52ae9e53174b1b3c8acc7f4648fb26a22848c` |
| `fedora-single-idempotency-lifecycle-final.log` | `9137abfa2847ae1235615abdc69c7dff87da1541f747c3ea7f9360183f1dd1e8` |
| `rocky-single-fleet-restart-recovery.log` | `f38393f1bedacfafb1255568f4437d9efce746fbdcdf38252b27a5781f83176b` |
| `fedora-single-fleet-restart-recovery.log` | `477c7b40b90a8e0dc7a2ccff8e108d1fac3b0f4890cfd1b1295cd5b37c752464` |
| `rocky-single-exact-reboot-precheck.log` | `b9fb6172e96debba8f1daa297d75a31710227622db6357ef5284b7bf5dfd8ca0` |
| `fedora-single-exact-reboot-precheck.log` | `3b7520be7b6e75095212dd04c0c6fd1bc66fed6940ca5c3924c0f8933216aa3d` |
| `rocky-single-exact-reboot-final.log` | `8a31344b78052b5a0fc4a31a3ac1e93e1520f3df3a7a2b9e20e96ecc60fddd3d` |
| `fedora-single-exact-reboot-final.log` | `6ba2799c866d72292d8647c37964658864d7b20998e7652d003c4b104251ae52` |
| `rocky-single-deprovision-cleanup-recheck.log` | `6bc86170ce278816787e288d2941510a86ba00c142bbb86d689a6c0e3e3fed5d` |
| `fedora-single-deprovision-cleanup-recheck.log` | `6bc86170ce278816787e288d2941510a86ba00c142bbb86d689a6c0e3e3fed5d` |

The local VM execution log files are mode `0600`; no credentials are included in this committed report. Public hostname/DNS/TLS routing was not configured on the cloned single-node test VMs and is **NOT TESTED**. This record does not validate the complete Single-Node cells: configuration/secrets/network lifecycle, broad concurrent update/delete, negative isolation/security tests, controlled exhaustion, external backup/restore, additional fault categories, and performance sampling remain outstanding.
