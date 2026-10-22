# Admiral production-readiness audit

Audit ID: `ADM-AUDIT-2026-10-21`. This directory holds the nine requested reports, non-secret lab procedures and reproducible evidence. The active target is Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 on x86_64, each in Single-Node and Multi-Node (eight cells).

The validation scope is x86_64 only: four distributions across Single-Node and Multi-Node, for eight cells. Rocky Linux 10 is back in scope using the documented EPEL `python3-pyOpenSSL-25.0.0-1.el10_1` seed exception; this is a validation-environment pin, not a product dependency fix or a pass. Its Release 46 dependency-resolution failure remains historical evidence in `evidence/release46-rocky-excluded-dependency-block.md`.

## Candidate status — Release 56 built; matrix 0/8

Release 55 built all six RPMs and ran partial Single-Node scenarios on fresh Fedora Rawhide and Rocky Linux 10 guests. A Fedora host reboot exposed false `running/healthy/available` state while PostgreSQL was not ready. This is tracked as [#256](https://github.com/admiral-project/admiral/issues/256), related to #237. Release 55 is invalidated; none of its results counts toward a matrix cell. The candidate manifest, hashes, targeted results and reboot failure are in [the Release 55 records](evidence/release55-candidate.md). Matrix completion remains **0/8**.

The #256 fix is pushed in `admirald@9b8f129` and `admiral-fleet@74e8b0f`. Root commit `042e578` pins all five components at their latest `origin/main` SHAs; root and component CI runs are green. The six Release 56 RPMs built locally and all six `%check` stages passed. Fresh Fedora Rawhide and Rocky Linux 10 Single-Node guests installed those RPMs and passed the targeted host-reboot regression, but neither full cell is complete. The clean dependency query failed: configured repositories do not provide Flask 3.1.3 on Rocky or Mistune 3.4.0 on Fedora/Rocky. Findings and raw-log hashes are recorded in `evidence/release56-candidate.md` and `evidence/release56-runtime-log-sha256.txt`; issues #201 and #257 track repository publication. Matrix completion remains **0/8**.

The release-blocking scope is x86_64 only: Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10, each in Single-Node and Multi-Node. Rocky Linux 10 uses the documented EPEL `python3-pyOpenSSL-25.0.0-1.el10_1` seed exception. This pin is a validation-environment workaround, not a product dependency fix or a pass.

Issues remain open pending exact-candidate validation; none has been closed. R55 observations remain candidate-specific and do not count toward Release 56 cells. R56 has targeted install/reboot evidence on Fedora and Rocky only; clean dependency resolution remains a blocker under #201 and #257. AlmaLinux and CentOS Stream R56 runs and all four Multi-Node cells remain outstanding.

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

For Multi-Node, keep the lab's two address spaces separate. The second NIC connects to libvirt's isolated `admiral-validation` **underlay** (`10.77.0.0/24`); give the hub `10.77.0.10`, worker 1 `10.77.0.11`, and worker 2 `10.77.0.12`. These are the `PRIVATE_IP`/`PRIVATE_MAC` arguments to `scripts/create-audit-vm.sh`, not WireGuard addresses. The supported installer configures a separate WireGuard **overlay** on `10.99.0.0/24`: use hub `10.99.0.1` and workers `10.99.0.2` and `10.99.0.3` with `--wireguard-ip`. Install the hub with `--admin-portal-node --public-ip 10.77.0.10`. Then run `scripts/install-worker-audit.sh ADMIN_SSH_KEY HUB_KNOWN_HOSTS WORKER_KNOWN_HOSTS HUB_IP WORKER_IP NODE_ID WIREGUARD_IP HOST_FINGERPRINT OUTPUT_LOG`; it uses strict host-key pins for both guests, creates a temporary per-worker bootstrap key, and removes temporary key material after the installer revokes the bootstrap credential. Its log records installer duration and the package NEVRA deltas on hub and worker. The candidate repo must already be configured on each worker so the installer receives the exact pinned RPM set. Use the supported modes documented in `docs/multi_node_setup_v1.md` and `docs/sysadmin_guide.md`. Keep topology files and private keys outside Git. Run `scripts/capture-guest-baseline.sh` after each install, then use scenario-specific scripts/commands recorded in the reports. Do not route lab network traffic to production systems.

Before storing any log in this directory, scan it for credentials, tokens, private keys, database URLs and customer data. Keep unsanitized raw logs mode 0600 in the ignored local validation directory. Preserve failures.

## Historical lab assets

The prepared Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 x86_64 seeds are under `/var/lib/libvirt/images/admiral-validation/seeds/`; the next candidate's guests must use disposable overlays from these seeds. The exact 2026-10-22 seed filenames and SHA-256 values are in [the Release 54 seed manifest](evidence/release54-seed-sha256.txt). Previous Release 42/43/45/46/47/48/49/53 observations remain candidate-specific history and do not count toward the next matrix run.
