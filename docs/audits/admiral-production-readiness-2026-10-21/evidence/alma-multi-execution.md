# AlmaLinux 10.2 x86_64 Multi-Node execution

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Source: root `748b703662eafdaf3919bad28787d0264f06bf16`; candidate submodule SHAs are in `source-manifest.txt`.<br>
Candidate: six Release 42 RPMs, `0.0.1rc5-42.el10`; exact SHA-256 values are in `candidate-rpm-sha256.txt`.<br>
Topology: three isolated libvirt VMs, each 2 vCPU / 2 GiB RAM, SELinux Enforcing. Hub `adm-audit-alma-hub` (`192.168.122.150`, WireGuard `10.99.0.1`); workers `adm-audit-alma-worker1` (`.151`, `10.99.0.2`) and `adm-audit-alma-worker2` (`.152`, `10.99.0.3`). No production host or service was involved.

Private SSH identities and unsanitized installer logs remain outside Git in the ignored local validation directory with mode `0600`. The installer logs are identified by SHA-256 below; they were not copied into the repository.

## Installation and registration

Both workers were installed from the supported `--worker-node` profile through the installed hub. Bootstrap completed successfully on both. Each recap reported `ok=146 changed=51 unreachable=0 failed=0 skipped=216 rescued=0 ignored=0`. Worker2 install helper recorded start `2026-10-21T13:10:07Z`, completion `13:17:40Z`, exit 0 (7m33s wall time, including package/security update and secure setup). Worker1 raw log filesystem mtime was `13:08:57Z`; its helper exited 0. The raw worker logs have mode `0600` and SHA-256:

* Worker1: `3be4871963def0f08d61d6c7cf9651f1b1a5b6deac9438875b5b9eb7641032c6`.
* Worker2: `e69500fa735c0fd75349507d7652b4756f14809071124eceb7a0fc73f9c707b2`.

`admiralctl nodes list --output json` showed the hub portal and both workers `active/healthy`; the workers reported the expected WireGuard addresses and `available_for_provisioning=true`. A hub WireGuard query showed recent handshakes for both worker peers. Fleet was active on both workers; the hub correctly ran Admirald/Harbor/Flagship and did not run Fleet.

## Workload placement and runtime

Applied `examples/apps/e2e-whoami.yaml` to the hub, then issued explicit, waited provisions:

| Test | Instance | Requested worker | Control-plane result | Runtime observation |
| --- | --- | --- | --- | --- |
| ALMA-MN-001 | `inst_51475b49fa4b9b7f` | `adm-audit-alma-worker1` | operation succeeded; instance `running/healthy`, storage `ok` | worker1 rootless Podman showed infra, app (`traefik/whoami:v1.10`) and PostgreSQL 16 containers `Up` |
| ALMA-MN-002 | `inst_ca49a728cc4b0758` | `adm-audit-alma-worker2` | operation succeeded; instance `running/healthy`, storage `ok` | worker2 rootless Podman showed infra, app and PostgreSQL 16 containers `Up` |

The instance records retained the requested worker IDs. `admiral-apps` had `Linger=yes`; per-instance user systemd units for pod, app and database were active. Quadlet files were under `/etc/containers/systemd/users/993/admiral/`, mode `0644`, owner `root:root`. App, pod and DB units declared `Restart=always`; the DB volume was a named persistent volume. DB Quadlets contained `Secret=` references for generated user/password values; secret values were not read or recorded. Runtime Podman inspection showed `Privileged=false`, private PID namespace and `no-new-privileges` for the app container. This is a positive sample, not a complete isolation or secrets-access audit.

## Worker outage and recovery

At `13:20:32Z`, the host suspended worker1 with `virsh suspend adm-audit-alma-worker1`. No packets were selectively filtered; this is a whole-VM pause test, not a network-partition test. At 60 and 90 seconds, the node still appeared active because the configured offline threshold is 2 minutes. At `13:22:57Z` (145 seconds after suspension), Admirald logged `Nodes marked offline by health monitor` for worker1. Its node record became `status=offline`, `health_status=degraded`, `available_for_provisioning=false`, reason `heartbeat_timeout`; worker2 and the hub remained healthy.

During that interval, the bound instance still reported `technical_status=running` and `health_status=healthy`; its `last_health_checked_at` was `13:20:20Z`, before the node pause. This is stale last-known instance state while the node was offline. No automatic migration or replacement instance was observed or expected by this single-hub/spoke architecture. This state-reporting gap is tracked as `ADM-F-002`.

At `13:23:42Z`, the host resumed worker1 with `virsh resume`. All three existing containers were `Up` after recovery; no additional instance IDs appeared. A new worker heartbeat arrived at `13:24:41Z`, 59 seconds after resume, and the node returned to `active/healthy/available_for_provisioning=true`. The instance remained assigned to worker1 and returned to a fresh healthy check. The other worker stayed available throughout.

## Worker guest reboot

Before reboot, worker1 reported boot ID `903a8c1d-f759-4164-aee5-f97dd967b33c`; its DB container mounted the named Quadlet volume `admiral-inst_51475b49fa4b9b7f-db` at `/var/lib/postgresql/data`, and `pg_isready -q` succeeded. `virsh reboot adm-audit-alma-worker1` was requested at `13:33:22Z`. SSH briefly refused connections during boot; after recovery, the boot ID was `f2c731bb-c590-41a2-8172-1657038d52b9`. The same infra/app/DB containers were `Up`, `pg_isready -q` succeeded, and the node reported `active/healthy/available_for_provisioning=true` with a fresh heartbeat at `13:34:10Z`. This confirms Quadlet startup and database process availability after a worker guest reboot. It does not verify a user-data marker across this worker reboot; the Single-Node marker backup/restore and persistence check is documented separately.

## Results and limits

* **PASS:** supported three-node bootstrap, authenticated WireGuard peer setup, live worker registration, explicit workload placement on both workers, rootless Podman/systemd/Quadlet runtime, worker offline detection and rejoin.
* **Observation / finding:** effective instance health is not degraded while its assigned node is offline; only the stale check timestamp exposes that condition (`ADM-F-002`).
* **Expected design limit:** an unavailable worker's workload is not migrated automatically. Recovery requires that worker to return or an operator to perform a separately audited migration/reprovisioning action.
* **NOT TESTED:** hub/database outage, real hub-worker network partition or latency, simultaneous admin requests, task interruption during side effects, node removal, cross-node authorization negatives, and automatic migration (not implemented).
* This AlmaLinux 10.2 execution is scoped evidence for the AlmaLinux x86_64 Multi-Node target cell. It does not substitute for the other three distributions or complete the full Multi-Node scenario catalog.
