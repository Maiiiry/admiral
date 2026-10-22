# Admiral production-readiness audit

Audit ID: `ADM-AUDIT-2026-10-21`. This directory holds the nine requested reports, non-secret lab procedures and reproducible evidence. The active target is Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 on x86_64, each in Single-Node and Multi-Node (eight cells).

The validation scope is x86_64 only: four distributions across Single-Node and Multi-Node, for eight cells. Rocky Linux 10 is back in scope using the documented EPEL `python3-pyOpenSSL-25.0.0-1.el10_1` seed exception; this is a validation-environment pin, not a product dependency fix or a pass. Its Release 46 dependency-resolution failure remains historical evidence in `evidence/release46-rocky-excluded-dependency-block.md`.

## Candidate status — Release 48 built; Release 47 invalidated

Release 47 was built and partially exercised on fresh Fedora Rawhide and Rocky Linux 10 Single-Node guests. Both reboot probes found stale `effective_availability` (#237), invalidating R47; none of its results count toward a cell. Release 48 is built from root package-preparation commit `5bb18b17cddce3c1a50e3bd19fe6b0ac4cae36b7`, whose GitHub CI is green, and staged in the isolated local repository. The #237 fix is included at `admirald@d50523f` with [component CI green](https://github.com/admiral-project/admirald/actions/runs/39711773654). The R48 repositories returned exactly six Admiral NEVRAs from both EL10 and Fedora endpoints, but no R48 VM execution has started; matrix completion remains **0/8**. A separate audit-helper issue #238 was found before guest testing; its local fix and regression test need a root commit and green CI before validation. R48 identity is recorded in [the candidate manifest](evidence/release48-candidate.md) and [checksum list](evidence/release48-rpm-sha256.txt). R47 hashes and invalidated guest evidence remain in [the historical candidate record](evidence/release47-candidate.md) and [diagnostic execution record](evidence/release47-invalidated-single-node.md). Issues #234–#238 remain open.

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

Run `scripts/host-preflight.sh` on the isolated Rocky Linux KVM host. The lab expects immutable, already-updated QCOW2 seeds under `/var/lib/libvirt/images/admiral-validation/seeds/`, a public SSH key supplied by the operator, the isolated `default` and `admiral-validation` libvirt networks, and the local candidate RPM repository served from `192.168.122.1` on TCP/80. `scripts/create-audit-vm.sh` creates a 2-vCPU/2-GiB guest and injects only the caller-supplied public key. It never copies the private key into a VM.

For a fresh single-node guest, run `scripts/install-single-node-audit.sh` with the `el10` or `fedora` profile, local private SSH key, pinned audit `known_hosts` file, guest address and unique node ID. It transfers the `.repo` file for `ADMIRAL_RC_RELEASE` (default 48), enables EPEL/CRB on EL10 or COPR on Fedora, verifies all six exact candidate NEVRAs, then runs the packaged `admiral-install --single-node` flow. The existing-node helper `scripts/bootstrap-candidate-node.sh` uses the same release default. Its raw console log is written with mode 0600 outside tracked evidence until it has been scanned and sanitized.

For Multi-Node, create the hub and two worker guests on the isolated WireGuard-validation network with unique `10.99.0.0/24` addresses; use the supported `--admin-portal-node` and `--worker-node` installer modes, documented in `docs/multi_node_setup_v1.md` and `docs/sysadmin_guide.md`. Keep topology files and private keys outside Git. Run `scripts/capture-guest-baseline.sh` after each install, then use scenario-specific scripts/commands recorded in the reports. Do not route lab network traffic to production systems.

Before storing any log in this directory, scan it for credentials, tokens, private keys, database URLs and customer data. Keep unsanitized raw logs mode 0600 in the ignored local validation directory. Preserve failures.

## Historical lab assets

The prepared Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 x86_64 seeds are under `/var/lib/libvirt/images/admiral-validation/seeds/`; the next candidate's guests must use disposable overlays from these seeds. Previous Release 42/43/45/46/47 observations remain candidate-specific history and do not count toward the next matrix run.
