# RC5 Release 62 — Rocky Linux 10.2 Single-Node invalidation

Date: 2026-10-23 UTC  
Result: **FAIL — candidate invalidated; contributes 0/8 cells.**

## Candidate identity

Release 62 was built from root commit `df279377c1e558ad5256c6457f3795665f1963de` after root CI run [39878912750](https://github.com/admiral-project/admiral/actions/runs/39878912750) passed. At build time, component refs were admirald `9b8f1299fe43d0540442b4bc05cdbe0c5f4611aa`, Fleet `0c805d6293bfb11fd4f015f1b0ccff520481e627`, CLI `49cf2428c064434c65af9a14f96975c1bb2db637`, Flagship `b7325bbc71fc474a521496e593b2967e4d555ac1`, and Harbor `dd39e9a74bf658ecf6fd6e9f8bd30b2ddf82d7db`.

The six locally built RPMs were installed on a fresh Rocky Linux 10.2 x86_64 guest (`adm-r62-rocky-single`, 2 vCPU, 2 GiB RAM). The build ran `make rpm-admiral RPMFLAGS_EXTRA=--nodeps`: package `%check` ran, but builder-side BuildRequires dependency resolution was bypassed. This limitation is material; R62 is not evidence of a clean dependency-closed build.

## Failure reproduced

After installation and a successful targeted user-manager restart check, the test workload was provisioned and the guest was rebooted twice. Both reboots produced API responses claiming `running/healthy/available` based on pre-reboot health observations before a fresh post-boot health report had arrived. The second reproduction captured:

- Boot ID changed from `bcc4d105-74cf-4001-a560-5e98d0ec738f` to `7fdf43a3-11eb-4f46-9101-a5732f3445a8`.
- Fleet started at 01:13:44Z. At 01:13:49Z, the API still returned `running/healthy/available` while the database health readiness check was false; `last_health_checked_at` was 01:13:04Z, before reboot.
- The workload containers had just started and PostgreSQL was not accepting connections. The recorded health timestamp demonstrates that the response used stale pre-boot health rather than a post-boot observation.
- Reboot one showed the same false availability at 01:08:40Z, shortly after Fleet startup, while only two of three workload containers were up.

The tested release therefore fails the reboot availability criterion. The issue is tracked by [#256](https://github.com/admiral-project/admiral/issues/256); no duplicate issue was opened. The source currently permits a 60-second-old healthy runtime observation. Fleet waits 10 seconds before its first heartbeat after startup and reports health on a five-second cadence, so an old observation can remain eligible during the reboot recovery window. This is the confirmed mechanism for the observed stale-availability response; runtime/database readiness was also still incomplete in the second snapshot.

## Scoped checks and candidate rule

On this exact R62 Rocky Single-Node candidate, targeted probes for the #259 user-systemd-manager restart, #260 PostgreSQL service outage, process recovery, duplicate concurrent provisioning, local database backup/restore, same-host workload isolation, concurrent update/delete, and cgroup limits produced the outcomes recorded in the local R62 logs. These were scoped diagnostics, not a complete Single-Node matrix cell. Direct workload-DB-IP reachability was NOT TESTED because the probe had no container IP. All R62 observations are invalidated for matrix credit by the reboot failure: **0/8** remains.

The test workloads were explicitly deprovisioned after each probe; both reboot failure cleanups completed and left no matching Podman resources. The VM was retained for diagnosis. Raw logs and archives remain in the local ignored directory `packaging/build/validation/rc5-r62/` and are not committed because they contain environment-specific runtime data. Reproducibility scripts are committed under `scripts/r62/`.

Evidence integrity hashes:

| Artifact | SHA-256 |
| --- | --- |
| First reboot failure archive | `648eff05e5f13409270abac58c8c48efe0262818aafd388e8e4124896689d5cd` |
| Second reboot failure archive | `8cac47c3ea05b122c9a7f68dc64337116cc963e1f703640b4228a9dfd753e10a` |
| Second reboot timeline log | `c8485bd2b76a14c6fcb36e1c1e5bb8f8e64e8efe23f63ccbd65f75850d7d9e5` |
| First Fleet boot journal | `d841cf2dff06a22dbd189bd74a3a468fc3c25dd1788141dd86e0640a65a5872c` |
| Second Fleet boot journal | `7ca541158cbfe0836d6ce257f40cb625979b601129256b0d83c8d527c7050472` |
| First cleanup record | `45951440562d4d0cd82cd351372136403e4bfb4f11b630db40ddc967e5f1d868` |
| Second cleanup record | `11a1c0a02fa0c0e393093f05cd0bd763f8537bffec7b67cb271a91e675f6eeb8` |

## Follow-up

The next candidate must contain the fix for #256, use fresh guest overlays, and repeat the host-reboot scenario before any result is credited. R62 also exposed a build-process limitation: `--nodeps` skipped builder dependency resolution. A future candidate build must use a local repository with its pinned Python RPM dependencies available and resolve BuildRequires normally; this is separate from the runtime defect and must be reported independently.
