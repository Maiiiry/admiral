#!/usr/bin/env python3
"""Remove one Admiral WireGuard peer from runtime and durable hub state.

This program is started by a root-owned systemd socket unit. It accepts one
IPv4 address on stdin and never prints peer keys or command output.
"""

from __future__ import annotations

import fcntl
import ipaddress
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Callable


INTERFACE = "wg-admiral"
CONFIG = Path("/etc/wireguard/wg-admiral.conf")
PEER_DIR = Path("/etc/wireguard/peers.d")
LOCK = Path("/run/lock/admiral-wireguard-peer-add.lock")
MAX_REQUEST_BYTES = 128
COMMAND_TIMEOUT_SECONDS = 10


class RevocationError(RuntimeError):
    """A peer could not be safely revoked."""


Runner = Callable[..., subprocess.CompletedProcess[str]]


def _run(command: list[str]) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            timeout=COMMAND_TIMEOUT_SECONDS,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise RevocationError(f"could not run {Path(command[0]).name}") from exc


def _parse_target(value: str) -> ipaddress.IPv4Address:
    try:
        target = ipaddress.ip_address(value)
    except ValueError as exc:
        raise RevocationError("WireGuard peer address is invalid") from exc
    if (
        not isinstance(target, ipaddress.IPv4Address)
        or target.is_unspecified
        or target.is_loopback
        or target.is_multicast
        or target.is_link_local
    ):
        raise RevocationError("WireGuard peer address must be a unicast IPv4 address")
    return target


def _interface_network(
    target: ipaddress.IPv4Address,
    config_text: str,
    run: Runner,
) -> tuple[bool, ipaddress.IPv4Network]:
    result = run(["ip", "-o", "-4", "addr", "show", "dev", INTERFACE])
    interface_present = result.returncode == 0
    if not interface_present:
        listed = run(["wg", "show", "interfaces"])
        if listed.returncode != 0:
            raise RevocationError("could not determine whether the hub WireGuard interface is active")
        if INTERFACE in listed.stdout.split():
            raise RevocationError("could not inspect the active hub WireGuard address")
    candidates: list[str] = []
    if interface_present:
        candidates.extend(re.findall(r"\binet\s+(\d+(?:\.\d+){3}/\d+)\b", result.stdout))
    if not candidates:
        candidates.extend(re.findall(r"(?m)^\s*Address\s*=\s*(\d+(?:\.\d+){3}/\d+)\s*$", config_text))
    for candidate in candidates:
        try:
            network = ipaddress.ip_interface(candidate).network
        except ValueError:
            continue
        if target in network:
            if any(ipaddress.ip_interface(item).ip == target for item in candidates if _valid_interface(item)):
                raise RevocationError("refusing to revoke the hub interface address")
            return interface_present, network
    raise RevocationError("peer address is outside the configured WireGuard subnet")


def _valid_interface(value: str) -> bool:
    try:
        ipaddress.ip_interface(value)
    except ValueError:
        return False
    return True


def _peer_sections(text: str) -> list[tuple[int, int, list[str]]]:
    lines = text.splitlines(keepends=True)
    headers = [index for index, line in enumerate(lines) if re.match(r"^\s*\[[^]]+\]\s*(?:#.*)?$", line)]
    sections: list[tuple[int, int, list[str]]] = []
    for position, start in enumerate(headers):
        end = headers[position + 1] if position + 1 < len(headers) else len(lines)
        if re.match(r"^\s*\[Peer\]\s*(?:#.*)?$", lines[start], re.IGNORECASE):
            sections.append((start, end, lines))
    return sections


def _section_matches_peer(section: list[str], target: ipaddress.IPv4Address) -> bool:
    values: list[str] = []
    for line in section:
        if re.match(r"^\s*\[Peer\]\s*(?:#.*)?$", line, re.IGNORECASE):
            continue
        match = re.match(r"^\s*AllowedIPs\s*=\s*([^#]+)", line, re.IGNORECASE)
        if match:
            values.append(match.group(1).strip())
    if not values:
        return False
    entries = [entry.strip() for value in values for entry in value.split(",") if entry.strip()]
    networks: list[ipaddress.IPv4Network | ipaddress.IPv6Network] = []
    try:
        networks = [ipaddress.ip_network(entry, strict=False) for entry in entries]
    except ValueError as exc:
        raise RevocationError("WireGuard peer configuration has an invalid AllowedIPs value") from exc
    matches = [network for network in networks if network.version == 4 and target in network]
    if not matches:
        return False
    if len(networks) != 1 or len(matches) != 1 or matches[0] != ipaddress.ip_network(f"{target}/32"):
        raise RevocationError("peer has additional AllowedIPs; refusing to remove unrelated routes")
    return True


def _remove_peer_sections(text: str, target: ipaddress.IPv4Address) -> tuple[str, int]:
    lines = text.splitlines(keepends=True)
    remove: set[int] = set()
    removed = 0
    headers = [index for index, line in enumerate(lines) if re.match(r"^\s*\[[^]]+\]\s*(?:#.*)?$", line)]
    for position, start in enumerate(headers):
        end = headers[position + 1] if position + 1 < len(headers) else len(lines)
        if not re.match(r"^\s*\[Peer\]\s*(?:#.*)?$", lines[start], re.IGNORECASE):
            continue
        if not _section_matches_peer(lines[start:end], target):
            continue
        section_start = start
        if start > 0 and re.match(r"^\s*#\s*ADMIRAL WORKER PEER\b", lines[start - 1], re.IGNORECASE):
            section_start -= 1
        remove.update(range(section_start, end))
        removed += 1
    return "".join(line for index, line in enumerate(lines) if index not in remove), removed


def _atomic_replace(path: Path, content: str) -> None:
    metadata = path.stat(follow_symlinks=False)
    if not stat.S_ISREG(metadata.st_mode):
        raise RevocationError(f"refusing to edit non-regular WireGuard configuration {path.name}")
    if metadata.st_uid != os.geteuid() or metadata.st_gid != os.getegid():
        raise RevocationError(f"WireGuard configuration {path.name} is not owned by the helper user")
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.revoke.", dir=path.parent)
    temporary = Path(temporary_name)
    try:
        os.fchmod(descriptor, stat.S_IMODE(metadata.st_mode))
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        directory_fd = os.open(path.parent, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    except Exception:
        try:
            temporary.unlink(missing_ok=True)
        except OSError:
            pass
        raise


def _update_persistent_config(target: ipaddress.IPv4Address, config: Path, peer_dir: Path) -> int:
    paths: list[Path] = []
    if config.exists():
        if config.is_symlink():
            raise RevocationError("hub WireGuard configuration must not be a symbolic link")
        paths.append(config)
    if peer_dir.exists():
        paths.extend(sorted(peer_dir.glob("*.conf")))
    changes: list[tuple[Path, str, int]] = []
    total_removed = 0
    for path in paths:
        if path.is_symlink():
            continue
        if not path.is_file():
            continue
        try:
            original = path.read_text(encoding="utf-8")
        except OSError as exc:
            raise RevocationError(f"could not read WireGuard configuration {path.name}") from exc
        updated, removed = _remove_peer_sections(original, target)
        if removed:
            changes.append((path, updated, removed))
            total_removed += removed
    for path, updated, _ in changes:
        if path.parent == peer_dir and not any(line.strip() and not line.lstrip().startswith("#") for line in updated.splitlines()):
            path.unlink()
            directory_fd = os.open(path.parent, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
            try:
                os.fsync(directory_fd)
            finally:
                os.close(directory_fd)
        else:
            _atomic_replace(path, updated)
    return total_removed


def _live_peer_keys(target: ipaddress.IPv4Address, run: Runner) -> list[str]:
    result = run(["wg", "show", INTERFACE, "allowed-ips"])
    if result.returncode != 0:
        raise RevocationError("could not inspect live WireGuard peers")
    keys: list[str] = []
    target_cidr = f"{target}/32"
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) != 2:
            continue
        if fields[1] == "(none)":
            continue
        allowed = [item.strip() for item in fields[1].split(",") if item.strip()]
        routes: list[ipaddress.IPv4Network | ipaddress.IPv6Network] = []
        try:
            routes = [ipaddress.ip_network(item, strict=False) for item in allowed]
        except ValueError as exc:
            raise RevocationError("live WireGuard peer has an invalid AllowedIPs value") from exc
        matching = [route for route in routes if route.version == 4 and target in route]
        if matching:
            if len(routes) != 1 or len(matching) != 1 or str(matching[0]) != target_cidr:
                raise RevocationError("live peer has additional AllowedIPs; refusing to remove unrelated routes")
            keys.append(fields[0])
    return keys


def _revoke_peer_locked(
    value: str,
    *,
    config: Path = CONFIG,
    peer_dir: Path = PEER_DIR,
    lock: Path = LOCK,
    run: Runner = _run,
) -> tuple[dict[str, object], int]:
    target = _parse_target(value)
    if config.is_symlink():
        raise RevocationError("hub WireGuard configuration must not be a symbolic link")
    try:
        config_text = config.read_text(encoding="utf-8")
    except OSError as exc:
        raise RevocationError("hub WireGuard configuration is unavailable") from exc

    interface_present, _ = _interface_network(target, config_text, run)
    lock.parent.mkdir(parents=True, exist_ok=True)
    try:
        lock_fd = os.open(lock, os.O_CREAT | os.O_RDWR | getattr(os, "O_NOFOLLOW", 0), 0o600)
    except OSError as exc:
        raise RevocationError("could not open WireGuard peer lock") from exc
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX)
        live_keys = _live_peer_keys(target, run) if interface_present else []
        persistent_removed = _update_persistent_config(target, config, peer_dir)
        live_removed = 0
        if interface_present:
            for key in live_keys:
                result = run(["wg", "set", INTERFACE, "peer", key, "remove"])
                if result.returncode != 0:
                    raise RevocationError("WireGuard refused to remove the live peer")
                live_removed += 1
            if _live_peer_keys(target, run):
                raise RevocationError("WireGuard peer remained active after revocation")
        return {
            "success": True,
            "wireguard_ip": str(target),
            "live_peers_removed": live_removed,
            "persistent_peer_entries_removed": persistent_removed,
        }, lock_fd
    except Exception:
        os.close(lock_fd)
        raise


def revoke_peer(
    value: str,
    *,
    config: Path = CONFIG,
    peer_dir: Path = PEER_DIR,
    lock: Path = LOCK,
    run: Runner = _run,
) -> dict[str, object]:
    response, lock_fd = _revoke_peer_locked(
        value,
        config=config,
        peer_dir=peer_dir,
        lock=lock,
        run=run,
    )
    os.close(lock_fd)
    return response


def main() -> int:
    raw = sys.stdin.buffer.readline(MAX_REQUEST_BYTES + 1)
    lock_fd = None
    if len(raw) > MAX_REQUEST_BYTES or not raw.endswith(b"\n"):
        response = {"success": False, "error": "request must be one short IPv4 address line"}
    else:
        try:
            value = raw.decode("ascii").strip()
            response, lock_fd = _revoke_peer_locked(value)
        except (UnicodeDecodeError, RevocationError, OSError) as exc:
            response = {"success": False, "error": str(exc)}
    try:
        sys.stdout.write(json.dumps(response, separators=(",", ":")) + "\n")
        sys.stdout.flush()
        if response.get("success"):
            # Keep the peer lock until the caller's database transaction has
            # committed and it closes the accepted socket.
            sys.stdin.buffer.read()
        return 0 if response.get("success") else 1
    finally:
        if lock_fd is not None:
            os.close(lock_fd)


if __name__ == "__main__":
    raise SystemExit(main())
