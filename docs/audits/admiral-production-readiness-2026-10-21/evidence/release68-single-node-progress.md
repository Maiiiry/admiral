# RC5 Release 68 Single-Node scoped runtime results

Audit: `ADM-AUDIT-2026-10-21`
Candidate: [RC5 Release 68](release68-candidate.md), root package source `4077c4ddb9d233682961d36c3570c63e70eb6405`; exact RPM hashes are in the linked manifests.
Status: **targeted scenarios executed; no Single-Node cell is complete; matrix remains 0/8.**

## Environment and evidence

| OS | Guest | Runtime image | Address | Candidate packages |
|---|---|---|---|---|
| Fedora Rawhide | `adm-r68-fedora-single` | Fedora Rawhide 46 x86_64, 2 vCPU / 2 GiB | `192.168.122.193` | six `.fc46` Release 68 RPMs |
| Rocky Linux 10 | `adm-r68-rocky-single` | Rocky Linux 10.2 x86_64, 2 vCPU / 2 GiB | `192.168.122.194` | six `.el10` Release 68 RPMs |
| AlmaLinux 10 | `adm-r68-alma-single` | AlmaLinux 10.2 x86_64, 2 vCPU / 2 GiB | `192.168.122.195` | six `.el10` Release 68 RPMs |
| CentOS Stream 10 | `adm-r68-centos-single` | CentOS Stream 10 x86_64, 2 vCPU / 2 GiB | `192.168.122.196` | six `.el10` Release 68 RPMs |

Each VM was a new disposable overlay backed by the verified, updated R66 seed; no earlier Admiral database or workload state was carried into the guest. Installations used the exact distribution-native, signed R68 repository in secure mode. The clean-install helper skipped repeating OS/security updates only because the parent seeds had already been updated and verified; it did not bypass package dependencies. Install recaps had zero unreachable or failed tasks. Postchecks found the expected package set, active required services, healthy node registration, SELinux enforcing, rootless Podman on workload nodes, and only the documented setup-rendered RPM configuration-file differences.

Raw output remains in the local ignored mode-0600 directory `packaging/build/validation/rc5-r68/`. [`release68-single-node-log-sha256.txt`](release68-single-node-log-sha256.txt) records SHA-256 values for each selected log. Procedures are in [`scripts/r68/`](../scripts/r68/); no raw log is copied into Git because the full installer and service output has not passed a complete secret-redaction review.

## Executed scenarios

The following are scoped scenario results, not cell-level passes:

| Scenario | Fedora | Rocky | AlmaLinux | CentOS Stream | Observed result |
|---|---|---|---|---|---|
| Fresh install and postcheck | PASS | PASS | PASS | PASS | Exact native six-RPM set installed; secure setup and service/API readiness verified. |
| Workload lifecycle | PASS | PASS | PASS | PASS | Apply/provision, healthy state, local HTTP 200, SQL marker, deprovision and resource cleanup. |
| Local database backup/restore | PASS | PASS | PASS | PASS | Restore operation completed and data marker/checksum matched; backup tombstone/deletion behavior checked where recorded. This is local backup evidence, not S3 or external-storage evidence. |
| Authentication negatives | PASS | PASS | PASS | PASS | Four administrative/Fleet API paths returned 401 without credentials and with a synthetic invalid token (rate-limit 429 is accepted by the probe but was not needed for these observed requests). TLS verification was disabled only for this authentication-only probe. |
| Effective cgroup tier limits | PASS | PASS | PASS | PASS | Runtime cgroup ancestors enforced the configured 512 MiB memory and one-CPU limits. |
| Concurrent same-key provision | PASS | PASS | PASS | PASS | Three concurrent requests converged on one operation/instance; cleanup completed. |
| Update versus delete | PASS | PASS | PASS | PASS | Resize and deprovision both reached terminal success; final instance state was deprovisioned. Rocky's deprovision queued for about 100 seconds before success; no response-time threshold was predeclared. |
| Workload DB service outage/recovery | PASS | PASS | PASS | PASS | Availability was withdrawn while the DB service was stopped; SQL marker and workload recovered after restart; cleanup succeeded. |
| Declared service fails readiness | PASS | PASS | PASS | PASS | Provision became terminal `failed`, instance was unavailable, and deprovision removed the failed workload. Rocky's corrected run omitted explicit node placement and is the Single-Node result. |
| Admiral/Fleet/workload process recovery | PASS | PASS | PASS | PASS | Unexpected process termination was followed by systemd/Quadlet recovery; operation count and data marker were checked. |
| Rootless user systemd manager restart | PASS | PASS | PASS | PASS | Workload and API returned to healthy/available with marker preserved. |
| Real host reboot and recovery | PASS | PASS | PASS | PASS | Boot ID changed, workload data marker persisted, API and runtime converged. Fedora showed a transient unhealthy/unavailable interval while containers recovered; no false healthy sample was counted. |
| Same-host workload isolation | PARTIAL | PARTIAL | PARTIAL | PARTIAL | Distinct PID/network namespaces, separate DB volumes and generated secret values, no privileged containers or Podman socket mounts, and denial to other workloads' host-published app ports were observed. Rootless Podman did not expose a direct DB container IP, so direct cross-workload DB-IP reachability remains **NOT TESTED**. These samples cannot prove full isolation. |

Rerunning the installer on the AlmaLinux and CentOS guests produced Ansible `changed` tasks and is not counted as an idempotency pass. The first and second invocations did not preserve the same node identity input; the changed task set included generated/deployed SSH identity and firewall/nftables operations. A controlled same-input installer rerun and before/after identity/firewall comparison remain **NOT TESTED**. This is kept separate from the same-key workload idempotency result above.

## Remaining Single-Node checks

The following still prevent a complete cell:

- Full cross-workload network probing to the peer database IP; unavailable in the rootless Podman topology used here.
- Complete configuration and secret create/update/delete lifecycle, including checks against every relevant process, host path and log surface.
- Podman command failure during create/update/delete, cleanup failure followed by retry, interrupted writes/deployments, and orphan reconciliation on the R68 candidate.
- Bounded memory and disk exhaustion, increasing stress/concurrency load, and measured latency/resource baselines with sample counts and p50/p95/p99 where meaningful.
- Public DNS/TLS routing and production exposure checks; the isolated lab has no production domain or public endpoint.
- External object-storage (S3-compatible) backup/restore and volume-level backup/restore. Only the configured local database backup path was exercised.
- Controlled same-input installer rerun/idempotency; the prior rerun pair had mismatched node identity input and is not evidence.
- A full requirement-by-requirement catalog run on a clean guest with every check tied to the unchanged R68 candidate.

No new source/RPM defect requiring a candidate change was confirmed by the named R68 Single-Node scenarios. That observation is not proof that no defect exists. Any new required source or package fix invalidates affected R68 results. **Single-Node remains NOT VALIDATED for production; all four Single-Node cells are incomplete and the overall matrix is 0/8.**
