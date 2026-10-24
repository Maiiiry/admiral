# RC5 Release 70 candidate identity

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Candidate: Admiral RC5 `0.0.1rc5-70.el10`<br>
Active scope: Rocky Linux 10 x86_64, Single-Node and three-guest Multi-Node.

## Source identity

- Root package-preparation commit: `fb081f3378813a0b5bd800a1573d0b4773052a44` (`build(release): prepare Rocky RC5 Release 70 candidate`), pushed to `origin/main`.
- Before the package build, each component was fetched from GitHub and its selected commit matched `origin/main`. Exact pins:

| Component | Selected commit |
|---|---|
| `admirald` | `a4d39ae6b5db92bd7e6e5257dc8f6b919af52668` |
| `admiral-fleet` | `029bb53da6c2bef7d567213a5fd6ab106d56d68c` |
| `admiralctl` | `fa2a65e866310bd82bea78859804b6c3aea7989a` |
| `admiral-flagship` | `b7325bbc71fc474a521496e593b2967e4d555ac1` |
| `admiral-harbor` | `dd39e9a74bf658ecf6fd6e9f8bd30b2ddf82d7db` |

- `python3 scripts/validate-release-refs.py`: PASS before build.
- Root CI: [run 40059727954](https://github.com/admiral-project/admiral/actions/runs/40059727954), completed successfully; both `Scripts regression suite` and `admiralctl local source-layout checks` passed.
- Component CI for the exact selected SHAs: [admirald 40030035439](https://github.com/admiral-project/admirald/actions/runs/40030035439), [admiral-fleet 40052142923](https://github.com/admiral-project/admiral-fleet/actions/runs/40052142923), [admiralctl 40030034925](https://github.com/admiral-project/admiralctl/actions/runs/40030034925), [admiral-flagship 39795263415](https://github.com/admiral-project/admiral-flagship/actions/runs/39795263415), [admiral-harbor 39795262318](https://github.com/admiral-project/admiral-harbor/actions/runs/39795262318): all completed successfully.

## Build and package identity

The six coordinated RPMs and six SRPMs were built natively on Rocky Linux 10.2 x86_64 using the EL10 toolchain. No Fedora or other-distribution RPM was installed into the EL10 guests. The local repository is `/var/lib/libvirt/images/admiral-validation/repo/rc5-r70/el10/x86_64/`; DNF used normal dependency resolution, `gpgcheck=1`, and the imported validation key.

| Package | NEVRA |
|---|---|
| `admiral-common` | `admiral-common-0.0.1rc5-70.el10.noarch` |
| `admirald` | `admirald-0.0.1rc5-70.el10.x86_64` |
| `admiral-fleet` | `admiral-fleet-0.0.1rc5-70.el10.x86_64` |
| `admiralctl` | `admiralctl-0.0.1rc5-70.el10.x86_64` |
| `admiral-flagship` | `admiral-flagship-0.0.1rc5-70.el10.noarch` |
| `admiral-harbor` | `admiral-harbor-0.0.1rc5-70.el10.noarch` |

All six Admiral binary RPM signatures/payload digests and all six Admiral SRPM signatures/digests verified with `rpmkeys --checksig`; the Admiral RPM signing key ID is `34ed6667`. All 14 binary RPMs (six Admiral packages and eight Python helpers) and six Admiral SRPM SHA-256 values are in [`release70-rpm-sha256.txt`](release70-rpm-sha256.txt). The updated Rocky seed retains the EPEL compatibility pin `python3-pyOpenSSL-25.0.0-1.el10_1`.

## Runtime lab identity

- Seed: `/var/lib/libvirt/images/admiral-validation/seeds/Rocky-10.2-seed-20261023-r66.x86_64.qcow2`; SHA-256 `64d918c2b1b8d69d210372d0e80252798178e3ae9b6b7f4af4dbec2b39b5b3d0`.
- Guests are clean 2-vCPU/2-GiB Rocky 10.2 x86_64 overlays from that seed. The seed has current OS updates applied; the installer used the explicit validation-seed mode to skip repeating the full OS update transaction.
- Single-Node guest: `adm-r70-rocky-single`, `192.168.122.216`.
- Multi-Node: `adm-r70-rocky-hub` (`10.77.0.10`, overlay `10.99.0.1`), `adm-r70-rocky-w1` (`10.77.0.11`, overlay `10.99.0.2`), `adm-r70-rocky-w2` (`10.77.0.12`, overlay `10.99.0.3`).
- The exact six candidate packages were installed on the Single-Node guest and hub. Workers receive exact `admiral-common` and `admiral-fleet` candidate packages through the supported secure bootstrap.
- Unsanitized installer and runtime logs remain local, ignored, and mode `0600` under `packaging/build/validation/rc5-r70/`. Do not copy those raw logs to GitHub; the tracked reports contain sanitized observations and hashes.

## Runtime status

- Single-Node: **PASS** on this exact Release 70 candidate; see [`../SINGLE_NODE_REPORT.md`](../SINGLE_NODE_REPORT.md).
- Multi-Node: **PASS** on this exact Release 70 candidate using three real Rocky Linux 10.2 x86_64 guests; see [`release70-multinode-runtime.md`](release70-multinode-runtime.md) and [`../MULTI_NODE_REPORT.md`](../MULTI_NODE_REPORT.md).
- Functional Rocky matrix: **2/2 PASS** on the unchanged candidate. RPM package hashes and NEVRAs are in [`release70-rpm-sha256.txt`](release70-rpm-sha256.txt); runtime evidence hashes are in [`release70-runtime-log-sha256.txt`](release70-runtime-log-sha256.txt). Raw logs stay local, ignored and mode `0600`.
- Findings #267 and #268 remain open and tagged `fix-proposed`; the Release 70 runtime checks exercised their proposed fixes. No issue was closed as part of validation.
- This is the functional release gate only. The broader production-readiness audit (security isolation, performance, resource exhaustion and additional fault scenarios) remains **NOT VALIDATED**.
