# Admiral RC5 Release 54 candidate — INVALIDATED

**Status:** Build and package checks succeeded, but Release 54 was invalidated by the CentOS Stream concurrent idempotency failure in [#254](https://github.com/admiral-project/admiral/issues/254). See `release54-invalidation-concurrent-idempotency.md`. No Release 54 test counts toward a later candidate; matrix remains 0/8.


- Build date: 2026-10-22 UTC.
- Build host: Rocky Linux 10.2 x86_64; Go RPM `golang-1.26.10-1.el10_2.x86_64`.
- Root source commit: `623083f369579ba0031b77ef9537a0aacf904a93`.
- Root GitHub Actions: [run 39797496909](https://github.com/admiral-project/admiral/actions/runs/39797496909), success.
- Component `origin/main` pins were fetched and compared immediately before the build; `scripts/validate-release-refs.py` passed.
- The complete six-package x86_64 RPM build succeeded. RPM `%check` ran during build; Flagship passed 266 tests and Harbor passed 350 tests. The Go component test commands completed successfully.
- Candidate repository: `/var/lib/libvirt/images/admiral-validation/repo/rc5-r54`; EL10 and Fedora metadata both returned HTTP 200. Repository files and per-distro SHA-256 manifests are local validation evidence.
- Successful build log: `packaging/build/validation/rc5-r54/build-retry-02.log` (mode 0600), SHA-256 `59f4009d4bf3adff351746d0824c076912cef5c268144e001a9efdb032b8caa7`.
- Earlier failed attempts were preserved as `build.log` (missing host Go BuildRequires) and `build-retry-01.log` (missing host Mistune BuildRequires); neither produced a complete candidate.

| RPM | NEVRA | SHA-256 |
|---|---|---|
| `admiral-common` | `admiral-common-0.0.1rc5-54.el10.noarch` | `9a3a668194af67f33d77f1473c3e5f0ecb7b7959437da331d1650bbb15ec484e` |
| `admirald` | `admirald-0.0.1rc5-54.el10.x86_64` | `e96c44c7c6fbac3b89132e8b2b7b99482932fbb813d4ce30d1b68437f1fcfe61` |
| `admiral-fleet` | `admiral-fleet-0.0.1rc5-54.el10.x86_64` | `ca0fbfc3a6acf46688f226b7138b363438a2c57f9592ddfd92896c239e229d90` |
| `admiralctl` | `admiralctl-0.0.1rc5-54.el10.x86_64` | `231d6b19e339fa83239c0b094fdb0f8f145dccf5104d7d4df96caf675368dc8e` |
| `admiral-flagship` | `admiral-flagship-0.0.1rc5-54.el10.noarch` | `b2ee1a839dd5e783b295b6b8d99c9823c86b620194af9560c6cc09ea06b1a059` |
| `admiral-harbor` | `admiral-harbor-0.0.1rc5-54.el10.noarch` | `2b58a954e20331fe459ff9c41c9d15ba1fa231bfe0785eaf311ca92e3ce7fc07` |

The local candidate repository also contains the support RPM set needed for dependency resolution, including `python3-flask-3.1.3-2.el10.noarch` and `python3-mistune-3.4.0-1.el10.noarch` for EL10, and `python3-mistune-3.4.0-1.fc46.noarch` for Fedora. The EL10 Mistune pin is SHA-256 `e4d00c79a8603c1ece1c210fcc4c2fa1eab1091ebd11269e4c6e788f196972ea`; the Fedora build is `bab290ad69b697f95af88663023c62c433964af5186b47e83a5496256906abaa`.

At report creation, the matrix is still **0/8**. Fedora Rawhide and Rocky Linux 10 Single-Node installs are running from fresh 2026-10-22 seed overlays. Installation and configuration are not counted as completed validation cells; each cell still requires its functional, security, recovery, and consistency checks.
