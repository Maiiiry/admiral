"""Verify audit guests receive host-key pins before first SSH contact."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import stat
import subprocess

import pytest


ROOT = Path(__file__).resolve().parents[1]
HELPER = (
    ROOT
    / "docs/audits/admiral-production-readiness-2026-10-21/scripts/prepare-audit-cloud-init.py"
)
CREATE_SCRIPT = (
    ROOT
    / "docs/audits/admiral-production-readiness-2026-10-21/scripts/create-audit-vm.sh"
)
LEASE_HELPER = (
    ROOT
    / "docs/audits/admiral-production-readiness-2026-10-21/scripts/verify-audit-vm-lease.py"
)
R53_REBOOT_SCRIPT = (
    ROOT
    / "docs/audits/admiral-production-readiness-2026-10-21/scripts/r53/r53-host-reboot.sh"
)
SPEC = importlib.util.spec_from_file_location("prepare_audit_cloud_init", HELPER)
assert SPEC and SPEC.loader
prepare_audit_cloud_init = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(prepare_audit_cloud_init)
LEASE_SPEC = importlib.util.spec_from_file_location("verify_audit_vm_lease", LEASE_HELPER)
assert LEASE_SPEC and LEASE_SPEC.loader
verify_audit_vm_lease = importlib.util.module_from_spec(LEASE_SPEC)
LEASE_SPEC.loader.exec_module(verify_audit_vm_lease)


def generate_validator_key(directory: Path) -> Path:
    private_key = directory / "validator"
    subprocess.run(
        ["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(private_key)],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return private_key.with_suffix(".pub")


def test_host_key_is_pre_pinned_for_nat_and_private_underlay_before_network_use(tmp_path):
    validator_public_key = generate_validator_key(tmp_path)
    guest_directory = tmp_path / "cloud-init" / "audit-worker"

    known_hosts, host_public_key = prepare_audit_cloud_init.prepare_guest_files(
        guest_directory,
        "audit-worker",
        "192.168.122.246",
        "52:54:00:aa:bb:01",
        "10.77.0.11",
        "52:54:00:aa:bb:02",
        validator_public_key,
    )

    private_key = guest_directory / "ssh_host_ed25519_key"
    private_text = private_key.read_text(encoding="utf-8")
    public_line = host_public_key.read_text(encoding="utf-8").split()
    derived_public = subprocess.run(
        ["ssh-keygen", "-y", "-f", str(private_key)],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.split()
    assert derived_public[:2] == public_line[:2]

    assert stat.S_IMODE(guest_directory.stat().st_mode) == 0o700
    private_paths = (
        private_key,
        guest_directory / "user-data",
        guest_directory / "meta-data",
        known_hosts,
    )
    for path in private_paths:
        assert stat.S_IMODE(path.stat().st_mode) == 0o600
    assert stat.S_IMODE(host_public_key.stat().st_mode) == 0o644

    expected_hosts = {
        f"192.168.122.246 ssh-ed25519 {public_line[1]}",
        f"10.77.0.11 ssh-ed25519 {public_line[1]}",
    }
    pin_lines = set(known_hosts.read_text(encoding="utf-8").splitlines())
    assert pin_lines == expected_hosts
    assert private_text not in known_hosts.read_text(encoding="utf-8")

    cloud_config = (guest_directory / "user-data").read_text(encoding="utf-8")
    assert "ssh_deletekeys: true" in cloud_config
    assert "ssh_keys:" in cloud_config
    assert "ed25519_private: |" in cloud_config
    assert "ed25519_public:" in cloud_config
    private_block = cloud_config.split("  ed25519_private: |\n", 1)[1].split(
        "\n  ed25519_public:", 1
    )[0]
    rendered_private = "\n".join(line[4:] for line in private_block.splitlines())
    assert rendered_private == private_text.rstrip()
    assert "ssh_publish_hostkeys: {enabled: false}" in cloud_config

    network_config = (guest_directory / "network-config").read_text(encoding="utf-8")
    assert "192.168.122.246" not in network_config
    assert "10.77.0.11/24" in network_config
    assert "10.99.0.2" not in network_config


def test_single_network_guest_gets_only_nat_host_pin(tmp_path):
    validator_public_key = generate_validator_key(tmp_path)
    guest_directory = tmp_path / "cloud-init" / "audit-single"

    known_hosts, host_public_key = prepare_audit_cloud_init.prepare_guest_files(
        guest_directory,
        "audit-single",
        "192.168.122.247",
        "52:54:00:aa:bb:03",
        "",
        "",
        validator_public_key,
    )

    public_line = host_public_key.read_text(encoding="utf-8").split()
    assert known_hosts.read_text(encoding="utf-8").splitlines() == [
        f"192.168.122.247 ssh-ed25519 {public_line[1]}"
    ]
    assert not (guest_directory / "network-config").exists()


def test_existing_cloud_init_directory_is_never_overwritten(tmp_path):
    validator_public_key = generate_validator_key(tmp_path)
    guest_directory = tmp_path / "cloud-init" / "audit-existing"
    guest_directory.mkdir(parents=True)
    sentinel = guest_directory / "operator-data"
    sentinel.write_text("preserve", encoding="utf-8")

    with pytest.raises(FileExistsError):
        prepare_audit_cloud_init.prepare_guest_files(
            guest_directory,
            "audit-existing",
            "192.168.122.248",
            "52:54:00:aa:bb:04",
            "",
            "",
            validator_public_key,
        )

    assert sentinel.read_text(encoding="utf-8") == "preserve"


def test_invalid_guest_identity_is_rejected_before_creating_files(tmp_path):
    validator_public_key = generate_validator_key(tmp_path)
    guest_directory = tmp_path / "cloud-init" / "../outside"

    with pytest.raises(ValueError, match="invalid guest name"):
        prepare_audit_cloud_init.prepare_guest_files(
            guest_directory,
            "../outside",
            "192.168.122.249",
            "52:54:00:aa:bb:05",
            "",
            "",
            validator_public_key,
        )

    assert not guest_directory.exists()


def test_cloud_init_iso_keeps_private_source_modes():
    script = CREATE_SCRIPT.read_text(encoding="utf-8")
    iso_command = next(
        line for line in script.splitlines() if "xorriso -as mkisofs" in line
    )

    assert " -r " not in f" {iso_command} "
    assert 'chmod 0600 "$iso"' in script


def test_create_helper_names_private_nic_as_underlay_not_wireguard():
    script = CREATE_SCRIPT.read_text(encoding="utf-8")
    cloud_init = HELPER.read_text(encoding="utf-8")

    assert "[PRIVATE_IP PRIVATE_MAC]" in script
    assert '"$private_ip"' in script
    assert '"$private_mac"' in script
    assert "--private-ip" in script
    assert "--private-mac" in script
    assert "wg_ip" not in script
    assert 'parser.add_argument("--wg-ip"' not in cloud_init


def test_create_helper_checks_the_actual_dhcp_lease_before_reporting_success():
    script = CREATE_SCRIPT.read_text(encoding="utf-8")
    assert "verify-audit-vm-lease.py" in script
    assert script.index("virt-install") < script.index("verify-audit-vm-lease.py")
    assert script.index("verify-audit-vm-lease.py") < script.index("printf 'Created")


def test_expected_static_dhcp_lease_is_accepted():
    output = """Expiry Time MAC address Protocol IP address Hostname Client ID
2026-10-22 13:28:15 52:54:00:53:00:01 ipv4 192.168.122.252/24 adm-r53-fedora-single 01:52:54:00:53:00:01
"""
    assert verify_audit_vm_lease.verify_lease(
        output, "52:54:00:53:00:01", "192.168.122.252"
    ) == (True, "DHCP lease verified: 52:54:00:53:00:01 -> 192.168.122.252")


def test_conflicting_stale_lease_is_rejected_with_actual_address():
    output = """Expiry Time MAC address Protocol IP address Hostname Client ID
2026-10-22 13:28:15 52:54:00:53:00:01 ipv4 192.168.122.233/24 adm-r53-fedora-single 01:52:54:00:53:00:01
"""
    valid, message = verify_audit_vm_lease.verify_lease(
        output, "52:54:00:53:00:01", "192.168.122.252"
    )
    assert not valid
    assert message == (
        "DHCP address mismatch for MAC 52:54:00:53:00:01: "
        "requested 192.168.122.252, actual 192.168.122.233"
    )


def test_missing_dhcp_lease_does_not_become_a_false_success():
    valid, message = verify_audit_vm_lease.verify_lease(
        "No leases found", "52:54:00:53:00:01", "192.168.122.252"
    )
    assert not valid
    assert message == "no DHCP lease found for MAC 52:54:00:53:00:01"


def test_reboot_harness_uses_accessible_working_directory_before_rootless_commands():
    script = R53_REBOOT_SCRIPT.read_text(encoding="utf-8")
    assert script.count("cd /") == 2
    assert script.index("cd /") < script.index("runuser -u admiral-apps")
    assert "systemctl reboot --no-block" in script
    assert 'previous_boot_id=$(ssh_guest' in script
    assert 'current_boot_id != "$previous_boot_id"' in script
