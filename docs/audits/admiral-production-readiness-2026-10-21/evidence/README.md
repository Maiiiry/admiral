# Evidence directory

## Current candidate

Release 46 source pins and package fields were prepared at root commit `7223561646b60d3c24e8bfb257d544a5eb6dea04`; all six RPMs were built and targeted Single-Node probes were recorded. No complete Release 46 cell passed. Its observations do not carry forward. The active Release 47 matrix is Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10 x86_64, each in Single-Node and Multi-Node. Release 47 source refs and Release fields are prepared; the RPM build is pending and the matrix starts at 0/8. Rocky's seed pins EPEL `python3-pyOpenSSL` 25.0.0 as a visible environment exception. Historical Rocky dependency evidence remains in `release46-rocky-excluded-dependency-block.md`.

This directory contains sanitized, non-secret audit artifacts from prior candidates. Source/RPM identity, lab preflight, guest snapshots, seed update results, lifecycle probes, Multi-Node placement and recovery, isolation probes, backups/restores, failure injection, concurrency probes, repository test results, and dependency screening are retained as candidate-specific history. They must not be used as Release 47 PASS evidence. Raw prior RC logs remain ignored because they have not passed a full secret-redaction review.

The Release 43 package manifest and its scoped guest observations are retained as historical evidence in `release43-candidate.md`. They do not validate Release 46.

The prepared seeds were sourced from official GenericCloud images, checked against official SHA-256 manifests, updated with `dnf -y update`, booted once with the updated kernel, and shut down cleanly. Source image SHA-256 values recorded during this preparation:

* AlmaLinux 10.2 `AlmaLinux-10-GenericCloud-10.2-20261012.0.x86_64.qcow2`: `cbee4726fc0f5a60694bb4f289003cc221e715dfbacebcce76b54daf386d8eca`.
* CentOS Stream 10 `CentOS-Stream-GenericCloud-10-20261019.0.x86_64.qcow2`: `61a925943be6f1352c5841d6d79e87f9864d265bb062495034408a83ea544b30`.

Official references: [AlmaLinux downloads](https://almalinux.org/get-almalinux/) and [CentOS Stream 10 cloud images](https://cloud.centos.org/centos/10-stream/x86_64/images/).
