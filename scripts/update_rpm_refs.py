#!/usr/bin/env python3
"""Pin RPM and Makefile source references without changing release metadata."""

from pathlib import Path
import re
import subprocess


ROOT = Path(__file__).resolve().parents[1]
COMPONENTS = (
    ("ADMIRALD_COMMIT", "admirald", "admirald.spec"),
    ("FLEET_COMMIT", "admiral-fleet", "admiral-fleet.spec"),
    ("ADMIRALCTL_COMMIT", "admiralctl", "admiralctl.spec"),
    ("FLAGSHIP_COMMIT", "admiral-flagship", "admiral-flagship.spec"),
    ("HARBOR_COMMIT", "admiral-harbor", "admiral-harbor.spec"),
)
SECONDARY_ADMIRALD_SOURCES = (
    ("admiral-fleet", "Source3"),
    ("admiralctl", "Source2"),
)


def git_head(path):
    return subprocess.check_output(
        ["git", "-C", str(path), "rev-parse", "HEAD"], text=True
    ).strip()


def replace_once(path, pattern, replacement):
    original = path.read_text()
    updated, count = re.subn(pattern, replacement, original, count=1, flags=re.MULTILINE)
    if count != 1:
        raise RuntimeError(f"expected one source reference in {path}, found {count}")
    if updated != original:
        path.write_text(updated)


def main():
    makefile = ROOT / "Makefile"
    component_commits = {}
    for variable, directory, spec_name in COMPONENTS:
        commit = git_head(ROOT / directory)
        component_commits[directory] = commit
        replace_once(
            makefile,
            rf"^{variable} := [0-9a-f]{{40}}$",
            f"{variable} := {commit}",
        )
        replace_once(
            ROOT / "packaging" / "rpm" / spec_name,
            r"^%global commit [0-9a-f]{40}$",
            f"%global commit {commit}",
        )

    common_commit = git_head(ROOT)
    replace_once(
        makefile,
        r"^ADMIRAL_COMMON_COMMIT := [0-9a-f]{40}$",
        f"ADMIRAL_COMMON_COMMIT := {common_commit}",
    )
    replace_once(
        ROOT / "packaging" / "rpm" / "admiral-common.spec",
        r"^%global commit [0-9a-f]{40}$",
        f"%global commit {common_commit}",
    )
    admirald_commit = component_commits["admirald"]
    for spec_name, source in SECONDARY_ADMIRALD_SOURCES:
        replace_once(
            ROOT / "packaging" / "rpm" / f"{spec_name}.spec",
            rf"^{source}: https://github\.com/admiral-project/admirald/archive/[0-9a-f]{{40}}\.tar\.gz$",
            f"{source}: https://github.com/admiral-project/admirald/archive/{admirald_commit}.tar.gz",
        )
    print("RPM source references updated; release and changelog were not modified.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError) as exc:
        raise SystemExit(f"update RPM refs failed: {exc}") from exc
