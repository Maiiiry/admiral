# Evidence directory

## Current candidate

Release 56 is the current locally built candidate, pinned to root commit `042e578efe0470124f47c905ddf493aa335d56d0`. All six package `%check` stages passed; root and five component CI runs are green. Exact source SHAs, NEVRAs and RPM hashes are recorded in `release56-candidate.md` and `release56-rpm-sha256.txt`. Fresh Fedora Rawhide and Rocky Linux 10 Single-Node guests installed the candidate and passed a targeted reboot regression, but no full cell has passed; matrix completion remains **0/8**. The clean repository dependency query failed for Flask/Mistune availability (#201, #257); raw-log hashes are in `release56-runtime-log-sha256.txt`. Release 55 is invalidated by #256 and its VM observations remain historical only. Issues remain open; none was closed. Rocky's seed pins EPEL `python3-pyOpenSSL` 25.0.0 as a visible environment exception.

This directory contains sanitized, non-secret audit artifacts from prior candidates. Source/RPM identity, lab preflight, guest snapshots, seed update results, lifecycle probes, Multi-Node placement and recovery, isolation probes, backups/restores, failure injection, concurrency probes, repository test results, and dependency screening are retained as candidate-specific history. They must not be used as Release 47 PASS evidence. Raw prior RC logs remain ignored because they have not passed a full secret-redaction review.

The Release 43 package manifest and its scoped guest observations are retained as historical evidence in `release43-candidate.md`. They do not validate Release 46.

The prepared seeds were sourced from official GenericCloud images, checked against official SHA-256 manifests, updated with `dnf -y update`, booted once with the updated kernel, and shut down cleanly. Source image SHA-256 values recorded during this preparation:

* AlmaLinux 10.2 `AlmaLinux-10-GenericCloud-10.2-20261012.0.x86_64.qcow2`: `cbee4726fc0f5a60694bb4f289003cc221e715dfbacebcce76b54daf386d8eca`.
* CentOS Stream 10 `CentOS-Stream-GenericCloud-10-20261019.0.x86_64.qcow2`: `61a925943be6f1352c5841d6d79e87f9864d265bb062495034408a83ea544b30`.

Official references: [AlmaLinux downloads](https://almalinux.org/get-almalinux/) and [CentOS Stream 10 cloud images](https://cloud.centos.org/centos/10-stream/x86_64/images/).
