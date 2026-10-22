# Evidence directory

## Current candidate

Release 50 was built from root package-preparation commit `fa5d585`, staged in both isolated local repositories, and queried for exactly six NEVRAs. No VM installed R50. Build review found that `admiral-common.spec` had no `%check` (#244), so R50 was superseded before runtime validation. Its NEVRAs, hashes and restricted build-log hash are recorded in `release50-candidate.md` and `release50-rpm-sha256.txt`. The proposed common payload syntax check is committed in root `012a571` with green CI [39727055542](https://github.com/admiral-project/admiral/actions/runs/39727055542). Release 51 preparation has all six Release fields bumped and selects that source commit; its packaging commit, CI and RPM build remain pending. Matrix completion is **0/8**. Issues remain open; no issue was closed. Rocky's seed pins EPEL `python3-pyOpenSSL` 25.0.0 as a visible environment exception; historical dependency evidence remains in `release46-rocky-excluded-dependency-block.md`.

This directory contains sanitized, non-secret audit artifacts from prior candidates. Source/RPM identity, lab preflight, guest snapshots, seed update results, lifecycle probes, Multi-Node placement and recovery, isolation probes, backups/restores, failure injection, concurrency probes, repository test results, and dependency screening are retained as candidate-specific history. They must not be used as Release 47 PASS evidence. Raw prior RC logs remain ignored because they have not passed a full secret-redaction review.

The Release 43 package manifest and its scoped guest observations are retained as historical evidence in `release43-candidate.md`. They do not validate Release 46.

The prepared seeds were sourced from official GenericCloud images, checked against official SHA-256 manifests, updated with `dnf -y update`, booted once with the updated kernel, and shut down cleanly. Source image SHA-256 values recorded during this preparation:

* AlmaLinux 10.2 `AlmaLinux-10-GenericCloud-10.2-20261012.0.x86_64.qcow2`: `cbee4726fc0f5a60694bb4f289003cc221e715dfbacebcce76b54daf386d8eca`.
* CentOS Stream 10 `CentOS-Stream-GenericCloud-10-20261019.0.x86_64.qcow2`: `61a925943be6f1352c5841d6d79e87f9864d265bb062495034408a83ea544b30`.

Official references: [AlmaLinux downloads](https://almalinux.org/get-almalinux/) and [CentOS Stream 10 cloud images](https://cloud.centos.org/centos/10-stream/x86_64/images/).
