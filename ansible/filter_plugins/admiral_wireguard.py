"""Ansible filters for deriving the Admiral WireGuard hub address."""

from __future__ import annotations

import ipaddress


def wireguard_hub_ip(subnet: str) -> str:
    """Return the first IPv4 address in a WireGuard subnet for the hub."""
    try:
        network = ipaddress.ip_network(str(subnet), strict=False)
    except ValueError as exc:
        raise ValueError(f"invalid Admiral WireGuard subnet {subnet!r}: {exc}") from exc

    if network.version != 4:
        raise ValueError(f"Admiral WireGuard subnet must be IPv4, got {network.version}")
    private_networks = (
        ipaddress.ip_network("10.0.0.0/8"),
        ipaddress.ip_network("172.16.0.0/12"),
        ipaddress.ip_network("192.168.0.0/16"),
    )
    if not any(network.subnet_of(private) for private in private_networks):
        raise ValueError("Admiral WireGuard subnet must be inside an RFC1918 private range")
    if network.num_addresses < 2:
        raise ValueError("Admiral WireGuard subnet must contain a hub and at least one peer address")

    return str(network.network_address + 1)


class FilterModule:
    def filters(self) -> dict[str, object]:
        return {"wireguard_hub_ip": wireguard_hub_ip}
