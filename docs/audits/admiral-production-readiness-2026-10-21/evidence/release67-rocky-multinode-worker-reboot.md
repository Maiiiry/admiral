# RC5 Release 67 — Rocky Linux 10 Multi-Node worker reboot evidence

**Result: the named W2 reboot/recovery scenario passed on the exact R67
candidate. Rocky Linux Multi-Node is not a completed matrix cell; the matrix
remains 0/8.**

## Candidate and environment

- Test ID: `R67-ROCKY-MN-WORKER-REBOOT-01`.
- Candidate: six Admiral RPMs `0.0.1rc5-67.el10`, built from root source
  commit `833d15aa4f8e96be30d28dad169b9d06a4d9894d`. The exact component pins,
  package manifests and native build evidence are in
  [`release67-candidate.md`](release67-candidate.md).
- Runtime: Rocky Linux 10.2 x86_64, three isolated libvirt guests, each 2 vCPU
  and 2 GiB RAM. Hub `adm-r67-rocky-mn-hub` (`192.168.122.184`), W1
  `adm-r67-rocky-mn-w1` (`192.168.122.185`) and W2
  `adm-r67-rocky-mn-w2` (`192.168.122.186`, WireGuard `10.99.0.3`).
- Before the test, the hub had all six exact `.el10` R67 packages. W2 had the
  role-required `admiral-common` and `admiral-fleet` at exact R67 `.el10`
  NEVRAs. No package was installed or changed during the test.
- SSH used pinned per-guest host keys with strict host-key checking. The
  scenario used only disposable lab guests.

## Procedure and observations

The reproducer applied `e2e-whoami` and provisioned
`inst_109b8ff5ff262abc` explicitly on W2 (operation
`op_615c472f9d8d7af1`, task `task_95bee1ada45352db`). Before reboot, HTTP
returned 200 and a unique SQL marker was written to and read from the
workload's PostgreSQL database. At `2026-10-23T21:33:59Z`, the test issued
`virsh reboot` to W2. Its boot ID changed from
`262c3247-717f-4f4f-a34f-3706b868d789` to
`a5e7a6de-5423-4b03-b922-372dd4f88f58`.

| UTC sample | Node | Instance | Worker runtime | HTTP |
| --- | --- | --- | --- | --- |
| 21:34:48 | active/healthy/available | stopped/stopped/unavailable | Two containers; PostgreSQL ready and marker present | 200 |
| 21:34:55 | active/healthy/available | running/healthy/available | Three containers; PostgreSQL ready and marker present | 200 |
| 21:35:01 | active/healthy/available | Second consecutive healthy/available sample | Three containers; PostgreSQL ready and marker present | 200 |

The instance remained unavailable until it reached healthy/available status.
The same SQL marker was read after recovery. The first healthy/available sample
arrived about 56 seconds after the reboot request. Deprovision operation
`op_e67e2443e79aabc0` succeeded. Final W2 inventory contained no matching
containers, pods, volumes or files. A three-node postcheck then confirmed all
nodes active/healthy/available, exact role-specific R67 `.el10` package sets,
active services, no failed systemd units, SELinux Enforcing, fresh WireGuard
handshakes, and empty worker Podman inventories.

**Expected:** W2's boot ID changes; Admiral does not report availability
before health convergence; workload HTTP and database data recover; removal
of the test workload leaves no resources.

**Observed:** each expected result was observed. This is scoped resilience
evidence, not proof of active-task/callback crash recovery, repeated reboot
behavior, or complete Multi-Node readiness.

## Excluded helper attempt

Attempt `rocky-mn-worker-reboot-01` provisioned the workload but stopped before
issuing a reboot. The copied helper ran `admiral-apps` commands while the
current directory was the validator's private home, producing
`cannot chdir to /home/validator: Permission denied`. After confirming the
helper issue, the run was interrupted before reboot; its EXIT cleanup
deprovisioned the instance successfully. Follow-up state showed the instance
deprovisioned and worker containers, pods and volumes empty. This was a test
helper defect, not an Admiral result; the attempt is retained and excluded.
The corrected helper sets the working directory to `/tmp` and sets the
workload user's `HOME` explicitly.

## Reproduction and evidence integrity

From the repository root, with the guests available, the validation SSH key
and pinned per-guest known-host files:

```bash
docs/audits/admiral-production-readiness-2026-10-21/scripts/r67/r67-rocky-multinode-worker-reboot.sh \
  "$SSH_KEY" "$HUB_KNOWN" "$W2_KNOWN" \
  192.168.122.184 192.168.122.186 \
  adm-r67-rocky-mn-w2 adm-r67-rocky-mn-w2 \
  "$OUT/rocky-mn-worker-reboot-02"
```

The corrected reproducer is committed with this report. Raw successful and
excluded-attempt captures are local, ignored and mode `0600` under
`packaging/build/validation/rc5-r67/rocky-mn-worker-reboot-{02,01}/`; both
SHA-256 manifests verified with `sha256sum -c`.

| Evidence | SHA-256 |
| --- | --- |
| Successful raw evidence manifest | `b57e6f4923c2650dc2927b5c43bfbf6cd5f63d4d34399fbdf360259c057726e6` |
| Excluded helper attempt manifest | `484aadd09e721acb23cd6113262e77047619c264526758f2df474f4ab29aa95f` |
| Reproducer script | `1350467619cfce737e0f306e7a80e5ee0341d5f4c9c05f6bf64a7292eb3ffcdf` |

All Rocky R67 guests were shut down after the postcheck. The candidate and
source remained unchanged throughout this scenario.
