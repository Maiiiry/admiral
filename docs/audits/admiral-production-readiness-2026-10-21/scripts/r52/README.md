# Release 52 scoped Single-Node probes

These scripts were used on disposable Fedora Rawhide and Rocky Linux 10.2 Release 52 guests. Run them only against fresh validation guests, never production. Each script expects its documented positional arguments and writes guest-side artifacts under `/var/tmp/adm-r52-<os>-<probe>/`; raw host-side captures belong in the ignored mode-0600 `packaging/build/validation/` tree.

The scripts contain no credentials. They use the guest's configured `admiralctl` session and rootless Podman secret store. `r52-podman-delete-failure.sh` must be paired with `restore-podman-after-injection.sh` or allowed to reach its five-minute watchdog before shutting down the guest. The resize reproduction intentionally failed before cleanup on R52; deprovision the instance named in its output before reusing the guest. The R52 outcomes and their exact artifact hashes are recorded in `../../evidence/release52-initial-single-node-execution.md`.
