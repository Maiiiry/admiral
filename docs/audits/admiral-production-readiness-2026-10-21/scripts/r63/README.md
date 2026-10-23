# Release 63 targeted Rocky/Fedora scripts — diagnostic only

The scripts in this directory reproduce the named R63 probes summarized in `../../evidence/release63-rocky-single-node-progress.md`. R63 has been invalidated by #262 and none of its observations counts toward the current release matrix.

Run the scripts only on disposable guests installed from the exact candidate. Most guest operations use `sudo bash` because the secure installer stores the admin CLI configuration for root. Host-reboot scripts run from the libvirt host and observe SSH reconnection and boot-ID change. Upload only deterministic fixture YAMLs to `/tmp`; do not pass tokens on the command line.

Runtime logs are retained locally under `packaging/build/validation/rc5-r63/`, mode 0600. They are excluded from Git because logs may contain environment-specific identifiers. SHA-256 values are recorded in the evidence directory.
