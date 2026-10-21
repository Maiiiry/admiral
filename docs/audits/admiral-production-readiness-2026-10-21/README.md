# Admiral production-readiness audit

Audit ID: `ADM-AUDIT-2026-10-21`. This directory holds the nine requested reports, non-secret lab procedures and reproducible evidence. The target scope is Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 on x86_64, each in Single-Node and Multi-Node (eight cells). AlmaLinux has scoped runtime evidence in both modes; CentOS Stream has scoped Single-Node evidence and a three-guest Multi-Node execution covering install, workload placement/cleanup, local database backup/restore, hub restart, failed service, concurrency, and worker outage/recovery. Both topologies remain incomplete; CentOS Stream Multi-Node reproduced stale healthy instance status during worker loss and premature health reporting before PostgreSQL readiness.

The audit scope is x86_64 only: four distributions across Single-Node and Multi-Node, for eight cells.

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

For a fresh single-node guest, run `scripts/install-single-node-audit.sh` with the local private SSH key, the pinned audit `known_hosts` file, guest address and unique node ID. It transfers the local candidate `.repo` file, bootstraps the exact RPM set, then runs the packaged `admiral-install --single-node` flow. The installer performs its documented DNF/security updates and EPEL, CRB and Admiral COPR setup. Its raw console log is written with mode 0600 outside tracked evidence until it has been scanned and sanitized.

For Multi-Node, create the hub and two worker guests on the isolated WireGuard-validation network with unique `10.99.0.0/24` addresses; use the supported `--admin-portal-node` and `--worker-node` installer modes, documented in `docs/multi_node_setup_v1.md` and `docs/sysadmin_guide.md`. Keep topology files and private keys outside Git. Run `scripts/capture-guest-baseline.sh` after each install, then use scenario-specific scripts/commands recorded in the reports. Do not route lab network traffic to production systems.

Before storing any log in this directory, scan it for credentials, tokens, private keys, database URLs and customer data. Keep unsanitized raw logs mode 0600 in the ignored local validation directory. Preserve failures.

## Current lab assets

The 2026-10-21 AlmaLinux and CentOS Stream seeds were verified against official checksums, updated, booted with the updated kernel and shut down before cloning. Their seed hashes are in `evidence/updated-seed-sha256.txt`; seed DNF logs are sanitized in `evidence/seed-updates/`. All four target distributions now have at least scoped runtime evidence in both topologies, but the scenarios are uneven and no cell is a complete production-readiness pass. CentOS Stream Multi-Node evidence covers secure three-guest installation, registration, placement on both workers, cleanup, hub restart with manual peer recovery, failed-service injection on a worker and concurrent duplicate provisions across workers. Its database process outage, network partition, task replay/lease behavior, conflicting updates/deletes, security, backup/restore and performance scenarios remain untested.
