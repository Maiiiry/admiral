# R67 EL10 Multi-Node local PostgreSQL backup and restore

Audit ID: `ADM-AUDIT-2026-10-21`

Candidate: Admiral RC5 Release 67, source commit `833d15aa4f8e96be30d28dad169b9d06a4d9894d`

Result: **PASS for local database backup/restore scenarios only; neither Multi-Node cell is complete**

## Procedure

On each configured three-guest topology, the run verified the Release 67 `.el10` NEVRAs on the hub and workers, applied the `e2e-backup` fixture, and placed one instance on a real worker. It inserted a unique SQL marker and captured a successful database backup with recorded SHA-256 checksum. Restore while the app was running was attempted and rejected with HTTP 409, preserving the pause precondition. The test then mutated the marker, paused the app, restored with checksum verification, resumed the app, waited for healthy/available state, verified the original marker and HTTP 200, deleted the backup, deprovisioned the workload, and checked the worker's containers, pods, volumes, units and files for residue.

## AlmaLinux 10.2 x86_64 — W1

- Test ID: `R67-ALMA-MN-LOCAL-BACKUP-RESTORE`.
- Hub/W1: `adm-r67-alma-mn-hub` / `adm-r67-alma-mn-w1`; WireGuard endpoint `10.99.0.2:40004`.
- Instance `inst_b0d4f45dd2786752`; backup `bk_164b8a7e73581fe3`; deprovision operation `op_92030d450073559b`.
- Backup record: `succeeded`, database service `db`, local backend, 754 bytes, checksum `0c165e51c9738c8a5e575934cbaee20cc70b8368dd336cfbcffd4b33e43646c0`.
- Before backup and after checksum-verified restore, SQL returned the original marker `r67-20261023-alma-mn-r67bkp01-inst_b0d4f45dd2786752`; the intervening mutation returned `mutated-after-backup`.
- HTTP was 200 before and after restore. Restore while running returned HTTP 409. Deprovision succeeded; final inventory reported no containers, pods, volumes, units or files.
- Probe window: preflight at `2026-10-23T21:12:43Z`; the script started at `21:12:50Z` and recorded completion at `21:13:40Z`.
- Reproducer: [`../scripts/r67/r67-alma-multinode-backup-restore.sh`](../scripts/r67/r67-alma-multinode-backup-restore.sh). Restricted raw manifest SHA-256: `4052f218a68a1d0ad732a0231189ab113ca630cb91932caa90fcb75c277e8734`; preflight SHA-256: `30925152b60540d287ed5188e64f798e23aee33f4252a23b3db5038a7b1bf528`; script SHA-256: `0385c448e4cb10d80efbb35582f419b56a735ca58e6424c3f328356a9665ffec`.

## CentOS Stream 10 x86_64 — W2

- Test ID: `R67-CENTOS-MN-LOCAL-BACKUP-RESTORE`.
- Hub/W2: `adm-r67-centos-mn-hub` / `adm-r67-centos-mn-w2`; WireGuard endpoint `10.99.0.3:40005`.
- Instance `inst_cbc76ee931b03dca`; backup `bk_6d8570152682feab`; deprovision operation `op_d1882b3dd89eb92d`.
- Backup record: `succeeded`, database service `db`, local backend, 759 bytes, checksum `e04b9c1389ef3df6ecaa0fb4cfe29bb172e5a3ded31b907c0b2872fa442b6975`.
- Before backup and after checksum-verified restore, SQL returned the original marker `r67-20261023-centos-mn-r67bkp01-inst_cbc76ee931b03dca`; the intervening mutation returned `mutated-after-backup`.
- HTTP was 200 before and after restore. Restore while running returned HTTP 409. Deprovision succeeded; final inventory reported no containers, pods, volumes, units or files.
- Probe interval: `2026-10-23T21:15:08Z` through `21:16:10Z`.
- Reproducer: [`../scripts/r67/r67-centos-multinode-backup-restore.sh`](../scripts/r67/r67-centos-multinode-backup-restore.sh). Restricted raw manifest SHA-256: `829e535fe42b8c6f93d928bebe092ac65925d1d9f94202c5fea0bd3e0df03674`; preflight SHA-256: `9a5343b1d1aadfa799d410c469c5e6365ad2505c6a36e3858c0beb26773668a3`; script SHA-256: `7ce9c2476c69ba1e2812c71207e368fc5b24951588a890eaeac98b1766cd86d9`.

## Limits

These tests validate Admiral's local PostgreSQL backup/restore flow and checksum verification on the exact R67 candidate. They do not test S3/R2, off-node storage, volume backups, Harbor uploads, corruption injection, interrupted writes, or restore under node loss. The raw capture directories under `packaging/build/validation/rc5-r67/` are ignored and mode `0700`; their manifests and files are mode `0600`. The scenarios are individually scoped and do not complete either OS cell. Overall matrix: **0/8**.
