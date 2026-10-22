# Admiral production-readiness audit

Audit ID: `ADM-AUDIT-2026-10-21`. This directory holds the nine requested reports, non-secret lab procedures and reproducible evidence. The active target is Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 on x86_64, each in Single-Node and Multi-Node (eight cells).

The validation scope is x86_64 only: four distributions across Single-Node and Multi-Node, for eight cells. Rocky Linux 10 is back in scope using the documented EPEL `python3-pyOpenSSL-25.0.0-1.el10_1` seed exception; this is a validation-environment pin, not a product dependency fix or a pass. Its Release 46 dependency-resolution failure remains historical evidence in `evidence/release46-rocky-excluded-dependency-block.md`.

## Candidate status — Release 52 built; runtime matrix 0/8

R49 exploratory Single-Node probes found #240 and invalidated R49. R50 built and was queried from both local repositories but no VM used it; build review found `admiral-common.spec` lacked `%check` (#244), so R50 was superseded before runtime testing. Release 51 installed on fresh Fedora Rawhide and Rocky Linux 10.2 guests; Fedora lifecycle testing found #245: paused and deprovisioned instances remained `effective_availability=available`. R51 is invalidated, and none of its observations count as matrix passes; completion remains **0/8**. The fix is pushed in `admirald@0baf488353386fdb67f995ef3e72cfe6cfc6de07`, with green CI [39730492772](https://github.com/admiral-project/admirald/actions/runs/39730492772). Coordinated Release 52 is now built from signed root preparation commit `c22d05e`; its root CI [39731120097](https://github.com/admiral-project/admiral/actions/runs/39731120097) is green, all six `%check` stages pass, and both local repositories return the same six NEVRAs. No R52 VM has run, so matrix completion remains **0/8**. R52 refs, NEVRAs, hashes and repository evidence are in [the candidate record](evidence/release52-candidate.md) and [checksum list](evidence/release52-rpm-sha256.txt). R51 runtime observations are in [the R51 lifecycle record](evidence/release51-initial-lifecycle.md) and count as no matrix passes.

Local tests pass: root audit scripts 118, `admirald` full suite, vet and build including #245, `admiral-fleet` and `admiralctl` tests/vet/build, Flagship 266 and Harbor 350. The Release 52 RPM `%check` ran all six package checks; Harbor emitted 307 non-fatal deprecation warnings tracked in #242. The CLI required the RPM-equivalent local dependency layout recorded in #241. All five component source SHAs and the root preparation commit have green CI: #245 [39730492772](https://github.com/admiral-project/admirald/actions/runs/39730492772), #240 [39724553667](https://github.com/admiral-project/admiralctl/actions/runs/39724553667), #233 [39724727343](https://github.com/admiral-project/admiral/actions/runs/39724727343), #239 [39726030742](https://github.com/admiral-project/admiral/actions/runs/39726030742), #244 [39727055542](https://github.com/admiral-project/admiral/actions/runs/39727055542), and R52 preparation [39731120097](https://github.com/admiral-project/admiral/actions/runs/39731120097). Issues remain open with their existing labels; no issue was closed. R47–R51 are superseded or invalidated and do not count toward a matrix cell.

R52 build identity and package hashes are in [the candidate manifest](evidence/release52-candidate.md) and [checksum list](evidence/release52-rpm-sha256.txt); no R52 VM run has occurred. R51's targeted runtime observations and #245 invalidation are in [the R51 lifecycle record](evidence/release51-initial-lifecycle.md); they count as no matrix passes. R50 details are in [its candidate record](evidence/release50-candidate.md) and [checksum list](evidence/release50-rpm-sha256.txt); it was superseded before VM testing. R49 build identity is in [its manifest](evidence/release49-candidate.md); partial Single-Node observations, limitations and raw-log checksums are in [the exploratory report](evidence/release49-exploratory-single-node.md) and [raw evidence checksum list](evidence/release49-exploratory-single-node-sha256.txt).

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
