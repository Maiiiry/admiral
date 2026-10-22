# Admiral production-readiness audit

Audit ID: `ADM-AUDIT-2026-10-21`. This directory holds the nine requested reports, non-secret lab procedures and reproducible evidence. The active target is Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 on x86_64, each in Single-Node and Multi-Node (eight cells).

The validation scope is x86_64 only: four distributions across Single-Node and Multi-Node, for eight cells. Rocky Linux 10 is back in scope using the documented EPEL `python3-pyOpenSSL-25.0.0-1.el10_1` seed exception; this is a validation-environment pin, not a product dependency fix or a pass. Its Release 46 dependency-resolution failure remains historical evidence in `evidence/release46-rocky-excluded-dependency-block.md`.

## Candidate status — Release 53 built; runtime matrix 0/8

R52 was invalidated when fresh Fedora and Rocky Single-Node guests reproduced #246: resize recreated PostgreSQL without its generated secret references. The fix is in `admirald@b4b125e`, with green component CI [39737323015](https://github.com/admiral-project/admirald/actions/runs/39737323015). Release 53 includes that fix; all six package checks passed and both local repositories expose the exact six NEVRAs. Fresh Fedora and Rocky Single-Node guests passed named install, resize/reactivation, concurrent same-key idempotency, local database backup/restore, required-service failure reporting, selected process recovery and targeted guest reboot with SQL-marker persistence; same-host isolation checks remain partial. No complete matrix cell has passed; completion remains **0/8**. See the [Release 53 candidate record](evidence/release53-candidate.md) and [initial execution report](evidence/release53-initial-single-node-execution.md); R52 failure evidence remains in its [candidate record](evidence/release52-candidate.md) and [execution report](evidence/release52-initial-single-node-execution.md).

The local full `admirald` suite, vet and build passed for #246 before the candidate build. Release 53’s six RPM `%check` stages passed; Harbor emitted 307 non-fatal warnings tracked in #242. Root package preparation is green [39738673606](https://github.com/admiral-project/admiral/actions/runs/39738673606), as are the selected component workflows listed in the Release 53 candidate record. Targeted host reboot checks with persistent SQL markers also passed on Fedora and Rocky; DHCP lease and reboot-helper defects are tracked in open issues [#247](https://github.com/admiral-project/admiral/issues/247) and [#248](https://github.com/admiral-project/admiral/issues/248). Their harness fixes remain local pending root CI. Issues remain open; none was closed. Earlier candidate runs do not count toward current matrix cells.

Release 53 build identity and package hashes are in its candidate manifest and checksum list. The #246 resize/reactivation regression and targeted host reboot/SQL-marker checks passed as scoped scenarios on fresh Fedora and Rocky guests; full-cell work continues. Results and raw-log hashes are in the [R53 initial execution report](evidence/release53-initial-single-node-execution.md). R52 scoped results remain historical and count as no matrix passes; R51’s observations are in its lifecycle record. R50 was superseded before VM testing and R49 partial Single-Node results remain historical only.

The target is Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 on x86_64, each in Single-Node and Multi-Node. The x86_64 host has four vCPU, 8 GiB RAM, 4 GiB swap, KVM/libvirt and about 87 GiB free disk after obsolete R46/R47 overlays were removed. Guest runs are isolated; Fedora and Rocky Single-Node probes ran in parallel, while each Multi-Node cell requires one admin/portal hub and two worker guests.

## Reports

* [Architecture review](ARCHITECTURE_REVIEW.md)
* [Test matrix](TEST_MATRIX.md)
* [Single-Node report](SINGLE_NODE_REPORT.md)
* [Multi-Node report](MULTI_NODE_REPORT.md)
* [Security review](SECURITY_REVIEW.md)
* [Resilience report](RESILIENCE_REPORT.md)
* [Performance report](PERFORMANCE_REPORT.md)
* [Findings](FINDINGS.md)
* [Production readiness](PRODUCTION_READINESS.md)

## Reproducing the lab

Run `scripts/host-preflight.sh` on the isolated Rocky Linux KVM host. The lab expects immutable, already-updated QCOW2 seeds under `/var/lib/libvirt/images/admiral-validation/seeds/`, a public validator SSH key supplied by the operator, the isolated `default` and `admiral-validation` libvirt networks, and the local candidate RPM repository served from `192.168.122.1` on TCP/80. `scripts/create-audit-vm.sh` creates a 2-vCPU/2-GiB guest and generates a unique Ed25519 SSH host key on the trusted host. Cloud-init receives that key through mode-0600 files and a mode-0600 ISO; the helper also writes a matching `known_hosts` file before the first network connection. It injects only the caller-supplied public validator key, never that login key's private half. After preserving required evidence and confirming the domain is disposable, run `scripts/cleanup-audit-vm.sh GUEST_NAME`; it refuses running guests, verifies seed-backed overlays and removes only that guest's libvirt artifacts and exact DHCP reservation, including the private host-key material.

For a fresh single-node guest, run `scripts/install-single-node-audit.sh` with the `el10` or `fedora` profile, local private SSH key, pinned audit `known_hosts` file, guest address and unique node ID. It transfers the `.repo` file for `ADMIRAL_RC_RELEASE` (default 53), enables EPEL/CRB on EL10 or COPR on Fedora, verifies all six exact candidate NEVRAs, then runs the packaged `admiral-install --single-node` flow. The existing-node helper `scripts/bootstrap-candidate-node.sh` uses the same release default. Its raw console log is written with mode 0600 outside tracked evidence until it has been scanned and sanitized.

For Multi-Node, create the hub and two worker guests on the isolated WireGuard-validation network with unique `10.99.0.0/24` addresses; use the supported `--admin-portal-node` and `--worker-node` installer modes, documented in `docs/multi_node_setup_v1.md` and `docs/sysadmin_guide.md`. Keep topology files and private keys outside Git. Run `scripts/capture-guest-baseline.sh` after each install, then use scenario-specific scripts/commands recorded in the reports. Do not route lab network traffic to production systems.

Before storing any log in this directory, scan it for credentials, tokens, private keys, database URLs and customer data. Keep unsanitized raw logs mode 0600 in the ignored local validation directory. Preserve failures.

## Historical lab assets

The prepared Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 x86_64 seeds are under `/var/lib/libvirt/images/admiral-validation/seeds/`; the next candidate's guests must use disposable overlays from these seeds. Previous Release 42/43/45/46/47/48/49 observations remain candidate-specific history and do not count toward the next matrix run.
