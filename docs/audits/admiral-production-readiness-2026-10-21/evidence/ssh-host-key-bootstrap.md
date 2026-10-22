# Audit VM SSH host-key bootstrap verification

Audit: `ADM-AUDIT-2026-10-21`
Date: 2026-10-22 UTC
Issue: [#239](https://github.com/admiral-project/admiral/issues/239)
Status: **targeted harness verification passed; source change awaits commit, push and CI**.

## Change under test

`scripts/create-audit-vm.sh` now creates a unique Ed25519 host key on the trusted KVM host before boot. `prepare-audit-cloud-init.py` places the private key in cloud-init's documented `ssh_keys.ed25519_private` field and the public key in `ssh_keys.ed25519_public`; cloud-init does not generate a second key when the `ssh_keys` mapping is provided. The private key file and cloud-init user-data are mode `0600` inside a mode `0700` directory. The generated NoCloud ISO is owned by `qemu` and mode `0600`; its Rock Ridge entries also preserve `0600` for `user-data` and `meta-data`. The host creates a per-guest mode-`0600` `known_hosts` file for the NAT address and, when configured, the WireGuard address. Guest SSH uses `StrictHostKeyChecking=yes` from the first connection.

Cloud-init references: [SSH key configuration example](https://cloudinit.readthedocs.io/en/stable/reference/yaml_examples/ssh.html) and [SSH module schema](https://cloudinit.readthedocs.io/en/latest/topics/modules.html#ssh).

## Automated checks

`python3 -m pytest -q scripts/test_audit_vm_hostkeys.py` passed **5/5**. The tests verify that the public pin corresponds to the generated private key, pins both guest addresses, does not put private-key material in `known_hosts`, restricts local file modes, refuses to overwrite an existing cloud-init directory, and ensures ISO creation preserves private source modes. The full root script suite passed **118/118**. `bash -n` for audit shell scripts, Python compilation and `git diff --check` also passed.

## Fresh-guest integration check

An initial integration run exposed that the intermediate ISO command still used `mkisofs -r`, which weakens the intended file-mode protection inside the ISO. That run was excluded from the evidence below. The option was removed; a synthetic ISO mode check confirmed that Rock Ridge retained `0600`, and then two fresh 2-vCPU/2-GiB guests were created from the existing pre-updated seeds. No RPM was installed and no OS update was run:

| OS | Temporary guest | Address | Expected host-key fingerprint | Result |
| --- | --- | --- | --- | --- |
| Fedora Rawhide | `adm-hostkey-final-fedora` | `192.168.122.248` | `SHA256:hcBffeKdathL1u1VABhxUsubCNhb/I+xStj+jG/sKoM` | **PASS** — first authenticated SSH succeeded with strict checking on attempt 5; guest-reported fingerprint matched the host-generated pin. |
| Rocky Linux 10.2 | `adm-hostkey-final-rocky` | `192.168.122.249` | `SHA256:jTghuja4F6SsE9z9BVDL5Y9WzWtmV3v+wiJpKeS5UUs` | **PASS** — first authenticated SSH succeeded with strict checking on attempt 7; guest-reported fingerprint matched the host-generated pin. |

The verification command queried `/etc/ssh/ssh_host_ed25519_key.pub` through the strict SSH connection and compared its SHA-256 fingerprint with the host-generated public key. No `ssh-keyscan` enrollment or interactive acceptance was used. Test guest fingerprints are public identifiers, not private key material.

Both guests were shut down and removed with `scripts/cleanup-audit-vm.sh`. The helper removed each exact DHCP reservation, overlay, ISO and cloud-init directory containing its private host key. `virsh list --all` was empty afterward and the shared seed images remained present. Host disk availability was 89 GiB before this run; post-cleanup availability was also 89 GiB.

This validates the first-contact SSH trust path for the harness on one Fedora and one EL10 guest. It does not count toward the Admiral runtime matrix and does not validate an RPM candidate.
