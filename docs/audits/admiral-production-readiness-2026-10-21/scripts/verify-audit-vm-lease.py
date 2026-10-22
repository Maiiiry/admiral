#!/usr/bin/env python3
"""Wait for an audit guest DHCP lease and reject an unexpected address."""

from __future__ import annotations

import argparse
import ipaddress
import re
import subprocess
import sys
import time


MAC_RE = re.compile(r"^(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$")


def lease_addresses(output: str, mac: str) -> list[str]:
    wanted = mac.lower()
    addresses: list[str] = []
    for line in output.splitlines():
        fields = line.split()
        for index, field in enumerate(fields):
            if field.lower() != wanted or index + 2 >= len(fields):
                continue
            try:
                address = ipaddress.ip_interface(fields[index + 2]).ip
            except ValueError:
                continue
            addresses.append(str(address))
            break
    return addresses


def verify_lease(output: str, mac: str, requested_ip: str) -> tuple[bool, str]:
    addresses = lease_addresses(output, mac)
    if not addresses:
        return False, f"no DHCP lease found for MAC {mac}"
    if requested_ip in addresses:
        return True, f"DHCP lease verified: {mac} -> {requested_ip}"
    actual = ", ".join(addresses)
    return (
        False,
        f"DHCP address mismatch for MAC {mac}: requested {requested_ip}, actual {actual}",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--network", required=True)
    parser.add_argument("--mac", required=True)
    parser.add_argument("--requested-ip", required=True)
    parser.add_argument("--timeout", type=int, default=90)
    parser.add_argument("--interval", type=float, default=3)
    args = parser.parse_args()
    if not MAC_RE.fullmatch(args.mac):
        parser.error("invalid MAC address")
    try:
        requested_ip = str(ipaddress.ip_address(args.requested_ip))
    except ValueError:
        parser.error("invalid requested IP address")
    if args.timeout < 0 or args.interval <= 0:
        parser.error("timeout must be nonnegative and interval must be positive")

    deadline = time.monotonic() + args.timeout
    last_output = ""
    while True:
        result = subprocess.run(
            ["virsh", "net-dhcp-leases", args.network, "--mac", args.mac],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            print(result.stderr.strip() or "virsh net-dhcp-leases failed", file=sys.stderr)
            return result.returncode
        last_output = result.stdout
        addresses = lease_addresses(last_output, args.mac)
        if addresses:
            ok, message = verify_lease(last_output, args.mac, requested_ip)
            print(message)
            if not ok:
                print(
                    "Guest artifacts are retained for inspection. The guest was not "
                    "contacted; stop it, remove the stale DHCP lease/reservation, and "
                    "retry with a free address. Do not disable SSH host-key checking.",
                    file=sys.stderr,
                )
                return 1
            return 0
        if time.monotonic() >= deadline:
            print(
                f"no DHCP lease for {args.mac} after {args.timeout}s; "
                "guest artifacts are retained for inspection",
                file=sys.stderr,
            )
            return 1
        time.sleep(min(args.interval, max(0, deadline - time.monotonic())))


if __name__ == "__main__":
    raise SystemExit(main())
