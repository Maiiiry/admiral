# Release 64 validation scripts

These are R63 scenario scripts adapted for the coordinated R64 candidate. They are reproducibility helpers only; no R64 scenario is PASS until it is executed against the exact per-distribution R64 RPMs and its evidence is recorded.

Run only on fresh disposable guests installed from the exact candidate. Most guest operations use `sudo bash` because the secure installer stores admin CLI configuration for root. Host-reboot scripts run from the libvirt host. Raw logs must remain mode 0600 and must not be committed without secret review.
