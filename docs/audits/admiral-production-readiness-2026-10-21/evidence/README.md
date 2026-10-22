# Evidence directory

## Current candidate

Release 52 is built from signed root preparation commit `c22d05e`; all six `%check` stages passed and both isolated repositories returned exactly the same six R52 NEVRAs. Root CI [39731120097](https://github.com/admiral-project/admiral/actions/runs/39731120097) and all component CI for the selected source SHAs are green. No VM has installed R52 yet; matrix completion remains **0/8**. R52 refs, CI, NEVRAs, hashes and repository checks are in `release52-candidate.md` and `release52-rpm-sha256.txt`. Release 51 was invalidated by #245 after fresh Fedora and Rocky Single-Node installs; none of its results count toward the matrix. Its runtime record is `release51-initial-lifecycle.md`. R50 was superseded before VM testing; R49 was invalidated by #240. Issues remain open and none was closed. Rocky's seed pins EPEL `python3-pyOpenSSL` 25.0.0 as a visible environment exception; historical dependency evidence remains in `release46-rocky-excluded-dependency-block.md`.

This directory contains sanitized, non-secret audit artifacts from prior candidates. Source/RPM identity, lab preflight, guest snapshots, seed update results, lifecycle probes, Multi-Node placement and recovery, isolation probes, backups/restores, failure injection, concurrency probes, repository test results, and dependency screening are retained as candidate-specific history. They must not be used as Release 47 PASS evidence. Raw prior RC logs remain ignored because they have not passed a full secret-redaction review.

The Release 43 package manifest and its scoped guest observations are retained as historical evidence in `release43-candidate.md`. They do not validate Release 46.

The prepared seeds were sourced from official GenericCloud images, checked against official SHA-256 manifests, updated with `dnf -y update`, booted once with the updated kernel, and shut down cleanly. Source image SHA-256 values recorded during this preparation:

* AlmaLinux 10.2 `AlmaLinux-10-GenericCloud-10.2-20261012.0.x86_64.qcow2`: `cbee4726fc0f5a60694bb4f289003cc221e715dfbacebcce76b54daf386d8eca`.
* CentOS Stream 10 `CentOS-Stream-GenericCloud-10-20261019.0.x86_64.qcow2`: `61a925943be6f1352c5841d6d79e87f9864d265bb062495034408a83ea544b30`.

Official references: [AlmaLinux downloads](https://almalinux.org/get-almalinux/) and [CentOS Stream 10 cloud images](https://cloud.centos.org/centos/10-stream/x86_64/images/).
