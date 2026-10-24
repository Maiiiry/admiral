#!/usr/bin/env python3
"""Unit tests for the privileged WireGuard peer revocation helper."""

from __future__ import annotations

import importlib.util
import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "admiral_wireguard_revoke_peer", ROOT / "scripts" / "admiral_wireguard_revoke_peer.py"
)
assert SPEC is not None and SPEC.loader is not None
HELPER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(HELPER)


class WireGuardPeerRevokeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temp_dir.name)
        self.config = self.root / "wg-admiral.conf"
        self.peer_dir = self.root / "peers.d"
        self.peer_dir.mkdir()
        self.lock = self.root / "run" / "admiral-wireguard-peer-add.lock"
        self.config.write_text(
            "[Interface]\nAddress = 10.99.0.1/24\nPrivateKey = hidden\n\n"
            "# ADMIRAL WORKER PEER worker-001\n[Peer]\n"
            "PublicKey = public-key-worker-001\nAllowedIPs = 10.99.0.3/32\n",
            encoding="utf-8",
        )
        (self.peer_dir / "worker-001.conf").write_text(
            "[Peer]\nPublicKey = public-key-worker-001\nAllowedIPs = 10.99.0.3/32\n",
            encoding="utf-8",
        )
        self.live_peers = {"public-key-worker-001": "10.99.0.3/32"}
        self.commands: list[list[str]] = []

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def runner(self, command: list[str], **_kwargs: object) -> subprocess.CompletedProcess[str]:
        self.commands.append(command)
        if command[:5] == ["ip", "-o", "-4", "addr", "show"]:
            return subprocess.CompletedProcess(command, 0, "2: wg-admiral inet 10.99.0.1/24 scope global wg-admiral\n", "")
        if command == ["wg", "show", "interfaces"]:
            return subprocess.CompletedProcess(command, 0, "wg-admiral\n", "")
        if command == ["wg", "show", "wg-admiral", "allowed-ips"]:
            rows = "".join(f"{key}\t{value}\n" for key, value in self.live_peers.items())
            return subprocess.CompletedProcess(command, 0, rows, "")
        if command[:3] == ["wg", "set", "wg-admiral"]:
            key = command[4]
            self.live_peers.pop(key, None)
            return subprocess.CompletedProcess(command, 0, "", "")
        raise AssertionError(f"unexpected command: {command}")

    def test_revokes_live_and_persistent_peer_idempotently(self) -> None:
        result = HELPER.revoke_peer(
            "10.99.0.3",
            config=self.config,
            peer_dir=self.peer_dir,
            lock=self.lock,
            run=self.runner,
        )

        self.assertEqual(result["live_peers_removed"], 1)
        self.assertEqual(result["persistent_peer_entries_removed"], 2)
        self.assertNotIn("10.99.0.3/32", self.config.read_text(encoding="utf-8"))
        self.assertFalse((self.peer_dir / "worker-001.conf").exists())
        self.assertEqual(self.live_peers, {})
        self.assertTrue(self.lock.exists())

        second = HELPER.revoke_peer(
            "10.99.0.3",
            config=self.config,
            peer_dir=self.peer_dir,
            lock=self.lock,
            run=self.runner,
        )
        self.assertEqual(second["live_peers_removed"], 0)
        self.assertEqual(second["persistent_peer_entries_removed"], 0)

    def test_refuses_a_peer_with_additional_routes_without_mutating_state(self) -> None:
        self.config.write_text(
            "[Interface]\nAddress = 10.99.0.1/24\nPrivateKey = hidden\n\n"
            "[Peer]\nPublicKey = public-key-worker-001\n"
            "AllowedIPs = 10.99.0.3/32, 10.88.0.0/16\n",
            encoding="utf-8",
        )
        before = self.config.read_text(encoding="utf-8")

        with self.assertRaisesRegex(HELPER.RevocationError, "additional AllowedIPs"):
            HELPER.revoke_peer(
                "10.99.0.3",
                config=self.config,
                peer_dir=self.peer_dir,
                lock=self.lock,
                run=self.runner,
            )

        self.assertEqual(self.config.read_text(encoding="utf-8"), before)
        self.assertEqual(self.live_peers, {"public-key-worker-001": "10.99.0.3/32"})
        self.assertFalse(any(command[:2] == ["wg", "set"] for command in self.commands))

    def test_refuses_a_live_supernet_route_before_mutating_persistent_state(self) -> None:
        self.config.write_text(
            "[Interface]\nAddress = 10.99.0.1/24\nPrivateKey = hidden\n",
            encoding="utf-8",
        )
        (self.peer_dir / "worker-001.conf").unlink()
        self.live_peers["public-key-worker-001"] = "10.99.0.0/24"
        before_config = self.config.read_text(encoding="utf-8")

        with self.assertRaisesRegex(HELPER.RevocationError, "additional AllowedIPs"):
            HELPER.revoke_peer(
                "10.99.0.3",
                config=self.config,
                peer_dir=self.peer_dir,
                lock=self.lock,
                run=self.runner,
            )

        self.assertEqual(self.config.read_text(encoding="utf-8"), before_config)
        self.assertEqual(self.live_peers, {"public-key-worker-001": "10.99.0.0/24"})
        self.assertFalse(any(command[:2] == ["wg", "set"] for command in self.commands))

    def test_ignores_unrelated_live_peer_without_allowed_ips(self) -> None:
        self.live_peers["public-key-without-routes"] = "(none)"

        result = HELPER.revoke_peer(
            "10.99.0.3",
            config=self.config,
            peer_dir=self.peer_dir,
            lock=self.lock,
            run=self.runner,
        )

        self.assertEqual(result["live_peers_removed"], 1)
        self.assertEqual(self.live_peers, {"public-key-without-routes": "(none)"})

    def test_rejects_non_private_or_non_ipv4_addresses(self) -> None:
        for address in ("203.0.113.5", "10.99.0.1", "2001:db8::1", "not-an-ip"):
            with self.subTest(address=address):
                with self.assertRaises(HELPER.RevocationError):
                    HELPER.revoke_peer(
                        address,
                        config=self.config,
                        peer_dir=self.peer_dir,
                        lock=self.lock,
                        run=self.runner,
                    )

    def test_updates_persistent_state_when_wireguard_is_down(self) -> None:
        def down_runner(command: list[str], **_kwargs: object) -> subprocess.CompletedProcess[str]:
            self.commands.append(command)
            if command[:5] == ["ip", "-o", "-4", "addr", "show"]:
                return subprocess.CompletedProcess(command, 1, "", "Device does not exist")
            if command == ["wg", "show", "interfaces"]:
                return subprocess.CompletedProcess(command, 0, "", "")
            raise AssertionError(f"unexpected command while interface is down: {command}")

        result = HELPER.revoke_peer(
            "10.99.0.3",
            config=self.config,
            peer_dir=self.peer_dir,
            lock=self.lock,
            run=down_runner,
        )

        self.assertEqual(result["live_peers_removed"], 0)
        self.assertEqual(result["persistent_peer_entries_removed"], 2)
        self.assertNotIn("10.99.0.3/32", self.config.read_text(encoding="utf-8"))
        self.assertFalse((self.peer_dir / "worker-001.conf").exists())


if __name__ == "__main__":
    unittest.main()
