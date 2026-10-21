# Concurrent duplicate provision requests on Fedora Rawhide Multi-Node

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Candidate: Release 42 x86_64, root source `748b703662eafdaf3919bad28787d0264f06bf16`.<br>
Guest: Fedora Linux 46 Cloud Edition prerelease (Rawhide), x86_64; isolated three-node cluster, request target worker1.

## Procedure and result

Two independent SSH clients invoked the same provision command concurrently, with identical app, tier, customer ID and explicit node:

```sh
admiralctl instances provision --app e2e-whoami --tier small \
  --customer audit_fedora_concurrent_20261021 \
  --node rc5-r42-fedora-x86-worker1 --wait --quiet --output json
```

Both requests were accepted within 3 ms of one another at `14:36:19Z`. Both operations succeeded, but they returned different instance and task IDs:

| Operation | Instance | Task | Result interval |
| --- | --- | --- | --- |
| `op_699e06608f4f7ec7` | `inst_b8e8da2740c9927c` | `task_ec68df5e91935a91` | succeeded `14:36:19.151Z`–`14:36:22.411Z` |
| `op_b860c7deb2078d0f` | `inst_5844214195ab7d48` | `task_c03648c18496a990` | succeeded `14:36:19.154Z`–`14:36:26.456Z` |

Both instance records had the same customer ID and worker assignment. Direct rootless Podman inspection showed six `Up` containers: infra, app and DB for each instance. This confirms that simultaneous retries/submissions can duplicate billable workload resources; it is not just a sequential CLI observation. No stable request idempotency key is exposed by this command.

Both instances were explicitly deprovisioned. Both operations succeeded and worker1 then had zero containers, zero Podman volumes and zero matching test Quadlet files. The control plane retained both records as deprovisioned. No customer or production data was involved.

**Status: FAIL for concurrent idempotency; PASS for deprovision cleanup.** The broader update/delete, callback replay and task-lease concurrency scenarios remain untested. This reproduces `ADM-F-001` and is tracked in GitHub issue [#207](https://github.com/admiral-project/admiral/issues/207).

Ignored raw logs are mode `0600` and contain no credentials:

| Log | SHA-256 |
| --- | --- |
| `audit-target-fedora-concurrent-provision-a.log` | `165e40b5940d221ca553dbcc298fb52732685302c48f0474ef82609fd0b74927` |
| `audit-target-fedora-concurrent-provision-b.log` | `910c7167241c91779af247e5ef8f4e072aea0508209d2acb09f6c61b595525dc` |
| `audit-target-fedora-concurrent-deprovision-a.log` | `06dd658c951d8c7c63fea687dbd39130c9831874e424a75f564aac43a331ce29` |
| `audit-target-fedora-concurrent-deprovision-b.log` | `53311fe54a82b76f9f800d0a8681eb1ba498517da96b045629f800dffe3309a7` |
