# Release 53 Single-Node regression probes

These probes run only on disposable Release 53 validation guests. The resize/reactivation scenario uses the application fixture in `../../fixtures/e2e-resize.yaml`, requires the guest's configured `admiralctl` session and rootless Podman secrets, and writes guest evidence under `/var/tmp/adm-r53-<os>-resize/`. Keep host captures mode `0600` under the ignored `packaging/build/validation/rc5-r53/evidence/` tree until scanned for secrets. The probe deprovisions its instance on success; preserve failed guest state and evidence before any cleanup.

`r53-process-recovery.sh` provisions the disposable whoami fixture, kills its container process, then SIGKILLs `admirald` and `admiral-fleet` to verify systemd recovery and cleanup. Run only on disposable R53 guests; it deprovisions on success and preserves guest evidence on failure.

The DB-backed fixtures now declare a `pg_isready` command healthcheck. Fleet treats a declared service with no healthcheck as ready once its container is running; do not use that default to claim database protocol readiness. The first R53 reboot-helper attempt used an older fixture without this check and is recorded as an inconclusive harness run, not a product failure.
