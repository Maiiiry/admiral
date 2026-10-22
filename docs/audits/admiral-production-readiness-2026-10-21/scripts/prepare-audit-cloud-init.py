#!/usr/bin/env python3
"""Create a guest's protected cloud-init files and trusted SSH host-key pin."""

from __future__ import annotations

import argparse
import ipaddress
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


GUEST_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9-]{0,62}$")
MAC_ADDRESS = re.compile(r"^(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$")
PRIVATE_MODE = 0o600


def _validate_ipv4(value: str, label: str) -> None:
    try:
        address = ipaddress.ip_address(value)
    except ValueError as exc:
        raise ValueError(f"invalid {label}: {value}") from exc
    if address.version != 4:
        raise ValueError(f"{label} must be IPv4: {value}")


def _write_private(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")
    os.chmod(path, PRIVATE_MODE)


def prepare_guest_files(
    directory: Path,
    name: str,
    nat_ip: str,
    nat_mac: str,
    wg_ip: str,
    wg_mac: str,
    validator_public_key_file: Path,
) -> tuple[Path, Path]:
    """Generate a unique host key, cloud-init material, and known_hosts pin.

    The private host key is generated locally, readable only by root, and
    passed to the guest through a mode-0600 NoCloud ISO. The known_hosts file
    contains only the public key and can be used for strict SSH before the
    first network connection.
    """
    if not GUEST_NAME.fullmatch(name):
        raise ValueError(f"invalid guest name: {name!r}")
    _validate_ipv4(nat_ip, "NAT address")
    if not MAC_ADDRESS.fullmatch(nat_mac):
        raise ValueError(f"invalid NAT MAC address: {nat_mac}")
    if bool(wg_ip) != bool(wg_mac):
        raise ValueError("private IPv4 and MAC must be supplied together")
    if wg_ip:
        _validate_ipv4(wg_ip, "private address")
        if not MAC_ADDRESS.fullmatch(wg_mac):
            raise ValueError(f"invalid private MAC address: {wg_mac}")

    validator_key = validator_public_key_file.read_text(encoding="utf-8").strip()
    validator_fields = validator_key.split()
    if len(validator_fields) < 2 or not validator_fields[0].startswith(
        ("ssh-", "ecdsa-", "sk-")
    ):
        raise ValueError("unsupported SSH validator public key")

    if directory.exists() or directory.is_symlink():
        raise FileExistsError(f"guest cloud-init directory already exists: {directory}")
    directory.mkdir(parents=True, mode=0o700)
    os.chmod(directory, 0o700)
    try:
        private_path = directory / "ssh_host_ed25519_key"
        subprocess.run(
            [
                "ssh-keygen",
                "-q",
                "-t",
                "ed25519",
                "-N",
                "",
                "-C",
                f"admiral-audit-{name}",
                "-f",
                str(private_path),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )
        os.chmod(private_path, PRIVATE_MODE)
        public_path = directory / "ssh_host_ed25519_key.pub"
        os.chmod(public_path, 0o644)
        host_key_fields = public_path.read_text(encoding="utf-8").split()
        if len(host_key_fields) < 2 or host_key_fields[0] != "ssh-ed25519":
            raise ValueError("ssh-keygen did not create an Ed25519 host key")
        public_host_key = " ".join(host_key_fields[:2])

        private_lines = (
            private_path.read_text(encoding="utf-8").rstrip("\n").splitlines()
        )
        user_lines = [
            "#cloud-config",
            "ssh_deletekeys: true",
            "ssh_keys:",
            "  ed25519_private: |",
            *(f"    {line}" for line in private_lines),
            f"  ed25519_public: {json.dumps(public_host_key)}",
            "ssh_publish_hostkeys: {enabled: false}",
            "ssh_pwauth: false",
            "disable_root: true",
            "users:",
            "  - default",
            "  - name: validator",
            "    gecos: Admiral production audit",
            "    groups: [wheel]",
            "    shell: /bin/bash",
            "    sudo: ['ALL=(ALL) NOPASSWD:ALL']",
            "    ssh_authorized_keys:",
            f"      - {json.dumps(validator_key)}",
            "write_files:",
            "  - path: /tmp/admiral-validator.pub",
            "    owner: root:root",
            "    permissions: '0600'",
            "    content: |",
            f"      {validator_key}",
            "runcmd:",
            "  - [install, -D, -o, validator, -g, validator, -m, '0644', /tmp/admiral-validator.pub, /home/validator/validator.pub]",
            "  - [rm, -f, /tmp/admiral-validator.pub]",
        ]
        _write_private(directory / "user-data", "\n".join(user_lines) + "\n")
        _write_private(
            directory / "meta-data",
            f"instance-id: {name}\nlocal-hostname: {name}\n",
        )

        addresses = [nat_ip]
        if wg_ip:
            addresses.append(wg_ip)
            network_lines = [
                "version: 2",
                "renderer: NetworkManager",
                "ethernets:",
                "  nat:",
                "    match:",
                f"      macaddress: '{nat_mac.lower()}'",
                "    dhcp4: true",
                "    dhcp6: false",
                "  private:",
                "    match:",
                f"      macaddress: '{wg_mac.lower()}'",
                "    dhcp4: false",
                "    dhcp6: false",
                "    addresses:",
                f"      - {wg_ip}/24",
            ]
            _write_private(
                directory / "network-config", "\n".join(network_lines) + "\n"
            )

        known_hosts_path = directory / "known_hosts"
        known_hosts = "".join(f"{address} {public_host_key}\n" for address in addresses)
        _write_private(known_hosts_path, known_hosts)
        return known_hosts_path, public_path
    except Exception:
        shutil.rmtree(directory)
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--nat-ip", required=True)
    parser.add_argument("--nat-mac", required=True)
    parser.add_argument("--wg-ip", default="")
    parser.add_argument("--wg-mac", default="")
    parser.add_argument("--validator-public-key", type=Path, required=True)
    args = parser.parse_args()

    try:
        known_hosts, public_key = prepare_guest_files(
            args.directory,
            args.name,
            args.nat_ip,
            args.nat_mac,
            args.wg_ip,
            args.wg_mac,
            args.validator_public_key,
        )
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        detail = (
            exc.stderr.strip()
            if isinstance(exc, subprocess.CalledProcessError)
            else str(exc)
        )
        print(f"cannot prepare trusted SSH host key: {detail}", file=sys.stderr)
        return 1

    fingerprint = subprocess.run(
        ["ssh-keygen", "-lf", str(public_key), "-E", "sha256"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.split()
    print(f"known_hosts_file={known_hosts}")
    print(f"host_key_fingerprint={fingerprint[1]}")
    print("host_key_private_material=protected-cloud-init-only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
