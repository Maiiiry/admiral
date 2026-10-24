# Admiral release validation — Rocky Linux 10 x86_64

Audit ID: `ADM-AUDIT-2026-10-21`. The active release gate is functional validation on **Rocky Linux 10 x86_64 only**, with two cells: Single-Node and Multi-Node. This gate does not certify production security, performance, or high availability.

## Active candidate — Release 70; matrix 0/2

RC5 Release 70 (`0.0.1rc5-70`) is being built from the latest selected component commits. The previous R69 Single-Node evidence is candidate-specific and earns no R70 credit. R70 must pass both cells on the exact same six RPMs before the functional release is accepted.

The candidate's source commit, five component SHAs, CI runs, RPM NEVRAs, signatures and SHA-256 values will be recorded in [`release70-candidate.md`](evidence/release70-candidate.md). The functional gate is tracked in [issue #200](https://github.com/admiral-project/admiral/issues/200).

**Current R70 matrix: 0/2.** Neither cell is credited until its complete functional checklist has run on Release 70 with reproducible evidence.

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

For a fresh Rocky Single-Node guest, run `scripts/install-single-node-audit.sh el10 ...`; it installs the exact candidate through normal DNF and invokes `admiral-install --single-node --validation-seed`. The seed is updated and includes the documented EPEL pyOpenSSL 25.0.0 compatibility pin. The validation-only option skips repeated OS updates because the guest comes from a verified updated seed. The helper records installer timing, package NEVRA changes and the DNF transaction. Raw logs stay mode 0600 until scanned and sanitized.

For Multi-Node, use three Rocky guests: one admin node and two workers. Keep the isolated underlay (`10.77.0.0/24`) separate from the WireGuard overlay (`10.99.0.0/24`). Enroll workers with `scripts/install-worker-audit.sh`, strict SSH host-key pins and the exact Release 70 repository. Capture hub and worker inventories, heartbeat/health, placement on each worker, SQL markers, HTTP 200, retry idempotency, worker recovery/rejoin and cleanup. Do not route lab traffic to production systems.

Before storing any log in this directory, scan it for credentials, tokens, private keys, database URLs and customer data. Keep unsanitized raw logs mode 0600 in the ignored local validation directory. Preserve failures.

## Historical evidence

R69 and earlier logs remain candidate-bound historical evidence. They do not count toward R70. Preserve all failed attempts and use only the Release 70 RPMs for active-cell decisions.
