#!/usr/bin/env python3
"""Unit tests for race-safe registration and WireGuard peer addition."""

from __future__ import annotations

import importlib.util
import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]


def load_module(name: str, path: pathlib.Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


HELPER = load_module("admiral_wireguard_peer_add", ROOT / "scripts" / "admiral_wireguard_peer_add.py")


class WireGuardPeerAddTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temp_dir.name)
        self.config = self.root / "wg-admiral.conf"
        self.config.write_text("[Interface]\nAddress = 10.99.0.1/24\nPrivateKey = hidden\n", encoding="utf-8")
        self.peer_dir = self.root / "peers.d"
        self.peer_dir.mkdir()
        self.lock = self.root / "run" / "admiral-wireguard-peer-add.lock"
        self.public_key = "A" * 43 + "="
        self.live_peers: dict[str, str] = {}
        self.commands: list[list[str]] = []

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def runner(self, command: list[str], **_kwargs: object) -> subprocess.CompletedProcess[str]:
        self.commands.append(command)
        if command[:5] == ["ip", "-o", "-4", "addr", "show"]:
            return subprocess.CompletedProcess(command, 0, "2: wg-admiral inet 10.99.0.1/24 scope global wg-admiral\n", "")
        if command == ["wg", "show", "wg-admiral", "allowed-ips"]:
            output = "".join(f"{key}\t{allowed}\n" for key, allowed in self.live_peers.items())
            return subprocess.CompletedProcess(command, 0, output, "")
        if command[:3] == ["wg", "set", "wg-admiral"]:
            key = command[4]
            address = command[6]
            self.live_peers[key] = address
            return subprocess.CompletedProcess(command, 0, "", "")
        raise AssertionError(f"unexpected command: {command}")

    def test_adds_registered_peer_to_live_and_persistent_state_idempotently(self) -> None:
        checks: list[tuple[str, str]] = []

        def registered(node_id: str, address: str) -> bool:
            checks.append((node_id, address))
            return node_id == "worker-001" and address == "10.99.0.3"

        changed = HELPER.add_peer(
            "worker-001",
            "10.99.0.3",
            self.public_key,
            config=self.config,
            peer_dir=self.peer_dir,
            lock=self.lock,
            run=self.runner,
            is_registered=registered,
        )

        self.assertTrue(changed)
        self.assertIn(self.public_key, self.config.read_text(encoding="utf-8"))
        self.assertEqual(
            (self.peer_dir / "worker-001.conf").read_text(encoding="utf-8"),
            f"[Peer]\nPublicKey = {self.public_key}\nAllowedIPs = 10.99.0.3/32\n",
        )
        self.assertEqual(self.live_peers, {self.public_key: "10.99.0.3/32"})

        changed = HELPER.add_peer(
            "worker-001",
            "10.99.0.3",
            self.public_key,
            config=self.config,
            peer_dir=self.peer_dir,
            lock=self.lock,
            run=self.runner,
            is_registered=registered,
        )
        self.assertFalse(changed)
        self.assertEqual(checks, [("worker-001", "10.99.0.3")] * 2)

    def test_removed_node_is_not_readded_after_waiting_for_the_shared_lock(self) -> None:
        with self.assertRaisesRegex(HELPER.wireguard.RevocationError, "node is absent"):
            HELPER.add_peer(
                "worker-001",
                "10.99.0.3",
                self.public_key,
                config=self.config,
                peer_dir=self.peer_dir,
                lock=self.lock,
                run=self.runner,
                is_registered=lambda _node_id, _address: False,
            )

        self.assertEqual(self.live_peers, {})
        self.assertNotIn(self.public_key, self.config.read_text(encoding="utf-8"))
        self.assertFalse((self.peer_dir / "worker-001.conf").exists())

    def test_does_not_overwrite_an_address_owned_by_another_peer(self) -> None:
        (self.peer_dir / "other-worker.conf").write_text(
            "[Peer]\nPublicKey = " + "B" * 43 + "=\nAllowedIPs = 10.99.0.3/32\n",
            encoding="utf-8",
        )
        original = (self.peer_dir / "other-worker.conf").read_text(encoding="utf-8")

        with self.assertRaisesRegex(HELPER.wireguard.RevocationError, "another durable WireGuard peer"):
            HELPER.add_peer(
                "worker-001",
                "10.99.0.3",
                self.public_key,
                config=self.config,
                peer_dir=self.peer_dir,
                lock=self.lock,
                run=self.runner,
                is_registered=lambda _node_id, _address: True,
            )

        self.assertEqual((self.peer_dir / "other-worker.conf").read_text(encoding="utf-8"), original)
        self.assertFalse((self.peer_dir / "worker-001.conf").exists())
        self.assertNotIn(self.public_key, self.config.read_text(encoding="utf-8"))
        self.assertEqual(self.live_peers, {})


if __name__ == "__main__":
    unittest.main()
