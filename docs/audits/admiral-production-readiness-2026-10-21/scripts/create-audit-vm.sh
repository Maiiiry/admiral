#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Create an isolated x86_64 KVM guest from an immutable, DNF-updated seed.
set -euo pipefail

usage() {
  echo "usage: $0 {fedora|rocky|alma|centos} NAME NAT_IP NAT_MAC [WG_IP WG_MAC] PUBKEY_FILE" >&2
  exit 2
}

[[ $# -eq 5 || $# -eq 7 ]] || usage
os=$1 name=$2 nat_ip=$3 nat_mac=$4
if [[ $# -eq 5 ]]; then
  wg_ip= wg_mac= pubkey_file=$5
else
  wg_ip=$5 wg_mac=$6 pubkey_file=$7
fi
[[ $EUID -eq 0 ]] || { echo "run as root" >&2; exit 1; }
[[ $name =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$ ]] || { echo "invalid guest name" >&2; exit 2; }
[[ $nat_mac =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] || { echo "invalid NAT MAC" >&2; exit 2; }
[[ $nat_ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "invalid NAT IPv4" >&2; exit 2; }
[[ -r $pubkey_file ]] || { echo "cannot read public key file" >&2; exit 2; }
if [[ -n $wg_ip ]]; then
  [[ $wg_ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "invalid private IPv4" >&2; exit 2; }
  [[ $wg_mac =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] || { echo "invalid private MAC" >&2; exit 2; }
fi

root=/var/lib/libvirt/images/admiral-validation
case "$os" in
  fedora) base="$root/seeds/Fedora-Rawhide-seed-20261022.x86_64.qcow2"; osinfo=fedora-rawhide ;;
  rocky)  base="$root/seeds/Rocky-10.2-seed-20261022.x86_64.qcow2"; osinfo=rocky10 ;;
  alma)   base="$root/seeds/AlmaLinux-10.2-seed-20261022.x86_64.qcow2"; osinfo=almalinux10 ;;
  centos) base="$root/seeds/CentOS-Stream-10-seed-20261022.x86_64.qcow2"; osinfo=centos-stream10 ;;
  *) usage ;;
esac
if [[ -n ${ADMIRAL_AUDIT_BASE_OVERRIDE:-} ]]; then
  base=$ADMIRAL_AUDIT_BASE_OVERRIDE
fi
[[ -r $base ]] || { echo "seed image not found: $base" >&2; exit 1; }
overlay="$root/overlays/$name.qcow2"
iso="$root/cloud-init/$name.iso"
seed_dir="$root/cloud-init/$name"
[[ ! -e $overlay && ! -e $iso ]] || { echo "guest artifacts already exist: $name" >&2; exit 1; }
! virsh dominfo "$name" >/dev/null 2>&1 || { echo "libvirt domain already exists: $name" >&2; exit 1; }

pub=$(tr -d '\r\n' < "$pubkey_file")
[[ $pub == ssh-* || $pub == ecdsa-* || $pub == sk-* ]] || { echo "unsupported SSH public key" >&2; exit 2; }
mkdir -p "$seed_dir" "$(dirname "$overlay")"
virsh net-update default add ip-dhcp-host "<host mac='$nat_mac' name='$name' ip='$nat_ip'/>" --live --config
python3 - "$seed_dir" "$name" "$pub" "$nat_mac" "$wg_ip" "$wg_mac" <<'PY'
from pathlib import Path
import sys

directory = Path(sys.argv[1])
name, pub, nat_mac, wg_ip, wg_mac = sys.argv[2:]
user_lines = [
    "#cloud-config", "ssh_deletekeys: true", "ssh_genkeytypes: [ed25519]",
    "ssh_pwauth: false", "disable_root: true", "users:", "  - default",
    "  - name: validator", "    gecos: Admiral production audit",
    "    groups: [wheel]", "    shell: /bin/bash",
    "    sudo: ['ALL=(ALL) NOPASSWD:ALL']", "    ssh_authorized_keys:",
    f"      - {pub}", "write_files:", "  - path: /tmp/admiral-validator.pub",
    "    owner: root:root", "    permissions: '0600'", "    content: |",
    f"      {pub}", "runcmd:",
    "  - [install, -D, -o, validator, -g, validator, -m, '0644', /tmp/admiral-validator.pub, /home/validator/validator.pub]",
    "  - [rm, -f, /tmp/admiral-validator.pub]",
]
(directory / "user-data").write_text("\n".join(user_lines) + "\n", encoding="utf-8")
(directory / "meta-data").write_text(
    f"instance-id: {name}\nlocal-hostname: {name}\n", encoding="utf-8"
)
if wg_ip:
    network_lines = [
        "version: 2", "renderer: NetworkManager", "ethernets:", "  nat:",
        "    match:", f"      macaddress: '{nat_mac}'", "    dhcp4: true",
        "    dhcp6: false", "  private:", "    match:",
        f"      macaddress: '{wg_mac}'", "    dhcp4: false", "    dhcp6: false",
        "    addresses:", f"      - {wg_ip}/24",
    ]
    (directory / "network-config").write_text(
        "\n".join(network_lines) + "\n", encoding="utf-8"
    )
PY

iso_files=(user-data meta-data)
[[ ! -f "$seed_dir/network-config" ]] || iso_files+=(network-config)
(cd "$seed_dir" && xorriso -as mkisofs -V CIDATA -J -r -o "$iso" "${iso_files[@]}")
qemu-img create -f qcow2 -F qcow2 -b "$base" "$overlay"
chown qemu:qemu "$overlay" "$iso"
restorecon -F "$overlay" "$iso"
networks=(--network "network=default,mac=$nat_mac,model=virtio")
if [[ -n $wg_ip ]]; then
  networks+=(--network "network=admiral-validation,mac=$wg_mac,model=virtio")
fi
virt-install --name "$name" --memory 2048 --vcpus 2 --osinfo "$osinfo" --import \
  --disk "path=$overlay,format=qcow2,bus=virtio" \
  --disk "path=$iso,device=cdrom" "${networks[@]}" \
  --graphics none --noautoconsole
echo "Created $name from $(basename "$base") at NAT $nat_ip${wg_ip:+ and private $wg_ip}."
