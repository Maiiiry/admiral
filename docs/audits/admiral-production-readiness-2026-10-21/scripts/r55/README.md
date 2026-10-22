# Release 55 Single-Node regression probes

These probes run only on disposable Release 55 validation guests. The resize/reactivation scenario uses the application fixture in `../../fixtures/e2e-resize.yaml`, requires the guest's configured `admiralctl` session and rootless Podman secrets, and writes guest evidence under `/var/tmp/adm-r55-<os>-resize/`. Keep host captures mode `0600` under `/var/lib/libvirt/images/admiral-validation/validation/rc5-r55/single/` until scanned for secrets. The probe deprovisions its instance on success; preserve failed guest state and evidence before any cleanup.

Run guest-side `r55-*.sh` scenario helpers as root (`sudo -n bash ...`). The secure installer writes the administrator CLI configuration to `/root/.config/admiralctl/config.yaml`, so running these scripts as the SSH `validator` account fails before the CLI can authenticate. Example, after uploading the helper and fixture to the guest:

```bash
ssh -i "$SSH_KEY" -o BatchMode=yes -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="$KNOWN_HOSTS" "$GUEST" \
  'sudo -n bash -s -- alma audit_customer audit-idempotency-key' \
  < scripts/r55/r55-concurrent-idempotency.sh
```

The helper arguments contain scenario identifiers only; do not pass authentication tokens on the command line. Run `r55-host-reboot.sh` as root on the isolated libvirt host, not inside a guest. This execution-context requirement is tracked by open issue [#249](https://github.com/admiral-project/admiral/issues/249).

`r55-process-recovery.sh` provisions the disposable whoami fixture, kills its container process, then SIGKILLs `admirald` and `admiral-fleet` to verify systemd recovery and cleanup. Run only on disposable R55 guests; it deprovisions on success and preserves guest evidence on failure.

The DB-backed fixtures now declare a `pg_isready` command healthcheck. Fleet treats a declared service with no healthcheck as ready once its container is running; do not use that default to claim database protocol readiness. The first R55 reboot-helper attempt used an older fixture without this check and is recorded as an inconclusive harness run, not a product failure.
