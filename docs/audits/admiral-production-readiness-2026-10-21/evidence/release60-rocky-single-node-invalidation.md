# Release 60 Rocky Linux Single-Node execution

Audit ID: `ADM-AUDIT-2026-10-21`  
Candidate: Admiral RC5 Release 60, x86_64  
Guest: fresh Rocky Linux 10.2 overlay `adm-r60-rocky-single`, 2 vCPU / 2 GiB  
Root source commit: `1ee26549bf92181f1bd7d3b6b143f42280e524eb`  
`admirald`: `9b8f1299fe43d0540442b4bc05cdbe0c5f4611aa`  
`admiral-fleet`: `79a62914b17b4535fdbd436388f6f7a8c9936a72`  
`admiralctl`: `49cf2428c064434c65af9a14f96975c1bb2db637`  
`admiral-flagship`: `b7325bbc71fc474a521496e593b2967e4d555ac1`  
`admiral-harbor`: `dd39e9a74bf658ecf6fd6e9f8bd30b2ddf82d7db`  
`admiral-common` source archive: `f7118329c23a75ef36b0cd6067f30a82617d9ac9`

Release 60 is invalidated by the user systemd manager restart failure below. Its targeted results are retained for diagnosis and do not count as a passing matrix cell. Matrix completion remains 0/8.

## Candidate identity

The six exact Admiral RPMs installed in the guest were. The build used `RPMFLAGS_EXTRA=--nodeps`, so it bypassed builder-side BuildRequires resolution; package `%check` steps still ran. This does not establish a clean COPR dependency build.

| Package | NEVRA | SHA-256 |
| --- | --- | --- |
| admiral-common | `admiral-common-0.0.1rc5-60.el10.noarch` | `632f7d0b31de9c5cdf223d48b135624deaadbd7b83daf775c1a6545d440b92b6` |
| admiral-fleet | `admiral-fleet-0.0.1rc5-60.el10.x86_64` | `74db28cdb2d213e84e4ce9dd05267c5b2254691c90b7759aa1cb1049da57f748` |
| admiral-flagship | `admiral-flagship-0.0.1rc5-60.el10.noarch` | `a251475b08f6ef6c12fe31cad58ddbe575927f87e280e00642ee038518705575` |
| admiral-harbor | `admiral-harbor-0.0.1rc5-60.el10.noarch` | `ecb4f8edea521e1a99394de2cb668a2bae0fdd3cf59638434c22e511217be561` |
| admiralctl | `admiralctl-0.0.1rc5-60.el10.x86_64` | `b3c3c0abad4de12f85cee148c0ace87ee41ac4c1b7868d0e53c6a643e490fa89` |
| admirald | `admirald-0.0.1rc5-60.el10.x86_64` | `876c7f5a414c17fcbd654cadb26b25243e6df9321319fdadb54542bb4cee4854` |

All 14 Admiral and Python RPM checksums are in the local repository manifest `packaging/build/repos/el10-rc5-r60-x86_64/SHA256SUMS`. The full RPM build output was not retained; the completed build command returned success with package `%check` steps enabled.

## Executed scenarios

| Test ID | Procedure and observed result | Status | Evidence |
| --- | --- | --- | --- |
| `R60-ROCKY-SN-INSTALL` | Installed the six exact RPMs using the prepared validation seed, ran the secure installer, and checked services/API/runtime baseline. Ansible recap: `ok=231 changed=97 unreachable=0 failed=0 skipped=149`; elapsed 443 s. | PASS — install subset only | Restricted local `install-rocky.log`, SHA-256 `492376f2c22715a4445bb45755c527f319bf0436eafd2a6d3a862f0e56c7ea2e`; baseline SHA-256 `524f79ac5c030e09427ea6cff25ac568f21d7e8051f6f1e2fa24dcc6bbcf4ced` |
| `R60-ROCKY-SN-DB-OUTAGE` | Stopped the declared PostgreSQL user unit. API changed from healthy/available to failed/unhealthy/unavailable after 4 s; it stayed unavailable while PostgreSQL was stopped. Restart restored availability, SQL marker `r60-db-outage-persisted` survived, deprovision succeeded, and cleanup found no resources. | PASS — targeted #260 regression only | Restricted local `rocky-db-service-outage.log`, SHA-256 `863e0701ab9e057750f6b6d49c046c29b9af769a5479ca5f8d65613cde03f076`; cleanup SHA-256 `0ca862a94af0b049ca74686b2461e4208f50553c0fd4e552faed64c5d34ff89c` |
| `R60-ROCKY-SN-USER-MANAGER-RESTART` | Restarted `user@991.service` while a DB-backed workload and SQL marker were live. At `23:59:20Z`, the manager had a new PID, the pod was `activating`, the DB container was absent, HTTP returned `000`, yet Admiral still reported `running/healthy/available`. Fleet detected the manager PID change at `23:59:21.462Z`. At `23:59:26Z`, after the pod and DB were ready, API health and HTTP 200 returned; the marker persisted and deprovision succeeded. | **FAIL — candidate invalidated; #259** | Restricted local `rocky-user-systemd-restart.log`, SHA-256 `16050b9041a15ca658506348f848ebc7d6ea2a3e1bb5832f3a0d2b767f7ae0df`; Fleet journal SHA-256 `c1af0383a79594d9183ed7cede42287f3d5d045e34ae5990fd1222e95ce3f227`; user manager journal SHA-256 `c421ef99c898d4e9d91b549f719ab35f053550c8de6d6b0129e9d2c976c03410`; cleanup audit SHA-256 `a0db032932f426c8ef4d6c4a890f346df77d16d5a47da950e4a051cd14ea8458` |

The system journal records `user@991.service` stopping at `23:59:17.722Z`, deactivating at `23:59:19.811Z`, and starting successfully at `23:59:20.158Z`. This 2.4 s downtime fit inside the previous Fleet 2 s PID polling gap; Fleet observed the replacement PID only after the first false-healthy API sample. Cleanup audit showed no failed units, containers, pods, volumes, Quadlet files or instance data for the test workloads.

## Fix and next validation

Fleet commit `c902a2895c1b12c18f4607b92f13c83515b3da25` now checks the rootless manager every 500 ms and invalidates health without probing Podman in the same transition. It resets the five-second health reconciliation interval after manager replacement so the next report comes from the restored runtime. Local Fleet `go test ./...`, `go vet ./...`, and `go build ./...` passed. GitHub CI run [39875784788](https://github.com/admiral-project/admiral-fleet/actions/runs/39875784788) passed. This fix still requires a new coordinated six-RPM build and fresh exact-candidate runtime verification; Release 60 must not be reused as release evidence.
