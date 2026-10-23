# Release 65 local pre-build checks

**Disposition: PASS for local source/unit checks only.** This evidence does not validate RPM builds, DNF dependency resolution, installation, or any matrix cell.

- Root checkout base: `22f2fba1894d00c383dfa48b2413c05685050ec2`; uncommitted Release 65 RPM spec and audit-document changes were under test.
- Component source refs were fetched from `origin/main` and matched the root Makefile/spec pins:
  - common `f7118329c23a75ef36b0cd6067f30a82617d9ac9`
  - admirald `351a713dec3a3672a22707c1e15a7f77f827e1c5`
  - fleet `0c805d6293bfb11fd4f015f1b0ccff520481e627`
  - admiralctl `49cf2428c064434c65af9a14f96975c1bb2db637`
  - flagship `b7325bbc71fc474a521496e593b2967e4d555ac1`
  - harbor `dd39e9a74bf658ecf6fd6e9f8bd30b2ddf82d7db`
- `python3 scripts/validate-release-refs.py`: PASS.
- `python3 -m pytest -q scripts/test_*.py`: PASS, 129 passed in 3.30 seconds.
- `go test ./...` in `admirald`: PASS.
- `go test ./...` in `admiral-fleet`: PASS.
- `go test ./...` in `admiralctl`: PASS.
- `python3 -m pytest tests/ -x --tb=short` in `admiral-flagship`: PASS, 266 passed in 21.88 seconds.
- `python3 -m pytest tests/ -x --tb=short` in `admiral-harbor`: PASS, 350 passed in 203.72 seconds.
- `rpmspec --parse` for all six Admiral and five modified Python helper specs: PASS.
- `git diff --check`: PASS; `bash -n` for the three candidate installer/bootstrap helpers: PASS.

All six Admiral RPM specs are coordinated at Release 65. The changed dependency declarations have not yet been evaluated by an RPM builder or by Fedora DNF5. The next gate is signed root commit/push and green root CI, followed by a fresh R65 build and clean Fedora DNF5 resolution without vendor-change overrides or downgrades.
