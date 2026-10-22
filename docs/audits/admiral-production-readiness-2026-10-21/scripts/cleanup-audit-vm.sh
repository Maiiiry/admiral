#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Remove one powered-off audit guest and only its libvirt artifacts.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run as root on the isolated libvirt audit host." >&2
  exit 1
fi
if [[ $# -ne 1 || ! $1 =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,62}$ ]]; then
  echo "Usage: $0 GUEST_NAME" >&2
  exit 2
fi

python3 - "$1" <<'PY'
from pathlib import Path
import json
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

name = sys.argv[1]
root = Path("/var/lib/libvirt/images/admiral-validation")
overlay_dir = (root / "overlays").resolve()
seed_dir = (root / "seeds").resolve()
cloud_dir = (root / "cloud-init").resolve()
overlay = overlay_dir / f"{name}.qcow2"
iso = cloud_dir / f"{name}.iso"
seed_files = {path.resolve() for path in seed_dir.glob("*.qcow2")}


def run(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(args, text=True, capture_output=True)
    if check and result.returncode:
        raise SystemExit(result.stderr.strip() or result.stdout.strip())
    return result


info = run("virsh", "dominfo", name, check=False)
domain_exists = info.returncode == 0
if not domain_exists and "failed to get domain" not in info.stderr.lower():
    raise SystemExit(info.stderr.strip() or f"cannot inspect libvirt domain {name!r}")

domain_macs: set[str] = set()
if domain_exists:
    state = run("virsh", "domstate", name).stdout.strip().lower()
    if state != "shut off":
        raise SystemExit(f"refusing to clean {name}: domain state is {state!r}, expected 'shut off'")

    blocks = run("virsh", "domblklist", name, "--details").stdout.splitlines()
    sources: set[Path] = set()
    for line in blocks:
        fields = line.split()
        if len(fields) < 4 or fields[0] not in {"file", "block", "dir", "network"}:
            continue
        if fields[0] != "file":
            raise SystemExit(f"refusing to clean {name}: non-file block device found: {line}")
        source = Path(fields[-1])
        if source != overlay and source != iso:
            raise SystemExit(f"refusing to clean {name}: unexpected guest disk source {source}")
        sources.add(source)
    if overlay not in sources:
        raise SystemExit(f"refusing to clean {name}: expected overlay is not attached to the guest")

    interfaces = run("virsh", "domiflist", name).stdout.splitlines()
    for line in interfaces:
        fields = line.split()
        if len(fields) >= 5 and fields[1] == "network" and fields[-1].count(":") == 5:
            domain_macs.add(fields[-1].lower())

if overlay.exists():
    resolved_overlay = overlay.resolve(strict=True)
    if resolved_overlay.parent != overlay_dir:
        raise SystemExit(f"refusing to clean {name}: overlay resolves outside the audit overlay directory")
    image_info = json.loads(run("qemu-img", "info", "--output=json", str(resolved_overlay)).stdout)
    if image_info.get("format") != "qcow2":
        raise SystemExit(f"refusing to clean {name}: guest disk is not qcow2")
    backing = image_info.get("backing-filename")
    if not backing:
        raise SystemExit(f"refusing to clean {name}: disk is not a seed-backed overlay")
    backing_path = Path(backing)
    if not backing_path.is_absolute():
        backing_path = resolved_overlay.parent / backing_path
    backing_path = backing_path.resolve(strict=True)
    if backing_path not in seed_files:
        raise SystemExit(f"refusing to clean {name}: backing image is not one of the shared audit seeds")
elif domain_exists:
    raise SystemExit(f"refusing to clean {name}: attached overlay is missing")

for artifact in (iso, cloud_dir / name):
    if artifact.is_symlink():
        if artifact.parent.resolve() not in {cloud_dir, cloud_dir / name}:
            raise SystemExit(f"refusing to clean {name}: artifact symlink resolves outside audit cloud-init")
    elif artifact.exists() and artifact.resolve().parent != cloud_dir:
        raise SystemExit(f"refusing to clean {name}: cloud-init artifact resolves outside audit directory")

network = ET.fromstring(run("virsh", "net-dumpxml", "default").stdout)
hosts = [host for host in network.findall(".//host") if host.get("name") == name]
if len(hosts) > 1:
    raise SystemExit(f"refusing to clean {name}: multiple DHCP reservations share the guest name")
if hosts and domain_exists and hosts[0].get("mac", "").lower() not in domain_macs:
    raise SystemExit(f"refusing to clean {name}: DHCP reservation MAC does not match the guest")

if domain_exists:
    run("virsh", "undefine", name)
    print(f"undefined_domain={name}")

if overlay.exists():
    overlay.unlink()
    print(f"removed_overlay={overlay}")
if iso.exists() or iso.is_symlink():
    iso.unlink()
    print(f"removed_cloud_init_iso={iso}")
guest_cloud_dir = cloud_dir / name
if guest_cloud_dir.exists() or guest_cloud_dir.is_symlink():
    if guest_cloud_dir.is_symlink():
        guest_cloud_dir.unlink()
    else:
        shutil.rmtree(guest_cloud_dir)
    print(f"removed_cloud_init_dir={guest_cloud_dir}")

if hosts:
    host = hosts[0]
    host_xml = ET.tostring(host, encoding="unicode", short_empty_elements=True)
    run("virsh", "net-update", "default", "delete", "ip-dhcp-host", host_xml, "--live", "--config")
    print(
        "removed_dhcp_reservation="
        f"name:{name},mac:{host.get('mac','')},ip:{host.get('ip','')}"
    )
else:
    print(f"dhcp_reservation=none name:{name}")

print("shared_seed_images=preserved")
PY
