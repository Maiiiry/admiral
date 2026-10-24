# Admiral release validation — x86_64

Audit ID: `ADM-AUDIT-2026-10-21`. The active release gate covers Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 on x86_64, each in Single-Node and Multi-Node modes (eight cells). Every Multi-Node cell uses three real guests of the same OS: one admin node and two workers.

## Active candidate — Release 73

**Status: #272 fix is pushed and `admirald` CI is green; coordinated RPM builds pending. Matrix: 0/8.** R72 is invalidated after its worker-removal scenario reproduced #272 on AlmaLinux 10 and CentOS Stream 10. R72 had four Single-Node cells PASS, two Multi-Node cells PARTIAL, and two Multi-Node cells NOT TESTED. No R72 evidence carries into R73. See the [R72 candidate record](evidence/release72-candidate.md) and the new [R73 candidate record](evidence/release73-candidate.md).

The release gate checklist is tracked in [master issue #200](https://github.com/admiral-project/admiral/issues/200). Build all six packages at Release 73 using native EL10 and Fedora Rawhide toolchains. Record exact NEVRAs, signatures and SHA-256 values before the first cell. Do not bypass DNF dependency resolution or install RPMs built for another distribution.

## Reports

- [Architecture review](ARCHITECTURE_REVIEW.md)
- [Test matrix](TEST_MATRIX.md)
- [Single-Node report](SINGLE_NODE_REPORT.md)
- [Multi-Node report](MULTI_NODE_REPORT.md)
- [Security review](SECURITY_REVIEW.md)
- [Resilience report](RESILIENCE_REPORT.md)
- [Performance report](PERFORMANCE_REPORT.md)
- [Findings](FINDINGS.md)
- [Production readiness](PRODUCTION_READINESS.md)

## Reproducing the lab

Run `scripts/host-preflight.sh` on the isolated KVM host. Use immutable, updated QCOW2 seeds under `/var/lib/libvirt/images/admiral-validation/seeds/`, the isolated `default` and `admiral-validation` libvirt networks, and the R73 signed local RPM repository served from `192.168.122.1:80`. `scripts/create-audit-vm.sh` creates a 2-vCPU/2-GiB guest, generates a unique Ed25519 SSH host key on the trusted host, and writes mode-0600 cloud-init and known-host files. Preserve raw evidence in the ignored validation directory with mode 0600; scan logs for credentials before copying sanitized records into this audit.

For a fresh Single-Node guest, run `scripts/install-single-node-audit.sh el10 ...` or `scripts/install-single-node-audit.sh fedora ...`. The helper installs the native candidate through normal DNF resolution and invokes `admiral-install --single-node --validation-seed`; it records install time, package NEVRA changes and the transaction. Updated seeds avoid repeating OS updates. Preserve failed attempts and do not use production services.

For each Multi-Node cell, keep the isolated underlay (`10.77.0.0/24`) separate from the WireGuard overlay (`10.99.0.0/24`). Enroll workers with `scripts/install-worker-audit.sh`, strict SSH host-key pins and the exact native Release 73 repository. Capture hub and worker inventories, health, workload placement on each worker, SQL markers, HTTP 200, idempotent retries, worker recovery/rejoin, controlled node removal and cleanup.

Only complete evidence from the exact R73 RPM set can pass a cell. A functional cell pass does not certify all production security, resilience or performance properties.
