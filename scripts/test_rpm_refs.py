from pathlib import Path
from unittest.mock import patch

from scripts import update_rpm_refs


OLD = "1" * 40
NEW = {
    "admirald": "a" * 40,
    "admiral-fleet": "b" * 40,
    "admiralctl": "c" * 40,
    "admiral-flagship": "d" * 40,
    "admiral-harbor": "e" * 40,
    ".": "f" * 40,
}


def test_updates_primary_secondary_and_common_refs(tmp_path):
    (tmp_path / "packaging/rpm").mkdir(parents=True)
    (tmp_path / "admirald").mkdir()
    (tmp_path / "admiral-fleet").mkdir()
    (tmp_path / "admiralctl").mkdir()
    (tmp_path / "admiral-flagship").mkdir()
    (tmp_path / "admiral-harbor").mkdir()

    (tmp_path / "Makefile").write_text(
        "\n".join(
            [
                f"{variable} := {OLD}"
                for variable in (
                    "ADMIRAL_COMMON_COMMIT",
                    "ADMIRALD_COMMIT",
                    "FLEET_COMMIT",
                    "ADMIRALCTL_COMMIT",
                    "FLAGSHIP_COMMIT",
                    "HARBOR_COMMIT",
                )
            ]
        )
        + "\n"
    )
    component_specs = {
        "admirald": "admirald",
        "admiral-fleet": "admiral-fleet",
        "admiralctl": "admiralctl",
        "admiral-flagship": "admiral-flagship",
        "admiral-harbor": "admiral-harbor",
    }
    for name, spec in component_specs.items():
        (tmp_path / "packaging/rpm" / f"{spec}.spec").write_text(
            f"%global commit {OLD}\n"
        )
    (tmp_path / "packaging/rpm/admiral-fleet.spec").write_text(
        f"%global commit {OLD}\nSource3: https://github.com/admiral-project/admirald/archive/{OLD}.tar.gz\n"
    )
    (tmp_path / "packaging/rpm/admiralctl.spec").write_text(
        f"%global commit {OLD}\nSource2: https://github.com/admiral-project/admirald/archive/{OLD}.tar.gz\n"
    )
    (tmp_path / "packaging/rpm/admiral-common.spec").write_text(
        f"%global commit {OLD}\n"
    )

    def fake_git_head(path: Path) -> str:
        relative = Path(path).relative_to(tmp_path)
        return NEW["." if relative == Path(".") else str(relative)]

    with (
        patch.object(update_rpm_refs, "ROOT", tmp_path),
        patch.object(update_rpm_refs, "git_head", side_effect=fake_git_head),
    ):
        update_rpm_refs.main()

    makefile = (tmp_path / "Makefile").read_text()
    assert f"ADMIRAL_COMMON_COMMIT := {NEW['.']}" in makefile
    assert f"ADMIRALD_COMMIT := {NEW['admirald']}" in makefile
    for spec in component_specs.values():
        text = (tmp_path / "packaging/rpm" / f"{spec}.spec").read_text()
        name = spec if spec != "admiral-fleet" else "admiral-fleet"
        assert f"%global commit {NEW[name]}" in text

    for spec, source in (("admiral-fleet", "Source3"), ("admiralctl", "Source2")):
        text = (tmp_path / "packaging/rpm" / f"{spec}.spec").read_text()
        assert f"{source}: https://github.com/admiral-project/admirald/archive/{NEW['admirald']}.tar.gz" in text
    common = (tmp_path / "packaging/rpm/admiral-common.spec").read_text()
    assert f"%global commit {NEW['.']}" in common
