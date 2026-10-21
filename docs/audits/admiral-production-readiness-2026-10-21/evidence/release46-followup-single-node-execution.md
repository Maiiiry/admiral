# Release 46 follow-up Single-Node execution

Audit: `ADM-AUDIT-2026-10-21`<br>
Candidate: six exact `0.0.1rc5-46.el10` RPMs, root package-preparation commit `7223561646b60d3c24e8bfb257d544a5eb6dea04`; component pins and RPM digests are in `release46-candidate.md` and `release46-rpm-sha256.txt`.<br>
Scope: fresh Single-Node install and one `e2e-whoami` provision/replay/HTTP/deprovision probe on AlmaLinux 10, CentOS Stream 10 and Fedora Rawhide. This is targeted evidence only. The current three-OS matrix remains **0/6**.

## Test record

| Test ID | Guest / configuration | Result | Evidence |
| --- | --- | --- | --- |
| ALMA-R46-SN-INSTALL-001 | `adm-r46-alma-single`, AlmaLinux 10.2 x86_64, 2 vCPU / 2 GiB, fresh updated-seed overlay | PASS: all six Release 46 packages installed; secure installer recap `ok=229 changed=97 failed=0 unreachable=0`; Harbor API check succeeded | restricted install log and baseline hashes in `release46-followup-single-probe-log-sha256.txt` |
| ALMA-R46-SN-E2E-001 | Same guest | PASS: operation succeeded, instance reached running/healthy, HTTP 200, same-key retry returned the original operation/instance, deprovision succeeded, no matching runtime resources remained | same manifest; operation IDs below |
| CENTOS-R46-SN-INSTALL-001 | `adm-r46-centos-single`, CentOS Stream 10 x86_64, 2 vCPU / 2 GiB, fresh updated-seed overlay | PASS: all six Release 46 packages installed; secure installer recap `ok=228 changed=97 failed=0 unreachable=0`; Harbor API check succeeded | restricted install log and baseline hashes in `release46-followup-single-probe-log-sha256.txt` |
| CENTOS-R46-SN-E2E-001 | Same guest | PASS: operation succeeded, instance reached running/healthy, HTTP 200, same-key retry returned the original operation/instance, deprovision succeeded, no matching runtime resources remained | same manifest; operation IDs below |
| FEDORA-R46-SN-E2E-002 | `adm-r46-fedora-single`, Fedora Rawhide 46 x86_64, 2 vCPU / 2 GiB, fresh updated-seed overlay; booted after the earlier targeted reboot regression | PASS: `admiralctl status` healthy; provision succeeded, instance reached running/healthy, actual Podman port returned HTTP 200, same-key retry returned the original operation/instance, and deprovision removed matching resources | same manifest; operation IDs below |

All three guests reported SELinux `Enforcing` and the exact six candidate NEVRAs. Commands used `examples/apps/e2e-whoami.yaml`, then:

```bash
sudo admiralctl apps apply --file /tmp/audit-e2e-whoami.yaml
sudo admiralctl instances provision --app e2e-whoami --tier small \
  --customer <unique-audit-customer> --idempotency-key <stable-audit-key> \
  --wait --wait-timeout 10m --quiet --output json
sudo admiralctl instances deprovision <instance_id> --force \
  --wait --wait-timeout 10m --output json
```

AlmaLinux provision operation `op_52a0114f13e309fb`, task `task_0a494e01151e3863`, instance `inst_4c3faa8832cc1b01`, completed from `23:22:44.831Z` to `23:25:02.920Z` (138.1 seconds). The first diagnostic snapshot found the task still queued and the instance temporarily `failed/unhealthy` because its PostgreSQL container had not started. The database unit later started; the task callback and operation succeeded, the instance converged to `running/healthy`, and the app returned HTTP 200. Repeating the same explicit idempotency key returned the same operation and instance. Deprovision operation `op_6a862f79a36716c2` succeeded; final checks found no matching containers, volumes, Quadlets or user units.

CentOS Stream provision operation `op_5823c7b6e12548c0`, task `task_6af19a0c795c2dce`, instance `inst_9b7549fc5462cbde`, completed from `23:26:26.293Z` to `23:28:01.179Z` (94.9 seconds). The in-progress snapshot likewise showed a temporary unhealthy/failed state before PostgreSQL startup; final state was `running/healthy` and HTTP returned 200. Replaying the key returned the same operation and instance. Deprovision operation `op_fa565727cfc461a7` succeeded; no matching containers, volumes, Quadlets or user units remained.

Fedora Rawhide provision operation `op_50ffa358fdaff361`, task `task_f581428554f9485a`, instance `inst_c2fb5357f01f8c28`, completed from `23:31:12.191Z` to `23:31:23.462Z` (11.3 seconds). Podman reported the app mapping `80/tcp -> 127.0.0.1:40001`; that endpoint returned HTTP 200. An initial diagnostic request to assumed port 40000 was refused; the observed port mapping showed that 40000 was the wrong target, so this was a probe error, not a product failure. The same-key replay returned the original operation and instance. Deprovision operation `op_f24635f8b44460e3` succeeded and removed all matching runtime resources.

## Environment observations and limits

The AlmaLinux and CentOS Stream probes used cold PostgreSQL images. Their initial `unhealthy`/`technical_status=failed` snapshots happened while provision remained active and the DB container was unavailable. Both final operation results were `succeeded`, and both instances converged to healthy after the DB units started. This is a measured transient state, not a failed terminal provision. Repeat under controlled slow-pull and warm-image conditions before deciding whether the intermediate state needs a finding.

The first CentOS Stream installer attempt stopped before installing Admiral packages because EPEL mirror access failed (TLS issuer, timeout and checksum errors). The first failed log is preserved. A targeted EPEL metadata refresh succeeded and the fresh install was retried as a separate run; that retry passed. This external repository failure is not counted as a product failure.

The probes do not exercise concurrent requests, same-customer races, app updates, persistence across reboot, backup/restore, tenant isolation, resource exhaustion, Podman/systemd fault injection, public DNS/TLS routing, or performance percentiles. They do not complete any Single-Node cell. In-scope Release 46 Multi-Node remains untested, so matrix completion remains **0/6**.

Unsanitized logs and baselines are ignored local artifacts under `packaging/build/validation/rc5-r46/`, all mode `0600`. Their SHA-256 values are recorded in `release46-followup-single-probe-log-sha256.txt`; no secrets or raw logs are committed.
