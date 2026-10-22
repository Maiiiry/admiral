# Admiral Release 52 candidate build record

Audit: `ADM-AUDIT-2026-10-21`  
Candidate: Admiral RC5 Release 52, x86_64 RPM set.  
Disposition: **BUILT, installed, partially exercised, then INVALIDATED by #246.** All six RPMs built with their six `%check` stages passing and both isolated local repositories returned the same six Admiral NEVRAs. Fresh Fedora Rawhide and Rocky Linux 10.2 Single-Node guests installed R52 and completed scoped probes; a secret-loss defect during resize invalidated the candidate. No complete matrix cell passed; matrix completion remains **0/8**. See [`release52-initial-single-node-execution.md`](release52-initial-single-node-execution.md) for scenario results and evidence hashes.

## Build identity and host

The signed package-preparation commit is root `c22d05ef23dce9c693af8e46bf53f3e19955979b`; root CI [39731120097](https://github.com/admiral-project/admiral/actions/runs/39731120097) is green. All six Admiral specs report `Release: 52`. The build completed on 2026-10-22 at approximately 06:06 UTC on the isolated Rocky Linux 10.2 x86_64 lab host (4 vCPU, 8 GiB RAM, 4 GiB swap, SELinux enforcing, KVM/libvirt available). There were no active guests. Disk availability was 89 GiB before and after the build; updated OS seeds and prior candidate repositories were preserved.

Before the build, each component repository was freshly fetched and its selected SHA compared with `origin/main`. All five component pins matched exactly:

| Component | Selected SHA = `origin/main` | GitHub CI |
| --- | --- | --- |
| `admirald` | `0baf488353386fdb67f995ef3e72cfe6cfc6de07` | [39730492772](https://github.com/admiral-project/admirald/actions/runs/39730492772) — success |
| `admiral-fleet` | `740b690fdb49e86fa63c9db2b56a1e576247b162` | [39663860552](https://github.com/admiral-project/admiral-fleet/actions/runs/39663860552) — success |
| `admiralctl` | `5ed381d7d152e1606e78fafe332587cca09bc989` | [39724553667](https://github.com/admiral-project/admiralctl/actions/runs/39724553667) — success |
| `admiral-flagship` | `3911eb784aef732f0bbe4662d1dbc6a5947eb659` | [39654771764](https://github.com/admiral-project/admiral-flagship/actions/runs/39654771764) — success |
| `admiral-harbor` | `92c5ccac6a647cb85da36b056cb3352f391ab8c9` | [39705906726](https://github.com/admiral-project/admiral-harbor/actions/runs/39705906726) — success |

The common RPM source is root commit `6a249990671292d3f28401dc268db78f2bb5b601`, which was `origin/main` immediately before the coordinated packaging commit. Root `main` now points to `c22d05e`; the intervening change updates package pins/releases and audit documentation but does not change any of the common RPM's packaged payload paths. `python3 scripts/validate-release-refs.py` verifies that payload equivalence and all component/spec/Makefile references; it passed before the build and from each RPM target. The common source commit's root CI [39728224943](https://github.com/admiral-project/admiral/actions/runs/39728224943) and the package-preparation CI [39731120097](https://github.com/admiral-project/admiral/actions/runs/39731120097) are green.

## Build and checks

The build command was:

```bash
GOTOOLCHAIN=auto make rpm-admiral RPM_ARCH=x86_64 RPMFLAGS="--target x86_64 --define '_topdir /root/admiral/packaging/build' --define '_sourcedir /root/admiral/packaging/build/SOURCES' --define '_specdir /root/admiral/packaging/build/SPECS' --define '_builddir /root/admiral/packaging/build/BUILD' --define '_rpmdir /root/admiral/packaging/build/RPMS' --define '_srcrpmdir /root/admiral/packaging/build/SRPMS' --define '_tmppath /root/admiral/packaging/build/tmp' --nodeps"
```

The restricted raw build log is outside Git at `packaging/build/validation/rc5-r52/evidence/build.log`, mode `0600`, SHA-256 `7466cd2df087dfc353a7d2faf15e69028de88453c34e76ca4d0dbb91dde3fd96`. It contains six `Executing(%check)` sections and ends with `=== All 6 Admiral RPMs built ===`. No `--nocheck` was used. The common package checked four staged shell entry points with `bash -n` and compiled five staged Python entry points in memory. The Go package checks passed, including their x86_64 ELF checks; Flagship passed 266 tests; Harbor passed 350 tests in 183.34 seconds with 307 deprecation warnings tracked in #242. The warnings are non-fatal and the same known Alembic/SQLAlchemy warning class seen in earlier candidate suites.

The host has Go `1.26.7-2.el10_2`, below the RPM `BuildRequires` floor of 1.26.10, so `--nodeps` bypassed that host package gate. `GOTOOLCHAIN=auto` was enabled and all build and `%check` steps ran. This is a documented build-host limitation, not a skipped package test.

## Exact RPM identities

| NEVRA | SHA-256 |
| --- | --- |
| `admiral-common-0.0.1rc5-52.el10.noarch` | `9970c5a44af91703f8813b5ca167259128830ca0fd60c45dd0f05527ffa31004` |
| `admirald-0.0.1rc5-52.el10.x86_64` | `2ebb05305bc6307da9c2385dcb9fb29660b808328868c6dc03bda8d57d2f3237` |
| `admiral-fleet-0.0.1rc5-52.el10.x86_64` | `14efb811f9b4745d12c2d5465307303443df08a8042012be4632d3ed6edca636` |
| `admiralctl-0.0.1rc5-52.el10.x86_64` | `04435b96ce9e86268cfd1cc75a65e1971023b25d1f9f94f183ef45e01679dddc` |
| `admiral-flagship-0.0.1rc5-52.el10.noarch` | `3cfdab4fc40ba3b689f30b6f9b94e890651f6d4e0f54e9f59e9605d3f577a662` |
| `admiral-harbor-0.0.1rc5-52.el10.noarch` | `10f84cd6ee3ad6c7f607060fb4d9c3d458606bc7912dd8bf31509d34bc9e3f20` |

Machine-readable hashes are in [`release52-rpm-sha256.txt`](release52-rpm-sha256.txt). The staged copies in both repositories were byte-for-byte checked against these digests.

## Local repositories

The isolated repositories are served from the validation host and contain 13 RPMs each: the six R52 Admiral RPMs and seven pinned Python support RPMs. EL10 uses `python3-mistune-3.4.0-1.el10.noarch`; Fedora Rawhide uses `python3-mistune-3.4.0-1.fc46.noarch`. The exact repoquery results are committed in [`release52-el10-repoquery.txt`](release52-el10-repoquery.txt) and [`release52-fedora-repoquery.txt`](release52-fedora-repoquery.txt); the local configs, full repo checksums and raw copies remain in the ignored `packaging/build/validation/rc5-r52/` directory.

| Repository | Metadata endpoint | HTTP | `repomd.xml` SHA-256 | Repo config SHA-256 |
| --- | --- | --- | --- | --- |
| EL10 | `http://192.168.122.1/rc5-r52/el10/x86_64/repodata/repomd.xml` | 200 | `d2672e0af694fb0775185508ef466f08bd5229ce40e3e9c33ab9a2bb1a6423cc` | `63bd5e3ca92ea3028261db316535e724bc3178bc88a674f3c5824a8a3ece3c8c` |
| Fedora Rawhide | `http://192.168.122.1/rc5-r52/fedora/x86_64/repodata/repomd.xml` | 200 | `6c5db47c05fb5c57ccad271573f0a3c16204cb2b76b576ab6079eb5178674af3` | `7ede4ca52383112909d792d2f8977675a0f4aba0303349b5afa6d7a0db13b472` |

Both repositories returned the same six Release 52 NEVRAs. Per-repository checksums (including the seven support RPMs) are retained under the ignored `packaging/build/validation/rc5-r52/` directory.

## Runtime status

R52 was installed on fresh Fedora Rawhide and Rocky Linux 10.2 Single-Node overlays and exercised with the scoped probes in `release52-initial-single-node-execution.md`. Both guests reproduced #246: resize returned success but the recreated database service lost its generated secret references. Release 52 is **invalidated**; none of its observations count toward matrix completion. The source fix `admirald@b4b125e` has green component CI [39737323015](https://github.com/admiral-project/admirald/actions/runs/39737323015) and is included in the rebuilt Release 53 candidate documented in `release53-candidate.md`. R53 runtime validation must use fresh overlays; the matrix remains **0/8**. Rocky uses the recorded EPEL pyOpenSSL 25.0.0 seed pin. No issue was closed.
