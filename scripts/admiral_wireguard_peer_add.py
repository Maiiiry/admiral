#!/usr/bin/env python3
"""Add one registered Admiral node as a durable WireGuard hub peer."""

from __future__ import annotations

import fcntl
import ipaddress
import json
import os
import re
import ssl
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Callable

import admiral_wireguard_revoke_peer as wireguard


MAX_RESPONSE_BYTES = 1 << 20
PUBLIC_KEY_PATTERN = re.compile(r"^[A-Za-z0-9+/]{43}=$")
NODE_ID_PATTERN = re.compile(r"^[A-Za-z0-9_.:-]{1,128}$")


def _registered_node(node_id: str, expected_ip: str, environ: dict[str, str]) -> bool:
    base_url = environ.get("ADMIRAL_SERVER_URL", "").rstrip("/")
    ca_file = environ.get("ADMIRAL_TLS_CA_FILE", "")
    token = environ.get("ADMIRAL_INTERNAL_TOKEN") or environ.get("ADMIRAL_ADMIN_TOKEN", "")
    parsed_url = urllib.parse.urlsplit(base_url)
    if parsed_url.scheme != "https" or not parsed_url.netloc or parsed_url.username or parsed_url.password:
        raise wireguard.RevocationError("registered-node verification requires an HTTPS control-plane URL")
    if not ca_file or not Path(ca_file).is_file() or not token:
        raise wireguard.RevocationError("control-plane TLS CA and admin token are required for peer addition")
    url = f"{base_url}/api/v1/nodes/{urllib.parse.quote(node_id, safe='')}"
    request = urllib.request.Request(url, headers={"X-Admiral-Token": token}, method="GET")
    context = ssl.create_default_context(cafile=ca_file)
    try:
        with urllib.request.urlopen(request, context=context, timeout=10) as response:
            if response.status != 200:
                raise wireguard.RevocationError("control plane did not confirm the registered node")
            payload = response.read(MAX_RESPONSE_BYTES + 1)
    except (OSError, urllib.error.URLError, urllib.error.HTTPError) as exc:
        raise wireguard.RevocationError("control plane could not confirm the registered node") from exc
    if len(payload) > MAX_RESPONSE_BYTES:
        raise wireguard.RevocationError("control-plane node response exceeded the size limit")
    try:
        node = json.loads(payload)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise wireguard.RevocationError("control plane returned an invalid node response") from exc
    return node.get("id") == node_id and node.get("wireguard_ip") == expected_ip


def _public_key(text: str) -> str:
    for line in text.splitlines():
        match = re.match(r"^\s*PublicKey\s*=\s*([^#]+)", line, re.IGNORECASE)
        if match:
            return match.group(1).strip()
    return ""


def _peer_allowed_ips(text: str) -> list[str]:
    values: list[str] = []
    for line in text.splitlines():
        match = re.match(r"^\s*AllowedIPs\s*=\s*([^#]+)", line, re.IGNORECASE)
        if match:
            values.extend(item.strip() for item in match.group(1).split(",") if item.strip())
    return values


def _peer_blocks(text: str) -> list[str]:
    lines = text.splitlines(keepends=True)
    headers = [index for index, line in enumerate(lines) if re.match(r"^\s*\[[^]]+\]\s*(?:#.*)?$", line)]
    blocks: list[str] = []
    for position, start in enumerate(headers):
        end = headers[position + 1] if position + 1 < len(headers) else len(lines)
        if re.match(r"^\s*\[Peer\]\s*(?:#.*)?$", lines[start], re.IGNORECASE):
            blocks.append("".join(lines[start:end]))
    return blocks


def _peer_key_for_ip(text: str, target: ipaddress.IPv4Address) -> str:
    match_key = ""
    target_cidr = f"{target}/32"
    for block in _peer_blocks(text):
        allowed = _peer_allowed_ips(block)
        if target_cidr not in allowed:
            continue
        if allowed != [target_cidr]:
            raise wireguard.RevocationError("existing peer has additional AllowedIPs; refusing to alter unrelated routes")
        key = _public_key(block)
        if not key:
            raise wireguard.RevocationError("existing WireGuard peer has no public key")
        if match_key and match_key != key:
            raise wireguard.RevocationError("more than one persistent peer uses the requested WireGuard address")
        match_key = key
    return match_key


def _allowed_for_key(text: str, key: str) -> list[str]:
    matches = [_peer_allowed_ips(block) for block in _peer_blocks(text) if _public_key(block) == key]
    if len(matches) > 1:
        raise wireguard.RevocationError("public key appears in multiple persistent peer sections")
    return matches[0] if matches else []


def _preshared_key(text: str, key: str) -> str:
    values: list[str] = []
    for block in _peer_blocks(text):
        if _public_key(block) != key:
            continue
        values.extend(
            match.group(1).strip()
            for line in block.splitlines()
            if (match := re.match(r"^\s*PresharedKey\s*=\s*([^#]+)", line, re.IGNORECASE))
        )
    if len(set(values)) > 1:
        raise wireguard.RevocationError("persistent peer has conflicting preshared keys")
    return values[0] if values else ""


def _fragment_text(target: ipaddress.IPv4Address, key: str, old_text: str = "", preshared_key: str = "") -> str:
    if old_text:
        old_key = _public_key(old_text)
        old_allowed = _peer_allowed_ips(old_text)
        if old_key != key or old_allowed != [f"{target}/32"]:
            raise wireguard.RevocationError("node peer fragment conflicts with the requested key or address")
        existing_psk = _preshared_key(old_text, key)
        if existing_psk and preshared_key and existing_psk != preshared_key:
            raise wireguard.RevocationError("node peer fragment has a different preshared key")
        if preshared_key and not existing_psk:
            return old_text.rstrip() + f"\nPresharedKey = {preshared_key}\n"
        return old_text if old_text.endswith("\n") else old_text + "\n"
    psk_line = f"PresharedKey = {preshared_key}\n" if preshared_key else ""
    return f"[Peer]\nPublicKey = {key}\nAllowedIPs = {target}/32\n{psk_line}"


def _live_peers(run: wireguard.Runner) -> dict[str, list[str]]:
    result = run(["wg", "show", wireguard.INTERFACE, "allowed-ips"])
    if result.returncode != 0:
        raise wireguard.RevocationError("could not inspect live WireGuard peers")
    peers: dict[str, list[str]] = {}
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) == 2:
            peers[fields[0]] = [item.strip() for item in fields[1].split(",") if item.strip()]
    return peers


def _set_live_peer(target: ipaddress.IPv4Address, key: str, preshared_key: str, run: wireguard.Runner) -> None:
    command = [
        "wg",
        "set",
        wireguard.INTERFACE,
        "peer",
        key,
        "allowed-ips",
        f"{target}/32",
        "persistent-keepalive",
        "25",
    ]
    temporary_name = ""
    if preshared_key:
        descriptor, temporary_name = tempfile.mkstemp(prefix="admiral-wg-psk.", dir="/run")
        try:
            os.fchmod(descriptor, 0o600)
            with os.fdopen(descriptor, "w", encoding="ascii") as stream:
                stream.write(preshared_key + "\n")
                stream.flush()
                os.fsync(stream.fileno())
            command.extend(("preshared-key", temporary_name))
            result = run(command)
        finally:
            if temporary_name:
                Path(temporary_name).unlink(missing_ok=True)
    else:
        result = run(command)
    if result.returncode != 0:
        raise wireguard.RevocationError("WireGuard refused to add the registered peer")


def add_peer(
    node_id: str,
    address: str,
    public_key: str,
    *,
    config: Path = wireguard.CONFIG,
    peer_dir: Path = wireguard.PEER_DIR,
    lock: Path = wireguard.LOCK,
    run: wireguard.Runner = wireguard._run,
    is_registered: Callable[[str, str], bool] | None = None,
) -> bool:
    if not NODE_ID_PATTERN.fullmatch(node_id):
        raise wireguard.RevocationError("node ID contains unsupported characters")
    target = wireguard._parse_target(address)
    if not PUBLIC_KEY_PATTERN.fullmatch(public_key):
        raise wireguard.RevocationError("WireGuard public key is invalid")
    lock.parent.mkdir(parents=True, exist_ok=True)
    try:
        lock_fd = os.open(lock, os.O_CREAT | os.O_RDWR | getattr(os, "O_NOFOLLOW", 0), 0o600)
    except OSError as exc:
        raise wireguard.RevocationError("could not open WireGuard peer lock") from exc
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX)
        verify = is_registered or (lambda item_id, item_ip: _registered_node(item_id, item_ip, os.environ))
        if not verify(node_id, str(target)):
            raise wireguard.RevocationError("node is absent or its WireGuard address changed; no peer was added")

        if config.is_symlink():
            raise wireguard.RevocationError("hub WireGuard configuration must not be a symbolic link")
        try:
            config_text = config.read_text(encoding="utf-8")
        except OSError as exc:
            raise wireguard.RevocationError("hub WireGuard configuration is unavailable") from exc
        interface_present, _ = wireguard._interface_network(target, config_text, run)
        if not interface_present:
            raise wireguard.RevocationError("hub WireGuard interface is not active")
        if config.is_symlink() or not peer_dir.is_dir() or peer_dir.is_symlink():
            raise wireguard.RevocationError("hub WireGuard peer configuration directory is unavailable")
        safe_name = re.sub(r"[^A-Za-z0-9_.-]", "_", node_id)
        fragment = peer_dir / f"{safe_name}.conf"
        if fragment.is_symlink():
            raise wireguard.RevocationError("node peer fragment must not be a symbolic link")
        old_fragment = fragment.read_text(encoding="utf-8") if fragment.exists() else ""

        config_key = _peer_key_for_ip(config_text, target)
        if config_key and config_key != public_key:
            raise wireguard.RevocationError("another persistent WireGuard peer already owns this address")
        config_key_assignment = _allowed_for_key(config_text, public_key)
        if config_key_assignment and config_key_assignment != [f"{target}/32"]:
            raise wireguard.RevocationError("public key already has a different persistent address")
        peer_files: list[tuple[Path, str]] = []
        for path in sorted(peer_dir.glob("*.conf")):
            if path.is_symlink() or not path.is_file():
                continue
            peer_files.append((path, path.read_text(encoding="utf-8")))
        for path, text in peer_files:
            owner_key = _peer_key_for_ip(text, target)
            if owner_key and owner_key != public_key:
                raise wireguard.RevocationError("another durable WireGuard peer already owns this address")
            key_assignment = _allowed_for_key(text, public_key)
            if key_assignment and key_assignment != [f"{target}/32"]:
                raise wireguard.RevocationError("public key already has a different durable address")
            if path != fragment and public_key in text:
                raise wireguard.RevocationError("public key is already stored under a different node fragment")
        preshared_key = _preshared_key(config_text, public_key)
        if not preshared_key:
            for _, text in peer_files:
                preshared_key = _preshared_key(text, public_key)
                if preshared_key:
                    break
        new_fragment = _fragment_text(target, public_key, old_fragment, preshared_key)
        fragment_changed = new_fragment != old_fragment

        live = _live_peers(run)
        for key, allowed in live.items():
            if key == public_key:
                if allowed != [f"{target}/32"]:
                    raise wireguard.RevocationError("live WireGuard key has an unexpected AllowedIPs assignment")
            elif f"{target}/32" in allowed:
                raise wireguard.RevocationError("another live WireGuard peer already owns this address")
        if fragment_changed:
            wireguard._atomic_replace(fragment, new_fragment) if fragment.exists() else _create_fragment(fragment, new_fragment)
        config_changed = False
        if not config_key:
            psk_line = f"PresharedKey = {preshared_key}\n" if preshared_key else ""
            addition = f"\n# ADMIRAL WORKER PEER {safe_name}\n[Peer]\nPublicKey = {public_key}\nAllowedIPs = {target}/32\n{psk_line}"
            wireguard._atomic_replace(config, config_text.rstrip() + addition)
            config_changed = True
        if public_key not in live:
            _set_live_peer(target, public_key, preshared_key, run)
        return fragment_changed or config_changed or public_key not in live
    finally:
        os.close(lock_fd)


def _create_fragment(path: Path, content: str) -> None:
    descriptor = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY | getattr(os, "O_NOFOLLOW", 0), 0o600)
    with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as stream:
        stream.write(content)
        stream.flush()
        os.fsync(stream.fileno())
    directory_fd = os.open(path.parent, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
    try:
        os.fsync(directory_fd)
    finally:
        os.close(directory_fd)


def main(argv: list[str]) -> int:
    if len(argv) != 4:
        print("usage: admiral-wireguard-peer-add NODE_ID WG_IPV4 PUBLIC_KEY", file=sys.stderr)
        return 2
    try:
        changed = add_peer(argv[1], argv[2], argv[3])
    except (wireguard.RevocationError, OSError, subprocess.SubprocessError) as exc:
        print(f"admiral-wireguard-peer-add: {exc}", file=sys.stderr)
        return 1
    print("changed" if changed else "unchanged")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
