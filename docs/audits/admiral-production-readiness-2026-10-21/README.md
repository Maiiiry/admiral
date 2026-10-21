# Admiral production-readiness audit

Audit ID: `ADM-AUDIT-2026-10-21`. This directory holds the nine requested reports, non-secret lab procedures and reproducible evidence. The current target scope is Fedora Rawhide, AlmaLinux 10 and CentOS Stream 10 on x86_64, each in Single-Node and Multi-Node (six cells).

The audit scope is x86_64 only: three distributions across Single-Node and Multi-Node, for six cells. Rocky Linux 10 was removed from the matrix by user direction after fresh-install dependency resolution hit an EPEL/Rocky 10.2 cryptography incompatibility (“dependency hell”); it is out of scope, not an Admiral finding. See `evidence/release46-rocky-excluded-dependency-block.md`.

## Current candidate status — Release 46

Release 46 was built as six coordinated RPMs from root package-preparation commit `7223561646b60d3c24e8bfb257d544a5eb6dea04`. The `admirald` fix is `e2b4fcee8fcd63d3c66b9f659156874d2a1bbb09`; component and root CI are green. Fresh Single-Node guests for the three in-scope distributions have installed the exact packages. Targeted Fedora queue-recovery and workload lifecycle probes, plus AlmaLinux and CentOS Stream provision/HTTP/deprovision probes, passed for their named scenarios; they do not complete any matrix cell. **Completion remains 0/6.** Rocky’s prior Release 46 probe is preserved as excluded evidence and does not count. Release 45 remains invalidated by its reproduced stale-task replay; see [the Release 45 evidence](evidence/fedora-r45-stale-task-replay.md), [the initial Release 46 probes](evidence/release46-initial-single-node-execution.md), [the follow-up probes](evidence/release46-followup-single-node-execution.md), and [#229](https://github.com/admiral-project/admiral/issues/229).

The target is Fedora Rawhide, AlmaLinux 10 and CentOS Stream 10 on x86_64, each in Single-Node and Multi-Node. Finding #229 passed its Release 46 Fedora Single-Node regression but remains open pending the issue's Multi-Node acceptance check. Other findings remain open until affected scenarios are retested against this exact RPM set.

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

For a fresh single-node guest, run `scripts/install-single-node-audit.sh` with the `el10` or `fedora` profile, local private SSH key, pinned audit `known_hosts` file, guest address and unique node ID. It transfers the `.repo` file for `ADMIRAL_RC_RELEASE` (default 46), enables EPEL/CRB on EL10 or COPR on Fedora, verifies all six exact candidate NEVRAs, then runs the packaged `admiral-install --single-node` flow. Its raw console log is written with mode 0600 outside tracked evidence until it has been scanned and sanitized.

For Multi-Node, create the hub and two worker guests on the isolated WireGuard-validation network with unique `10.99.0.0/24` addresses; use the supported `--admin-portal-node` and `--worker-node` installer modes, documented in `docs/multi_node_setup_v1.md` and `docs/sysadmin_guide.md`. Keep topology files and private keys outside Git. Run `scripts/capture-guest-baseline.sh` after each install, then use scenario-specific scripts/commands recorded in the reports. Do not route lab network traffic to production systems.

Before storing any log in this directory, scan it for credentials, tokens, private keys, database URLs and customer data. Keep unsanitized raw logs mode 0600 in the ignored local validation directory. Preserve failures.

## Historical lab assets

The 2026-10-21 AlmaLinux and CentOS Stream seeds were verified against official checksums, updated, booted with the updated kernel and shut down before cloning. Their seed hashes are in `evidence/updated-seed-sha256.txt`; seed DNF logs are sanitized in `evidence/seed-updates/`. Previous Release 42/43/45 runtime probes exist across the original four-distribution scope and both topologies, but all are historical and do not count toward Release 46. Fresh Release 46 guests must use new overlays from the verified seeds. The earlier CentOS Stream Multi-Node observations and their remaining gaps are summarized in the historical reports.
