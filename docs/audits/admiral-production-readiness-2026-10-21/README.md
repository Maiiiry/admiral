# Admiral production-readiness audit

Audit ID: `ADM-AUDIT-2026-10-21`. This directory holds the nine requested reports, non-secret lab procedures and reproducible evidence. The target scope is Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 on x86_64, each in Single-Node and Multi-Node (eight cells).

The audit scope is x86_64 only: four distributions across Single-Node and Multi-Node, for eight cells.

## Current candidate status — Release 46

Release 46 source pins and six package `Release` fields are prepared at root commit `7223561646b60d3c24e8bfb257d544a5eb6dea04`. The `admirald` fix is `e2b4fcee8fcd63d3c66b9f659156874d2a1bbb09`; its CI and root package-preparation CI are green. The six RPM build and publication are pending. **No Release 46 matrix cell has run; status is 0/8.** Release 45 was installed on Fedora Rawhide and Rocky Linux 10 Single-Node guests, where reboot testing found a stale task replay after failure and deprovision. That HIGH defect invalidates every Release 45 result as candidate validation; see [the replay evidence](evidence/fedora-r45-stale-task-replay.md) and [#229](https://github.com/admiral-project/admiral/issues/229).

The target remains Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 on x86_64, each in Single-Node and Multi-Node. Prior findings remain open until regressions are recorded against the exact Release 46 RPM set.

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

The 2026-10-21 AlmaLinux and CentOS Stream seeds were verified against official checksums, updated, booted with the updated kernel and shut down before cloning. Their seed hashes are in `evidence/updated-seed-sha256.txt`; seed DNF logs are sanitized in `evidence/seed-updates/`. Previous Release 42/43/45 runtime probes exist across the four target distributions and both topologies, but all are historical and do not count toward Release 46. Fresh Release 46 guests must use new overlays from the verified seeds. The earlier CentOS Stream Multi-Node observations and their remaining gaps are summarized in the historical reports.
