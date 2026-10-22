# Admiral production-readiness audit

Audit ID: `ADM-AUDIT-2026-10-21`. This directory holds the nine requested reports, non-secret lab procedures and reproducible evidence. The active target is Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 on x86_64, each in Single-Node and Multi-Node (eight cells).

The validation scope is x86_64 only: four distributions across Single-Node and Multi-Node, for eight cells. Rocky Linux 10 is back in scope using the documented EPEL `python3-pyOpenSSL-25.0.0-1.el10_1` seed exception; this is a validation-environment pin, not a product dependency fix or a pass. Its Release 46 dependency-resolution failure remains historical evidence in `evidence/release46-rocky-excluded-dependency-block.md`.

## Candidate status — Release 58 invalidated; matrix 0/8

Release 58 is the latest local candidate, built on Rocky Linux 10.2 x86_64. It pins the Flask/SQLAlchemy/Alembic stack, and a local RPM repository resolves the six-package Admiral transaction plus the Flagship/Harbor BuildRequires. Flagship passed 266 unit tests, Harbor passed 350, and all three Go module suites passed. Fresh disposable Single-Node guests on Rocky Linux 10.2, AlmaLinux 10.2 and CentOS Stream 10 installed the exact R58 package set and ran the named targeted scenarios recorded in [the EL10 execution report](evidence/release58-el10-single-node-execution.md). One intermittent false-availability observation during a user-systemd manager restart invalidated R58 for release validation; it is tracked in [issue #259](https://github.com/admiral-project/admiral/issues/259).

Release 58 has not been published or built in COPR. Its Admiral RPM packaging command skipped `%check` and bypassed the builder's stale BuildRequires; the application suites were run separately against the staged Python RPM contents. Runtime results are limited to named EL10 Single-Node scenarios: no complete cell has passed, Fedora Rawhide has not run, and no Release 58 Multi-Node topology has run. **Matrix completion remains 0/8.** See [the candidate record](evidence/release58-candidate.md), [the execution evidence](evidence/release58-el10-single-node-execution.md), and [the raw-log hash manifest](evidence/release58-el10-single-node-raw-sha256.txt). The local repo is unpublished; no clean COPR build is claimed.

The release-blocking scope is x86_64 only: Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10, each in Single-Node and Multi-Node. Rocky Linux 10 uses the documented EPEL `python3-pyOpenSSL-25.0.0-1.el10_1` seed exception. This pin is a validation-environment workaround, not a product dependency fix or a pass.

Issue #259 was opened and tagged `needs-work`; #212 is closed upstream and its installed-binary negative check passed in R58. No issue was closed during this validation. R58's three EL10 Single-Node runs are diagnostic only because the candidate was invalidated; no complete cell passed and the matrix remains 0/8. Fedora Rawhide and all four Multi-Node cells remain untested.

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

For a fresh single-node guest, run `scripts/install-single-node-audit.sh` with the `el10` or `fedora` profile, local private SSH key, pinned audit `known_hosts` file, guest address and unique node ID. It transfers the `.repo` file for `ADMIRAL_RC_RELEASE`, enables EPEL/CRB on EL10 or COPR on Fedora, verifies all six exact candidate NEVRAs, then runs `admiral-install --single-node --validation-seed`. This validation-only option skips the otherwise repeated base OS and security update transactions because the VM is created from a verified, recently updated seed; normal production installer behavior remains unchanged. The helper records installer start/end and elapsed seconds, a pre/post package NEVRA delta, and the final DNF transaction. Raw console logs are written with mode 0600 outside tracked evidence until scanned and sanitized.

For Multi-Node, keep the lab's two address spaces separate. The second NIC connects to libvirt's isolated `admiral-validation` **underlay** (`10.77.0.0/24`); give the hub `10.77.0.10`, worker 1 `10.77.0.11`, and worker 2 `10.77.0.12`. These are the `PRIVATE_IP`/`PRIVATE_MAC` arguments to `scripts/create-audit-vm.sh`, not WireGuard addresses. The supported installer configures a separate WireGuard **overlay** on `10.99.0.0/24`: use hub `10.99.0.1` and workers `10.99.0.2` and `10.99.0.3` with `--wireguard-ip`. Install the hub with `--admin-portal-node --public-ip 10.77.0.10`. Then run `scripts/install-worker-audit.sh ADMIN_SSH_KEY HUB_KNOWN_HOSTS WORKER_KNOWN_HOSTS HUB_UNDERLAY_IP HUB_WIREGUARD_IP WORKER_UNDERLAY_IP NODE_ID WORKER_WIREGUARD_IP HOST_FINGERPRINT OUTPUT_LOG`; SSH bootstrap and the WireGuard UDP endpoint use the hub underlay, while the API URL inside Fleet must use the hub overlay. The helper verifies both destinations explicitly. It uses strict host-key pins for both guests, creates a temporary per-worker bootstrap key, and removes temporary key material after the installer revokes the bootstrap credential. Its log records installer duration and the package NEVRA deltas on hub and worker. Set `ADMIRAL_LOCAL_REPO_CONFIG` to the exact candidate repository file so each worker installs the same RPM candidate as the hub. Use the supported modes documented in `docs/multi_node_setup_v1.md` and `docs/sysadmin_guide.md`. Keep topology files and private keys outside Git. Run `scripts/capture-guest-baseline.sh` after each install, then use scenario-specific scripts/commands recorded in the reports. Do not route lab network traffic to production systems.

Before storing any log in this directory, scan it for credentials, tokens, private keys, database URLs and customer data. Keep unsanitized raw logs mode 0600 in the ignored local validation directory. Preserve failures.

## Historical lab assets

The prepared Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 x86_64 seeds are under `/var/lib/libvirt/images/admiral-validation/seeds/`; the next candidate's guests must use disposable overlays from these seeds. The exact 2026-10-22 seed filenames and SHA-256 values are in [the Release 54 seed manifest](evidence/release54-seed-sha256.txt). Previous Release 42/43/45/46/47/48/49/53 observations remain candidate-specific history and do not count toward the next matrix run.
