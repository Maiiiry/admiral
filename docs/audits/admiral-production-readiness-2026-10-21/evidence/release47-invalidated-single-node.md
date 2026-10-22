# Release 47 diagnostic Single-Node execution — candidate invalidated

Audit ID: `ADM-AUDIT-2026-10-21`.<br>
Candidate: root package-preparation commit `45b7b591b013c957ceeae2fcfd3849bbaeb03ef4`, six `0.0.1rc5-47.el10` RPMs; exact SHAs and RPM hashes are in [`release47-candidate.md`](release47-candidate.md) and [`release47-rpm-sha256.txt`](release47-rpm-sha256.txt).<br>
Scope: fresh Fedora Rawhide and Rocky Linux 10 Single-Node diagnostic runs only. Both installations and scoped lifecycle probes completed, but reboot status observations exposed issue [#237](https://github.com/admiral-project/admiral/issues/237). Under the audit rule, the candidate is invalidated and **none of these results count toward a matrix cell**. The matrix remains 0/8.

## Test record

| Test ID | Guest / configuration | Result | Evidence |
| --- | --- | --- | --- |
| FEDORA-R47-SN-INSTALL-001 | `adm-r47-fedora-single`, Fedora Rawhide 46 x86_64, 2 vCPU / 2 GiB, updated-seed overlay, isolated libvirt NAT | PASS for install subset: all six exact R47 RPMs; secure installer recap `ok=238 changed=99 failed=0 unreachable=0`; `admiralctl status` API online/control plane healthy; no failed system units; SELinux Enforcing | restricted raw log and before/after baselines listed below |
| FEDORA-R47-SN-E2E-001 | Same guest; `e2e-whoami`, cold app and PostgreSQL containers | PASS for scoped provision, idempotency replay, and HTTP request only: operation `op_f75f4ee644e1fc89` succeeded in 43.54 s; replay with the same explicit key returned the same operation and instance `inst_c68f9c2ebbb10ccf`; app returned HTTP 200 in 17 ms. Deprovision and complete cleanup were not tested. | restricted local files listed below |
| FEDORA-R47-SN-REBOOT-001 | Same workload; SQL marker inserted before guest reboot | FAIL for current-state reporting: first SSH snapshot returned `running/healthy/available`, although only infra existed and DB query failed; later API reported stopped while all containers were back; converged to `running/healthy` about 63 s after first reconnect. SQL marker persisted and HTTP returned 200. Tracked as #237. | `fedora-single-after-reboot.txt`, `fedora-single-after-reboot-convergence.txt`, `fedora-single-recovery-final.txt` |
| ROCKY-R47-SN-INSTALL-001 | `adm-r47-rocky-single`, Rocky Linux 10.2 x86_64, 2 vCPU / 2 GiB, updated-seed overlay, isolated libvirt NAT | PASS for install subset: all six exact R47 RPMs; secure installer recap `ok=232 changed=97 failed=0 unreachable=0`; API online/control plane healthy; no failed system units; SELinux Enforcing; `python3-pyOpenSSL-25.0.0-1.el10_1` present | restricted raw log and before/after baselines listed below |
| ROCKY-R47-SN-E2E-001 | Same guest; `e2e-whoami`, cold app and PostgreSQL containers | PASS for scoped provision: operation `op_e3572b83f54a77ac` succeeded in 30.06 s | `rocky-single-provision-first.json` |
| ROCKY-R47-SN-REBOOT-001 | Same workload; SQL marker inserted before guest reboot | FAIL for current-state reporting: first SSH snapshot returned `running/healthy/available`, while infra was `Up`, app was `Created`, and DB was absent; DB query failed. By the later snapshot all containers and marker were present, HTTP returned 200 and API was healthy. Tracked as #237. | `rocky-single-after-reboot.txt`, `rocky-single-after-reboot-convergence.txt` |

The `effective_availability` value was derived from node state only. `last_health_checked_at` was 68–71 seconds old on the initial post-reboot snapshots, but the API still reported `available`. Fedora's fresh callback then reported `stopped`; the runtime recovered before the following healthy report. The marker remained on both guests. This is a current-state accuracy defect, not evidence of data loss.

Harness note: the first combined Fedora replay/HTTP command stopped at a local `awk` quoting error while extracting Podman's host port, before issuing an HTTP request. The recorded idempotency replay itself succeeded; a separate corrected port extraction then returned HTTP 200. The malformed probe is not counted as a product failure.

## Candidate invalidation and follow-up

Finding #237 is severity MEDIUM. The fix in `admirald` derives availability from a fresh workload observation: unknown before the first health report, unavailable for nonhealthy observations or when the observation is older than two 30-second Fleet intervals, and available after a fresh healthy report. It preserves the last observed health fields and timestamp. Regression coverage checks unknown, stale healthy, fresh stopped, and recovery transitions.

The local fix passed the full `admirald` Go test suite, `go vet`, `go build`, and the focused regression 10/10, then was pushed as `admirald` commit `d50523f7a75b0a1606c761423de9d1cdc844425e`. Release 47 remains invalid; the next candidate must be rebuilt after GitHub CI is green and all six Admiral RPM `Release` fields are incremented together.

Other tracked observations: #234 records Ansible fact-injection deprecation warnings; #235 records that Rocky's installer applied a newer kernel and generated normal and rescue initramfs despite the updated seed (installer elapsed 16m02s); #236 records transient unhealthy status during cold DB startup. None of these changes the classification of #237.

## Restricted local evidence

Unsanitized logs and snapshots remain outside Git under `packaging/build/validation/rc5-r47/`, all mode `0600`. SHA-256 values:

| File | SHA-256 |
| --- | --- |
| `fedora-single-install.log` | `2b1390f5b2a0dc7b85e5d3466fdce7a29aa03feec67399c15ec30d55c760739b` |
| `fedora-single-before-install-baseline.txt` | `f91c722c7c95248ab1d6738eb9ad947aacc2d97af824f5fab0bbcb2e3250036b` |
| `fedora-single-after-install-baseline.txt` | `4c459d7dc5eee89a87731e7711401219e742b5f342d6599acf1ed0be1ab8020d` |
| `fedora-single-after-reboot.txt` | `22079438aba5d42ec5cce99a892831883e3a79f56fc1cd9d9c1b27b1cc7fac08` |
| `fedora-single-after-reboot-convergence.txt` | `37267f91ba7b1152aef3b6b27611d7fa2fca4ccf01d7459ce6f783550638d263` |
| `fedora-single-recovery-final.txt` | `64288245a666f3a22cb5a2557bbdc55ea8f1df88be4fd3c01e4c92d680749be0` |
| `fedora-single-provision-first.json` | `c2ad34391870a5c9b5eb0325adfa2cc71f9542a6c2efb2721072b35aa752ffd6` |
| `fedora-single-replay-http.txt` | `3f0e92c2f8f4a94326c3a685fc2a797edde82de508727a07f027a70bdbda1c65` |
| `fedora-single-http-check.txt` | `4d405a96e9f830c1d262680b55dbdb7c9db36d0c86f5eebb0f47a650d13c81b8` |
| `rocky-single-install.log` | `5065c44704489999f5d69b6720f6e64c32b49a3dd1b035a52766c84300a93f83` |
| `rocky-single-before-install-baseline.txt` | `657f09b5f9ed78648884c35c79c6ff440402aeb0c7b576478ad5f41ddefa0522` |
| `rocky-single-after-install-baseline.txt` | `06874020337112c8c0ff2d4f4dcef5cbc74f925eadfba093106f780680b9a963` |
| `rocky-single-provision-first.json` | `1501b5a763e3673c27d7f9a199678633760688b077c27cb273e351a0ca21753a` |
| `rocky-single-after-reboot.txt` | `2891fb21aa3a12a7c0b0a7909e1c00d34f0d1b7a663117ca036c02b322385e46` |
| `rocky-single-after-reboot-convergence.txt` | `082aa306ca64e74266dc841209b54ed14ff5044544a741e14bf353de894bdcda` |

These are diagnostic execution records only. Neither Single-Node cell is complete; concurrency, update/delete races, backup/restore, isolation negatives, failure injection, resource pressure and the complete cleanup assertions remain untested on Release 47.
