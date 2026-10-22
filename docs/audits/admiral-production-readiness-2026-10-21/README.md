# Admiral production-readiness audit

Audit ID: `ADM-AUDIT-2026-10-21`. This directory holds the nine requested reports, non-secret lab procedures and reproducible evidence. The active target is Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 on x86_64, each in Single-Node and Multi-Node (eight cells).

The validation scope is x86_64 only: four distributions across Single-Node and Multi-Node, for eight cells. Rocky Linux 10 is back in scope using the documented EPEL `python3-pyOpenSSL-25.0.0-1.el10_1` seed exception; this is a validation-environment pin, not a product dependency fix or a pass. Its Release 46 dependency-resolution failure remains historical evidence in `evidence/release46-rocky-excluded-dependency-block.md`.

## Candidate status — Release 49 exploratory; next candidate is gated

Release 49 was built from root package-preparation commit `6661bb779dd197d24cf565e7e5bb85c99ef809ed`; all six packages passed `%check`, the local EL10/Fedora repos served the exact R49 NEVRAs, and root/component CI was green. Fresh Single-Node guests on Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 have now run scoped installation, workload, backup/restore, restart, reboot and fault-injection probes. A real Rocky capacity-rejection probe exposed #240: `admiralctl` retried one structured policy rejection and produced four failed operations/tasks. R49 is invalidated for final validation; **matrix completion remains 0/8** and none of its runtime evidence counts toward the next candidate. No Release 50 RPM has been built.

The complete local suites now pass: root audit scripts 118, `admirald`, `admiral-fleet` and `admiralctl` tests/vet/build, Flagship 266 and Harbor 350. The Harbor suite emits 307 non-fatal deprecation warnings tracked in #242. The CLI needed the RPM-equivalent local dependency layout, recorded in #241. Its CI run [39724553667](https://github.com/admiral-project/admiralctl/actions/runs/39724553667) is green, with GitHub maintenance notices tracked in #243. The #233 VM-cleanup helper is tested and tagged `fix-proposed`; its signed root commit `2159d27` and CI run [39724727343](https://github.com/admiral-project/admiral/actions/runs/39724727343) are green. The #239 SSH pin fix passed five local tests, protected-ISO mode checks and strict-SSH integration on fresh Fedora/EL10 guests; it is tagged `fix-proposed`, merged to `main` as signed commit `54d4a6b`, and root CI run [39726030742](https://github.com/admiral-project/admiral/actions/runs/39726030742) is green. Release 50 pins and all six spec bumps are prepared locally; the common-source pin now targets `54d4a6b2e3843cb22f33526c198b32e4ac8e53bf`, and the final reference check passes. The packaging pin refresh still requires its own signed commit and green CI before building RPMs. R47, R48 and R49 remain invalidated/superseded and do not count.

R49 build identity and package hashes are in [the candidate manifest](evidence/release49-candidate.md) and [checksum list](evidence/release49-rpm-sha256.txt). Its partial Single-Node observations, limitations and raw-log checksums are in [the exploratory report](evidence/release49-exploratory-single-node.md) and [raw evidence checksum list](evidence/release49-exploratory-single-node-sha256.txt).

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

For a fresh single-node guest, run `scripts/install-single-node-audit.sh` with the `el10` or `fedora` profile, local private SSH key, pinned audit `known_hosts` file, guest address and unique node ID. It transfers the `.repo` file for `ADMIRAL_RC_RELEASE` (default 50), enables EPEL/CRB on EL10 or COPR on Fedora, verifies all six exact candidate NEVRAs, then runs the packaged `admiral-install --single-node` flow. The existing-node helper `scripts/bootstrap-candidate-node.sh` uses the same release default. Its raw console log is written with mode 0600 outside tracked evidence until it has been scanned and sanitized.

For Multi-Node, create the hub and two worker guests on the isolated WireGuard-validation network with unique `10.99.0.0/24` addresses; use the supported `--admin-portal-node` and `--worker-node` installer modes, documented in `docs/multi_node_setup_v1.md` and `docs/sysadmin_guide.md`. Keep topology files and private keys outside Git. Run `scripts/capture-guest-baseline.sh` after each install, then use scenario-specific scripts/commands recorded in the reports. Do not route lab network traffic to production systems.

Before storing any log in this directory, scan it for credentials, tokens, private keys, database URLs and customer data. Keep unsanitized raw logs mode 0600 in the ignored local validation directory. Preserve failures.

## Historical lab assets

The prepared Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 x86_64 seeds are under `/var/lib/libvirt/images/admiral-validation/seeds/`; the next candidate's guests must use disposable overlays from these seeds. Previous Release 42/43/45/46/47/48/49 observations remain candidate-specific history and do not count toward the next matrix run.
