# RC5 Release 71 candidate record

**Status: INVALIDATED by an exact-RPM Fedora Single-Node false-availability observation; matrix credit 0/8.** This record is candidate-specific. Do not carry Release 70 runtime evidence into Release 71.

## Scope

Release 71 is intended for Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 on x86_64, each in Single-Node and Multi-Node. Multi-Node means three real VMs of the same operating system (one control-plane/admin node and two workers).

## Source references

The five component submodules were fetched from `origin/main` on 2026-10-24 and the selected pins matched those published commits:

| Repository | Selected SHA | CI for exact commit |
|---|---|---|
| `admirald` | `a4d39ae6b5db92bd7e6e5257dc8f6b919af52668` | Prior exact-commit CI passed; verify again before candidate acceptance |
| `admiral-fleet` | `029bb53da6c2bef7d567213a5fd6ab106d56d68c` | Prior exact-commit CI passed; verify again before candidate acceptance |
| `admiralctl` | `fa2a65e866310bd82bea78859804b6c3aea7989a` | Prior exact-commit CI passed; verify again before candidate acceptance |
| `admiral-flagship` | `b7325bbc71fc474a521496e593b2967e4d555ac1` | Prior exact-commit CI passed; verify again before candidate acceptance |
| `admiral-harbor` | `dd39e9a74bf658ecf6fd6e9f8bd30b2ddf82d7db` | Prior exact-commit CI passed; verify again before candidate acceptance |

`python3 scripts/validate-release-refs.py` passed before candidate preparation. All six Admiral RPM specs now use `Release: 71`; native EL10 build and all six Fedora rpmbuild `%check` phases completed. The Fedora aggregate Make target returned nonzero only because its final `find` used a different `RPMDIR` from `RPMTOPDIR`; the six RPM artifacts and test logs are preserved. Fedora must use Rawhide build tooling and `.fc46` RPMs; EL10 uses the EL10 toolchain and `.el10` RPMs. Cross-distribution installation and dependency bypasses are prohibited.

## Fix included before the build

The reusable validation-seed helper previously applied EPEL `python3-pyOpenSSL-25.0.0-1.el10_1` only on Rocky Linux. R69/R70 investigation established that AlmaLinux 10.2 needs the same verified compatibility pin; CentOS Stream 10 resolves its native EPEL set and remains unpinned. Release 71 preparation extends the seed script to AlmaLinux, keeps the checksum/GPG verification and EPEL exclusion, and adds a regression assertion. Fedora preflight also showed that staged Python RPMs were installed with `NOKEY` warnings. The helper now requires the pinned Admiral validation key, imports it, verifies each package signature, and enables local-package signature checking in DNF. Issues #269 and #270 remain open pending fresh-seed checks. The pyOpenSSL pin is an audit-seed dependency-resolution exception, not an Admiral RPM dependency change.

## Build and runtime status

- R71 root candidate commit: `ad4f6caa0572ebeff54d3dfcb51f635cf346b31e`; root CI [40066220144](https://github.com/admiral-project/admiral/actions/runs/40066220144) passed.
- Root helper tests: `python3 -m pytest -q scripts/test_*.py` — 138 passed locally after the seed-signature regression was added.
- Fedora local RPM signature probe: all eight exact `.fc46` helper RPMs passed `rpmkeys --checksig` against key fingerprint `7103D33100F674D0B3DFAD17B943D0C834ED6667`; `dnf install --setopt=localpkg_gpgcheck=1` completed with no `NOKEY` warnings. The first run without the guest key is preserved as a failed preflight and tracked by #270.
- `python3 scripts/validate-release-refs.py` — PASS.
- Native EL10 RPM build: PASS, all six `%check` sections passed. Fedora Rawhide RPM build: all six `rpmbuild` and `%check` sections passed; aggregate output discovery failed as documented above.
- Local repositories under `/var/lib/libvirt/images/admiral-validation/repo/rc5-r71/{el10,fedora}/x86_64` contain 14 RPMs per platform, `RPM-MANIFEST.tsv` and `SHA256SUMS`; all RPM signatures and signed `repomd.xml` verified.
- R71 Single-Node and Multi-Node cells: **0/8 validated**. Rocky and Fedora received exact-candidate Single-Node probes, but R71 was invalidated before any cell could pass. AlmaLinux, CentOS Stream, and all Multi-Node cells were NOT TESTED on R71.
- No production readiness conclusion is implied by a functional cell pass.



## R71 runtime invalidation — 2026-10-24

The exact Release 71 Fedora Rawhide guest reported `running/healthy/available` at 06:11:18.615Z and 06:11:21.633Z while its declared PostgreSQL `pg_isready` check failed and the provision operation remained queued. PostgreSQL became ready at 06:11:25.066Z; the operation succeeded at 06:11:29.157Z. The test instance was deprovisioned and its matching containers were removed. This confirms the existing #236 readiness gap and invalidates R71 for release matrix credit.

A same-candidate Rocky Linux 10 Single-Node repeat remained `stopped/unavailable` until `pg_isready` succeeded; it did not reproduce false availability. Restricted evidence logs are mode 0600: Fedora SHA-256 `116a6cefb7c225c69dba442dc5f1f89407d8f93670dcdda63bad1c2b130997a1`; Rocky SHA-256 `fad17793ce6c688fdfd2a1b07ae112959be90ce8dcc263eff97227e72a1e883a`. No R71 observation is carried forward into R72.

The confirmed implementation gap was in Fleet periodic health reporting: provision used declared healthchecks, but periodic health only inspected container state. The correction is in `admiral-fleet@55a9371` and the follow-up redirect safeguard in `admiral-fleet@fc6909f`; exact-commit CI for `fc6909f` is pending. Issue #236 remains open with `needs-work` pending the rebuilt candidate; #271 tracks redirect prevention and remains open with `fix-proposed`.
