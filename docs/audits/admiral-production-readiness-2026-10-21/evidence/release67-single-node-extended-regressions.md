# R67 Single-Node extended regression evidence

**Result: the listed named scenarios passed on all four x86_64 target OSes; no Single-Node cell is complete.**

Date: 2026-10-23 UTC<br>
Candidate root source commit: `833d15aa4f8e96be30d28dad169b9d06a4d9894d`<br>
Candidate: RC5 Release 67, six exact native RPMs per guest<br>
Guests: `adm-r67-fedora-single`, `adm-r67-rocky-single`, `adm-r67-alma-single` and `adm-r67-centos-single`; Fedora Rawhide 46, Rocky Linux 10.2, AlmaLinux 10.2 and CentOS Stream 10 x86_64 respectively, each a fresh 2-vCPU/2-GiB overlay from its updated seed.<br>
Matrix status: **0/8**. These tests add named scenario evidence and do not complete any cell.

The four R67 guests used their distribution-native RPMs (`.fc46` on Fedora and `.el10` on EL10). Fedora did not install or force-install EL10 binaries. Each per-OS capture is a mode-0600 raw log named `packaging/build/validation/rc5-r67/<os>-single-<scenario>.log`; hashes let reviewers identify the exact capture without committing unsanitized output.

## Results

| Test family / reproducible helper | Fedora Rawhide | Rocky Linux 10 | AlmaLinux 10 | CentOS Stream 10 |
| --- | --- | --- | --- | --- |
| Declared PostgreSQL service failure (#227); `scripts/r67/r67-single-failed-service.sh` | **PASS** — terminal failed operation, unavailable instance, no DB runtime residue; `6922616279228809471cb2ef216ae4c9a12057696cac903739ee75691bd73cb7` | **PASS** — same assertions; `dbf88c5458ed9cac7b05b4640a90f3736a7e3ad2238dd54038e1d07a1cdf7845` | **PASS** — same assertions; `39ccef85a2b845e3c517da95995ae489fd2e36fc00736bfb55bcace10851f18e` | **PASS** — same assertions; `97622c25f7929e98f3d5acf453b5b3f03b4777f7b17a77f09aa228287fe0f797` |
| Local PostgreSQL backup/restore; `scripts/r67/r67-single-backup-restore.sh` | **PASS** — checksum verified, restore while active rejected with HTTP 409, SQL marker restored, cleanup; `67c95247f119f2c708159218157dab95756adae0d1f84eab95d52a694b790ba4` | **PASS** — same assertions; `7278ef0c7f9f6c1e1577e415ce851755ead3319defa0326fe5f7e80bee8862fa` | **PASS** — same assertions; `f0e57dbb64fb83d4b5de5d14bbfe859853eeff87d94d60e7db32aeb4e83a3dca` | **PASS** — same assertions; `a4d029fe6eee8b09da9c1e0494647725342612d9b0cc432c781d1c2cda789f09` |
| Authentication negatives, `scripts/r67/r67-single-auth-negative.sh` | **PASS** — eight unauthenticated/bad synthetic-token API requests returned HTTP 401; `59798ca88989c4c34d2634ca2bff3cc62e1454daeebfbe68d848214780eda669` | **PASS** — same endpoint/sample set; same-host capture hash above | **PASS** — same endpoint/sample set; same-host capture hash above | **PASS** — same endpoint/sample set; same-host capture hash above |
| Same-host isolation sample, `scripts/r67/r67-single-same-host-isolation.sh` | **PARTIAL** — distinct secrets/volumes and PID/network namespaces; no privileged mode or Podman socket mount; tested cross-workload host-mapped app port was refused; direct DB-IP probe **NOT TESTED**; `00834a744bbf713013272dcf0d4b7b45aa8ece6c98ad65e7f6740a1ea74b8461` | **PARTIAL** — same limits; `a00c417230c3cfc744492d9f54b751967693d1c3d48f21ca2a7067b58c9f4740` | **PARTIAL** — same limits; `733d7cedae0b44be1ff850be51806f7dc3e5875043ba4c988f9148c1c22a8704` | **PARTIAL** — same limits; `3e64715134f7257c3e5560b44201861c4c3b5a09638696e6ae43a2e9b8bba1a2` |
| Effective cgroup limits, `scripts/r67/r67-single-cgroup-limits.sh` | **PASS** — pod ancestor enforced `memory.max=536870912`, `cpu.max=100000 100000`; `bb26b2e8d306af2138b200e1418ad13f9ca414c889508e3864f911cdc1b01bd3` | **PASS** — same small-tier limits; `4a597ea3f71972f89dc2ce7ec4325044cca1421f4d63e09ba63994bce64557ae` | **PASS** — same small-tier limits; `15928c673292de797198374ad027e7029eab81a7d45de2960b7723e58322cee5` | **PASS** — same small-tier limits; `d34f91e28b1690c48bb058eb30e8ed923357fbebb3e315bc3afcc63982624ef5` |
| Three simultaneous same-key provision requests, `scripts/r67/r67-single-concurrent-idempotency.sh` | **PASS** — one operation/instance, exactly three runtime containers, clean deprovision; `1530fd32f30d3a5e7764727bdb81fe1a4227c59272b2b062bf0870ef64e6d74c` | **PASS** — same assertions; `02928d713a732454dfc1774091e3613e6fd0bfae37798f5281e8e550ae81c81d` | **PASS** — same assertions; `1dcef12421ddca95c1ec90d8ee178c18407d1b3fb617641a7313b6de1c41a639` | **PASS** — same assertions; `9c4d4486feb13ef86265713f2b92e6caa962888f6e89db011666f2d939ffb5df` |
| Concurrent resize vs forced deprovision, `scripts/r67/r67-single-concurrent-update-delete.sh` | **PASS** — both operations terminal, final instance deprovisioned, no resources; `5633bc57ff932fb5c87bcb28c8705102cb910ffb3d1246b9529afb45c62cd726` | **PASS** — same assertions; `dff6cc272840055332150a5754c2b44fb23efc13d09733247b39c2830abf5885` | **PASS** — same assertions; `b7c93609e68d6667bb45f8347fa2bb9b0c3a4d652b714b7a1190a68cecd4c8a0` | **PASS** — same assertions; `e9d93dafa9cb3907872a0c012fe86eac651aac0a30113387b6c5bf25f782d682` |
| Workload PostgreSQL outage/recovery, `scripts/r67/r67-single-db-service-outage.sh` | **PASS** — API unavailable by 7 s; DB restarted, instance/data recovered; `aa94f1514dede269a957fcd56a0f0c378b47b422f3f54e94e0a0c9327d338e61` | **PASS** — same recovery assertions; `247d303f754892d58eebd4b72fb3543f6f961f056fe3ecbdd270eb6e0687508d` | **PASS** — same recovery assertions; `458e42c3d59a49d7e5600ccfd0ccebf77b04c487e06248c75f190b8b96940934` | **PASS** — same recovery assertions; `7131f446a1caf37f3a1ad90d52fcf2ecbd2b63a21dc36f1c92a92e1ed9362551` |
| User systemd manager restart, `scripts/r67/r67-single-user-systemd-restart.sh` | **PASS** — API remained unavailable until fresh DB health, then HTTP/SQL recovered; no false healthy/available samples; `729faae6a99fba876ba0df455e9ca3e9e4466288aa0555a6369859de2af8dcbc` | **PASS** — same assertions; `07efb1d2a013544f5e1b64e571240c6b96cfcb83bcbd3283bfeac76cbb938f21` | **PASS** — same assertions; `ef399825b80ff4d6ffc8800a1255c50d482f1efd3c896ff9d8ab48bef38d8696` | **PASS** — same assertions; `747d5dc8951d79ded761c4db3897b561565845b1a2197a77a56f28962c4ba0eb` |
| App container, `admirald` and Fleet process recovery, `scripts/r67/r67-single-process-recovery.sh` | **PASS** — systemd recovered killed components, HTTP 200, one provision operation, clean deprovision; `5498ced4d3bd016c6b9748d4dff0df0223d0b63b4595826c3c89d12c5f5b5dc1` | **PASS** — same assertions; `c43b8ee448ebb05744cdac83dacfc8cf840b08a6d9942d9fa86f634717567abc` | **PASS** — same assertions; `c4cd5d3a8dd2d12b9c8d7ceeb0cafc8966aa1f62b1baa8013044fa44b8169737` | **PASS** — same assertions; `acaa526857a49afd2fe439f86de4d79f63dcd04a88f4adb9cd2155143c27f6cb` |

The table reports only the exact scenario executed. The authentication probes disabled TLS verification for the isolated auth-only requests; no mutation endpoint was called. Backup evidence used the local backend only; **S3/R2 was not tested**. The isolation sample remains partial: rootless Podman/pasta did not expose a target container IP, so direct cross-workload DB access was not probed. `podman inspect` reports child memory/CPU as zero because the effective limits are inherited from the pod cgroup; the checked pod ancestor held the configured small-tier values above.

## Reproduction helper checksums

The committed scripts are under [`../scripts/r67/`](../scripts/r67/). Their SHA-256 values at capture time are:

| Scenario | Helper | SHA-256 |
| --- | --- | --- |
| Failed declared service | `r67-single-failed-service.sh` | `9e9679bac2df037eaf59d8043d76e4cb32a721fc63a4f72b053c4acaa9612632` |
| Local backup/restore | `r67-single-backup-restore.sh` | `ab5233fab86ef83c3afdfc823ebe16ad61dfe5782fdcc40702a8d623fba50865` |
| Auth negatives | `r67-single-auth-negative.sh` | `9574050933cf3e335e5fd6cd8b9e0286dddc6aac3c612c27311169c1c14b0edc` |
| Same-host isolation | `r67-single-same-host-isolation.sh` | `75c7e31c531021bc24f59bb8aa6a3989491e70a8fc5efdc6c6aefb07c50e2d97` |
| Effective cgroup limits | `r67-single-cgroup-limits.sh` | `831eedcad380bcc54d19e3cba5fded42ec034dd646fd0b07c125ffafee6e8a32` |
| Concurrent same-key provision | `r67-single-concurrent-idempotency.sh` | `cf87a4ef653f4efaad912ef37f5429c5e39167b3a7e122f9133ab71b6e75df00` |
| Concurrent resize/deprovision | `r67-single-concurrent-update-delete.sh` | `018a770823a10b5c0567a59b9e4943305d554367526c737401fafb087a24c8e8` |
| Workload DB outage | `r67-single-db-service-outage.sh` | `489aa47f44fec21f99ada9190a15d0df6f15bc70d1b3e63153c154c1c5c19512` |
| User systemd-manager restart | `r67-single-user-systemd-restart.sh` | `23dc80a40ee52f59a4ec098fa8c524013153061928f25e16387bc57b97ecf89b` |
| App/daemon process recovery | `r67-single-process-recovery.sh` | `124b01ab98d16afddeecbe4f294a6396d47a0ddfbc9374ad8b3c58c2991f248d` |

## Preserved precondition/harness failures

The first Alma and CentOS isolation invocations occurred before worker metrics became fresh after cold boot. Admiral rejected them with `no_node_available_for_requested_tier` / `metrics_stale`; they created no instance and were excluded from the isolation results. The later uniquely keyed runs passed the limited isolation sample. Alma raw-log SHA-256: `ff92c96173dc2ef92fd5df5d651be896df0c069dc392483fabc00fc079c41674`; CentOS: `914cb56cf49cd1af7886dfef34b75d0b97c6c85f3e7536418fc488720f6cdece`.

## Limits and remaining R67 Single-Node work

These are named regression, integration and recovery probes on updated seeds, not a full cell. The validation has not established fresh-image dependency closure, public DNS/TLS, full configuration/secret lifecycle, cross-workload DB/network/storage denial, external S3/R2 backup, memory/disk exhaustion, disk-write interruption, callback/task crash windows, latency injection, or performance percentiles. The test set contains no sustained stress result. Do not infer absence of defects from these passes.
