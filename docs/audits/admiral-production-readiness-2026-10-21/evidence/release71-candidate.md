# RC5 Release 71 candidate record

**Status: BUILD PENDING; matrix 0/8.** This record is candidate-specific. Do not carry Release 70 runtime evidence into Release 71.

## Scope

Release 71 is intended for Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 on x86_64, each in Single-Node and Multi-Node. Multi-Node means three real VMs of the same operating system (one control-plane/admin node and two workers). ARM64 is a separate Tier 2 track and is not release-blocking.

## Source references

The five component submodules were fetched from `origin/main` on 2026-10-24 and the selected pins matched those published commits:

| Repository | Selected SHA | CI for exact commit |
|---|---|---|
| `admirald` | `a4d39ae6b5db92bd7e6e5257dc8f6b919af52668` | Prior exact-commit CI passed; verify again before candidate acceptance |
| `admiral-fleet` | `029bb53da6c2bef7d567213a5fd6ab106d56d68c` | Prior exact-commit CI passed; verify again before candidate acceptance |
| `admiralctl` | `fa2a65e866310bd82bea78859804b6c3aea7989a` | Prior exact-commit CI passed; verify again before candidate acceptance |
| `admiral-flagship` | `b7325bbc71fc474a521496e593b2967e4d555ac1` | Prior exact-commit CI passed; verify again before candidate acceptance |
| `admiral-harbor` | `dd39e9a74bf658ecf6fd6e9f8bd30b2ddf82d7db` | Prior exact-commit CI passed; verify again before candidate acceptance |

`python3 scripts/validate-release-refs.py` passed before candidate preparation. All six Admiral RPM specs now use `Release: 71`; native Fedora and EL10 builds are pending. Fedora must use Rawhide build tooling and `.fc46` RPMs; EL10 uses the EL10 toolchain and `.el10` RPMs. Cross-distribution installation and dependency bypasses are prohibited.

## Fix included before the build

The reusable validation-seed helper previously applied EPEL `python3-pyOpenSSL-25.0.0-1.el10_1` only on Rocky Linux. R69/R70 investigation established that AlmaLinux 10.2 needs the same verified compatibility pin; CentOS Stream 10 resolves its native EPEL set and remains unpinned. Release 71 preparation extends the seed script to AlmaLinux, keeps the checksum/GPG verification and EPEL exclusion, and adds a regression assertion. The pin is an audit-seed dependency-resolution exception, not an Admiral RPM dependency change. Issue #269 remains open.

## Build and runtime status

- Package-preparation commit: pending commit/CI.
- Root helper tests: `python3 -m pytest -q scripts/test_*.py` — 137 passed locally.
- `python3 scripts/validate-release-refs.py` — PASS.
- Native EL10 and Fedora builds: NOT TESTED.
- RPM manifests, signatures and SHA-256: pending.
- R71 Single-Node and Multi-Node cells: **0/8 validated**; all eight start NOT TESTED.
- No production readiness conclusion is implied by a functional cell pass.

