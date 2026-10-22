# Evidence directory

## Current candidate

Release 53 is the active candidate, built from signed root preparation commit `e149571`; all six `%check` stages passed and both isolated repositories returned the same six R53 NEVRAs. Fresh Fedora Rawhide and Rocky Linux 10.2 Single-Node guests installed R53 and passed targeted #246 resize/reactivation, process-recovery, and host reboot/SQL-marker scenarios; no full cell is complete, so matrix completion remains **0/8**. Same-host isolation remains partial. Its component refs, NEVRAs, hashes and repository metadata are in `release53-candidate.md`, `release53-rpm-sha256.txt`, `release53-el10-repoquery.txt` and `release53-fedora-repoquery.txt`; runtime details and hashes are in `release53-initial-single-node-execution.md`. R52 was invalidated when the same distributions reproduced #246: resize omitted persisted database secret references. The source fix `admirald@b4b125e` is included in R53 and has green CI [39737323015](https://github.com/admiral-project/admirald/actions/runs/39737323015). R52's exact failure results remain in `release52-initial-single-node-execution.md` and its candidate record. Lab DHCP and reboot harness issues are open as #247 and #248; fixes are proposed locally pending root CI. Release 51 was invalidated by #245; R50 was superseded before VM testing; R49 was invalidated by #240. Issues remain open and none was closed. Rocky's seed pins EPEL `python3-pyOpenSSL` 25.0.0 as a visible environment exception; historical dependency evidence remains in `release46-rocky-excluded-dependency-block.md`.

This directory contains sanitized, non-secret audit artifacts from prior candidates. Source/RPM identity, lab preflight, guest snapshots, seed update results, lifecycle probes, Multi-Node placement and recovery, isolation probes, backups/restores, failure injection, concurrency probes, repository test results, and dependency screening are retained as candidate-specific history. They must not be used as Release 47 PASS evidence. Raw prior RC logs remain ignored because they have not passed a full secret-redaction review.

The Release 43 package manifest and its scoped guest observations are retained as historical evidence in `release43-candidate.md`. They do not validate Release 46.

The prepared seeds were sourced from official GenericCloud images, checked against official SHA-256 manifests, updated with `dnf -y update`, booted once with the updated kernel, and shut down cleanly. Source image SHA-256 values recorded during this preparation:

* AlmaLinux 10.2 `AlmaLinux-10-GenericCloud-10.2-20261012.0.x86_64.qcow2`: `cbee4726fc0f5a60694bb4f289003cc221e715dfbacebcce76b54daf386d8eca`.
* CentOS Stream 10 `CentOS-Stream-GenericCloud-10-20261019.0.x86_64.qcow2`: `61a925943be6f1352c5841d6d79e87f9864d265bb062495034408a83ea544b30`.

Official references: [AlmaLinux downloads](https://almalinux.org/get-almalinux/) and [CentOS Stream 10 cloud images](https://cloud.centos.org/centos/10-stream/x86_64/images/).
