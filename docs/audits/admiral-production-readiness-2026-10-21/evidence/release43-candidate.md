# Release 43 candidate build record

Built: 2026-10-21T18:58:24+00:00
Packaging recipe commit: `a94c348606a538e9334e7be07d821849a2fedad8` (`origin/main`).
Target: Rocky Linux 10.2 build host; x86_64; RPM Release 43.
Audit scope: Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10, Single-Node and Multi-Node.

## Pinned source commits

| Component | SHA |
| --- | --- |
| admiral-common payload | `d01b08c1b8976d9c3d6d6f3cec6f1e01d1230c39` |
| admirald | `12b5612873cbdb2dd9c3fabd1bb882ef55c30584` |
| admiral-fleet | `004d49a49a2edd783e9a11ada00e128f599ed0bc` |
| admiralctl | `2840536316dcd4ae5a038bee9b29334a67a5d7de` |
| admiral-flagship | `3911eb784aef732f0bbe4662d1dbc6a5947eb659` |
| admiral-harbor | `3223c07246fd1b76ba8b311afa62cdf1be46839e` |

All five component submodules were fetched immediately before the build; each checked-out SHA equaled `origin/main`. `python3 scripts/validate-release-refs.py` passed.

## GitHub Actions

All workflows passed for the exact repository heads used by this candidate:

| Repository | Commit | CI | Result |
| --- | --- | --- | --- |
| `admiral` | `a94c348606a538e9334e7be07d821849a2fedad8` | [Main Regression Tests](https://github.com/admiral-project/admiral/actions/runs/39657433692) | PASS |
| `admirald` | `12b5612873cbdb2dd9c3fabd1bb882ef55c30584` | [CI](https://github.com/admiral-project/admirald/actions/runs/39655359688) | PASS |
| `admiral-fleet` | `004d49a49a2edd783e9a11ada00e128f599ed0bc` | [CI](https://github.com/admiral-project/admiral-fleet/actions/runs/39650315686) | PASS |
| `admiralctl` | `2840536316dcd4ae5a038bee9b29334a67a5d7de` | [CI](https://github.com/admiral-project/admiralctl/actions/runs/39654766669) | PASS |
| `admiral-flagship` | `3911eb784aef732f0bbe4662d1dbc6a5947eb659` | [CI](https://github.com/admiral-project/admiral-flagship/actions/runs/39654771764) | PASS |
| `admiral-harbor` | `3223c07246fd1b76ba8b311afa62cdf1be46839e` | [CI](https://github.com/admiral-project/admiral-harbor/actions/runs/39655648591) | PASS |

## Artifacts

| Package | NEVRA | SHA-256 | Local validation copies |
| --- | --- | --- | --- |
| `admiral-common` | `admiral-common-0.0.1rc5-43.el10.noarch` | `4a443f2425b0b694a5f88b9e2ddce73a36e7c315d15a92228f3598cfcd5b3f4b` | `el10/x86_64`, `fedora/x86_64` (byte-identical) |
| `admirald` | `admirald-0.0.1rc5-43.el10.x86_64` | `fe7ea5755b69c611e31a951a2d1aef6b86ed0e7426f58a425edf1363a425219d` | `el10/x86_64`, `fedora/x86_64` (byte-identical) |
| `admiral-fleet` | `admiral-fleet-0.0.1rc5-43.el10.x86_64` | `ce8f042087fbc9cd1a6b6ad53612a53a1b8874fb09c8c8595b84e162e4ccf306` | `el10/x86_64`, `fedora/x86_64` (byte-identical) |
| `admiralctl` | `admiralctl-0.0.1rc5-43.el10.x86_64` | `fa910ddf01ce8e9c5603ae9f2fa152f781dd0cf74c9dda24087b05d71067e20d` | `el10/x86_64`, `fedora/x86_64` (byte-identical) |
| `admiral-flagship` | `admiral-flagship-0.0.1rc5-43.el10.noarch` | `1d378e36d1e9e0cf91055ff4f1aff65aeb83e881ef351520a8faf00df424bb86` | `el10/x86_64`, `fedora/x86_64` (byte-identical) |
| `admiral-harbor` | `admiral-harbor-0.0.1rc5-43.el10.noarch` | `a02ff7aefa00bd75726b95ff23a541e97331a4aa734a604f84388750cc0f6443` | `el10/x86_64`, `fedora/x86_64` (byte-identical) |
| `python3-mistune` | `python3-mistune-3.4.0-1.el10.noarch` | `e4d00c79a8603c1ece1c210fcc4c2fa1eab1091ebd11269e4c6e788f196972ea` | `el10/x86_64`, `fedora/x86_64` (byte-identical) |

The six Admiral packages are `0.0.1rc5-43.el10`; the additional runtime dependency `python3-mistune-3.4.0-1.el10.noarch` is in both local repositories.

## Build and repository verification

- `make rpm-python-mistune RPM_ARCH=x86_64` built the Mistune runtime dependency.
- `make rpm-admiral RPM_ARCH=x86_64` completed all six RPM builds; all five specs with `%check` passed. Flagship: 266 tests passed. Harbor: 347 tests passed, 304 warnings.
- Harbor `%check` loaded Mistune 3.4.0 from a temporary `PYTHONPATH`; the system RPM remains unchanged.
- The host RPM database reports Go 1.26.7 while the three Go modules require 1.26.10. The build used cached Go 1.26.10 with `GOTOOLCHAIN=auto`; `rpmbuild --nodeps` bypassed only its local BuildRequires preflight. Compilation, package `%check`, and ELF architecture checks ran.
- `createrepo_c --update --checksum sha256` refreshed the EL10 and Fedora local x86_64 repositories. `dnf repoquery --latest-limit=1` returned Release 43 for all six Admiral packages and Mistune 3.4.0. Both HTTP `repomd.xml` endpoints returned 200.
- Disk availability was 42 GiB before and after the RPM build.
- The Release 43 artifacts have not yet been installed into audit guests; the eight runtime matrix cells remain unvalidated for this candidate.

Repository root: `/var/lib/libvirt/images/admiral-validation/repo`; EL10 URL: `http://192.168.122.1/el10/$basearch`; Fedora URL: `http://192.168.122.1/fedora/$basearch`.
