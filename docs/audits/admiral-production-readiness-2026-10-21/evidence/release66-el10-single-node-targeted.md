# Release 66 EL10 Single-Node targeted validation

Audit: `ADM-AUDIT-2026-10-21`  
Candidate: RC5 Release 66, root package-preparation commit `c5365da267eca6f1f5246c60a26c7875f07a5ffa`  
Result: **PARTIAL — named scenarios executed on AlmaLinux 10.2 and CentOS Stream 10; neither Single-Node cell is complete. Overall matrix remains 0/8.**

The two guests were freshly cloned from the updated R66 seeds, had 2 vCPU/2 GiB RAM, SELinux enforcing, and installed all six exact `0.0.1rc5-66.el10` Admiral RPMs through the packaged secure Single-Node installation path.

## Results

| Test ID | Scenario | AlmaLinux 10.2 | CentOS Stream 10 |
| --- | --- | --- | --- |
| `R66-SN-EL10-INSTALL-01` | Install exact candidate and initialize secure Single-Node services | Installer recap `ok=231 changed=97 unreachable=0 failed=0`; exact six R66 NEVRAs installed. | Installer recap `ok=230 changed=97 unreachable=0 failed=0`; exact six R66 NEVRAs installed. |
| `R66-SN-EL10-IDEMP-01` | Repeat provision with same idempotency key and request; then deprovision | First and replay returned operation `op_f3551301587ea31c` and instance `inst_ed1b46aed64efed8`; deprovision succeeded and final inventory was empty. | First and replay returned operation `op_7c1810d4894e5f15` and instance `inst_1e2330f93abb9e40`; deprovision succeeded and final inventory was empty. |
| `R66-SN-EL10-REBOOT-01` | Reboot host with a running workload; verify boot ID, database marker, HTTP and cleanup | Boot ID changed. Initial polls were `running/healthy/unavailable` while no workload containers were up, then while DB was ready; the third poll reported available. HTTP returned 200, SQL marker `r65-reboot-persisted` remained, and deprovision succeeded. | Boot ID changed. Polls briefly reported unavailable and then stopped/unavailable although all three containers and PostgreSQL were ready; the next poll reported available. HTTP returned 200, marker `r65-reboot-persisted` remained, and deprovision succeeded. |
| `R66-SN-EL10-FAILED-SVC-01` | Force declared DB service to exit immediately (#227) | Provision operation `op_007028ec570b7c22` failed; instance was `failed/stopped/unavailable`. Deprovision `op_bfc19616a545dc59` succeeded; final state was deprovisioned/unavailable with no matching resources. | Provision operation `op_c6a0d4721971290a` failed; instance was `failed/stopped/unavailable`. Deprovision `op_075c51553965b2bb` succeeded; final state was deprovisioned/unavailable with no matching resources. |
| `R66-SN-EL10-BACKUP-01` | Local PostgreSQL backup, mutate/restore and verify the original SQL marker | Restore while running was rejected with HTTP 409. Pause/restore/resume completed and the original marker was read back; test backup and instance were removed. | Restore while running was rejected with HTTP 409. Pause/restore/resume completed and the original marker was read back; test backup and instance were removed. |
| `R66-SN-EL10-ISOLATION-SAMPLE-01` | Inspect two co-resident workloads and attempt host-alias cross-workload app access | Tested host-alias app port was denied; container metadata recorded separate workload instances and no Podman socket mount in DB containers. Direct database-address isolation and secret-read negatives are not established. | Tested host-alias app port was denied; container metadata recorded separate workload instances and no Podman socket mount in DB containers. Direct database-address isolation and secret-read negatives are not established. |

The host-reboot raw transcripts were accidentally labeled `R65` internally by the local harness, even though they ran on the same two isolated guests immediately after the logs proving installation of all six R66 NEVRAs. The label is a harness defect; the installation records and node IDs tie these runtime captures to the R66 guests. The SQL marker name also retained the string `r65`. Neither label was used as candidate identity. Raw files are unchanged and preserved.

The first general lifecycle probe's `su`-based Podman inspection failed because the harness supplied no interactive password; this is not a product failure. The failed attempt is preserved. The later host-reboot test provided live HTTP, DB marker and cleanup checks. On AlmaLinux that earlier probe also observed a temporary unavailable state while PostgreSQL was initializing; it recovered on subsequent polling. Broad cold-start convergence remains open for review under #236.

## Evidence integrity

Raw mode-0600 transcripts remain in ignored `packaging/build/validation/rc5-r66/` on the lab host. SHA-256:

| Capture | SHA-256 |
| --- | --- |
| `alma-single-install.log` | `be4ef14a80f8c1446e35a4acfee1719fac5bf26165066991c6529cfcea96b2a1` |
| `centos-single-install.log` | `1bde54120c8b390e9538ca64dd5203f66077be4fb22734f0e3c62a6a694aba25` |
| `alma-single-e2e.log` | `8411971f9e9969e6edfe51b86f8345984075b386a2c1c419b18e98018fc5bd9e` |
| `centos-single-e2e.log` | `8a512343bfcb091007d18bb3b13a80d615e31e2252c46d889cc1380aa19ba841` |
| `alma-single-host-reboot.log` | `04a444b301ff25457e80ce6c775129a3775cb76f16761e2487afc97bd4035c8c` |
| `centos-single-host-reboot.log` | `d9010af236209b174177f5a0d7fc3167a3fff1c823677171c230adc5eacbf7b3` |
| `alma-single-failed-service.log` | `2a74d7ba6f0a0b1dd971670ca71ade75e4f3036c136f49b3343183dbec27bc75` |
| `centos-single-failed-service.log` | `30f1807a2b0dda0a0f85f5c1eb13fa2a1982801a15d8d7efb1730b2a2fd44366` |
| `alma-single-backup-restore.log` | `6e2df4e6087542753107fe47ea2071142d3876c71fbe2524784baa9eec20a075` |
| `centos-single-backup-restore.log` | `1335d881694aedadcadd70800519f5fe87168f778b3c81e51941f2f68171d772` |
| `alma-single-isolation.log` | `bfcc4e243e0acc32b93cfad4b35c8ad1317481b54e0cabc505f67c8cc69d18b2` |
| `centos-single-isolation.log` | `b000e1de62d19b1eec7f9176efbfa48893ff8c9b1cfbc8969028a7e5bad46e65` |

These records are targeted evidence, not full-cell passes. External S3/volume restore, public DNS/TLS, comprehensive auth and isolation negatives, concurrent conflicting operations, resource exhaustion, broad fault injection and performance remain untested.
