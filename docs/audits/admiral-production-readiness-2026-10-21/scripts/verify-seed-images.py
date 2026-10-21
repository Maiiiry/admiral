#!/usr/bin/env python3
"""Verify downloaded cloud images against their locally retained official manifests."""
from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as image:
        for block in iter(lambda: image.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def expected_alma(manifest: Path, image_name: str) -> str:
    for line in manifest.read_text(encoding="utf-8").splitlines():
        match = re.fullmatch(r"([0-9a-fA-F]{64})\s+(.+)", line.strip())
        if match and Path(match.group(2)).name == image_name:
            return match.group(1).lower()
    raise ValueError(f"no checksum entry for {image_name} in {manifest}")


def expected_centos(manifest: Path, image_name: str) -> str:
    pattern = re.compile(rf"^SHA256 \({re.escape(image_name)}\) = ([0-9a-fA-F]{{64}})$")
    for line in manifest.read_text(encoding="utf-8").splitlines():
        match = pattern.fullmatch(line.strip())
        if match:
            return match.group(1).lower()
    raise ValueError(f"no checksum entry for {image_name} in {manifest}")


def verify(label: str, path: Path, expected: str) -> None:
    actual = sha256(path)
    status = "PASS" if actual == expected else "FAIL"
    print(f"{status} {label} official_sha256={expected} computed_sha256={actual}")
    if actual != expected:
        raise SystemExit(1)


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} DOWNLOADED_IMAGE_DIRECTORY")
    directory = Path(sys.argv[1])
    alma_name = "AlmaLinux-10-GenericCloud-10.2-20261012.0.x86_64.qcow2"
    centos_name = "CentOS-Stream-GenericCloud-10-20261019.0.x86_64.qcow2"
    verify(
        alma_name,
        directory / alma_name,
        expected_alma(directory / "AlmaLinux-10-CHECKSUM", alma_name),
    )
    verify(
        centos_name,
        directory / centos_name,
        expected_centos(directory / f"{centos_name}.SHA256SUM", centos_name),
    )


if __name__ == "__main__":
    main()
