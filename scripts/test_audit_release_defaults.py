"""Keep audit guest helpers aligned with the coordinated RPM release."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
RPM_SPECS = (
    "admiral-common",
    "admirald",
    "admiral-fleet",
    "admiralctl",
    "admiral-flagship",
    "admiral-harbor",
)
AUDIT_HELPERS = (
    ROOT
    / "docs/audits/admiral-production-readiness-2026-10-21/scripts/install-single-node-audit.sh",
    ROOT
    / "docs/audits/admiral-production-readiness-2026-10-21/scripts/bootstrap-candidate-node.sh",
    ROOT
    / "docs/audits/admiral-production-readiness-2026-10-21/scripts/install-admin-portal-audit.sh",
)


def test_audit_helpers_default_to_the_coordinated_rpm_release():
    releases = set()
    for package in RPM_SPECS:
        spec = ROOT / f"packaging/rpm/{package}.spec"
        match = re.search(r"^Release:\s*(\d+)%\{\?dist\}", spec.read_text(), re.MULTILINE)
        assert match, f"missing numeric Release in {spec}"
        releases.add(match.group(1))

    assert len(releases) == 1, f"Admiral RPM Release values differ: {sorted(releases)}"
    expected = releases.pop()
    for helper in AUDIT_HELPERS:
        text = helper.read_text()
        match = re.search(r"ADMIRAL_RC_RELEASE:-([0-9]+)", text)
        assert match, f"missing default candidate release in {helper}"
        assert match.group(1) == expected, (
            f"{helper} defaults to Release {match.group(1)}, but RPM specs use {expected}"
        )
