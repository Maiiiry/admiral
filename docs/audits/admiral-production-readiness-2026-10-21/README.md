# Admiral production-readiness audit

Audit ID: `ADM-AUDIT-2026-10-21`. This directory holds the nine requested reports, non-secret lab procedures and reproducible evidence. The active target is Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 on x86_64, each in Single-Node and Multi-Node (eight cells).

The validation scope is x86_64 only: four distributions across Single-Node and Multi-Node, for eight cells. Rocky Linux 10 is back in scope using the documented EPEL `python3-pyOpenSSL-25.0.0-1.el10_1` seed exception; this is a validation-environment pin, not a product dependency fix or a pass. Its Release 46 dependency-resolution failure remains historical evidence in `evidence/release46-rocky-excluded-dependency-block.md`.

## Candidate status — Release 50 superseded before VM testing; Release 51 preparation

Release 49 was built from root package-preparation commit `6661bb779dd197d24cf565e7e5bb85c99ef809ed`; exploratory Single-Node probes found #240, which invalidated R49. Release 50 was then built and its six NEVRAs were served from both isolated local repositories, but no VM used it. The build review found that `admiral-common.spec` had no `%check`; issue #244 tracks that LOW coverage gap. R50 is superseded before runtime validation and contributes **0/8** cells. The proposed check is now in signed root commit `012a571`, and Release 51 preparation increments all six packages and pins common source to that commit. No Release 51 RPM has been built yet.

Local tests pass: root audit scripts 118, `admirald`, `admiral-fleet` and `admiralctl` tests/vet/build, Flagship 266 and Harbor 350. The Harbor suite emits 307 non-fatal deprecation warnings tracked in #242. The CLI required the RPM-equivalent local dependency layout recorded in #241. CI for `admiralctl` [39724553667](https://github.com/admiral-project/admiralctl/actions/runs/39724553667), root #233 [39724727343](https://github.com/admiral-project/admiral/actions/runs/39724727343), root #239 [39726030742](https://github.com/admiral-project/admiral/actions/runs/39726030742), the R50 pin refresh [39726163045](https://github.com/admiral-project/admiral/actions/runs/39726163045), and #244's source change [39727055542](https://github.com/admiral-project/admiral/actions/runs/39727055542) is green. Issues #239 and #244 remain open with `fix-proposed`; no issue was closed. R50 is retained as build history only. R47–R50 do not count toward the next matrix run.

R50 build identity and package hashes are in [the candidate manifest](evidence/release50-candidate.md) and [checksum list](evidence/release50-rpm-sha256.txt); it was superseded before VM testing and contributes no matrix evidence. R49 build identity is in [its manifest](evidence/release49-candidate.md); partial Single-Node observations, limitations and raw-log checksums are in [the exploratory report](evidence/release49-exploratory-single-node.md) and [raw evidence checksum list](evidence/release49-exploratory-single-node-sha256.txt).

The target is Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 on x86_64, each in Single-Node and Multi-Node. The x86_64 host has four vCPU, 8 GiB RAM, 4 GiB swap, KVM/libvirt and about 90 GiB free disk after obsolete R46/R47 overlays were removed. Guest runs are isolated; Fedora and Rocky Single-Node diagnostics ran in parallel, while Multi-Node uses one admin/portal hub and two worker guests.

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

For a fresh single-node guest, run `scripts/install-single-node-audit.sh` with the `el10` or `fedora` profile, local private SSH key, pinned audit `known_hosts` file, guest address and unique node ID. It transfers the `.repo` file for `ADMIRAL_RC_RELEASE` (default 51), enables EPEL/CRB on EL10 or COPR on Fedora, verifies all six exact candidate NEVRAs, then runs the packaged `admiral-install --single-node` flow. The existing-node helper `scripts/bootstrap-candidate-node.sh` uses the same release default. Its raw console log is written with mode 0600 outside tracked evidence until it has been scanned and sanitized.

For Multi-Node, create the hub and two worker guests on the isolated WireGuard-validation network with unique `10.99.0.0/24` addresses; use the supported `--admin-portal-node` and `--worker-node` installer modes, documented in `docs/multi_node_setup_v1.md` and `docs/sysadmin_guide.md`. Keep topology files and private keys outside Git. Run `scripts/capture-guest-baseline.sh` after each install, then use scenario-specific scripts/commands recorded in the reports. Do not route lab network traffic to production systems.

Before storing any log in this directory, scan it for credentials, tokens, private keys, database URLs and customer data. Keep unsanitized raw logs mode 0600 in the ignored local validation directory. Preserve failures.

## Historical lab assets

The prepared Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 x86_64 seeds are under `/var/lib/libvirt/images/admiral-validation/seeds/`; the next candidate's guests must use disposable overlays from these seeds. Previous Release 42/43/45/46/47/48/49 observations remain candidate-specific history and do not count toward the next matrix run.
