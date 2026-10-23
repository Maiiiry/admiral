# Evidence directory

## Current candidate

RC5 Release 67 is the current locally built candidate, pinned to root commit `833d15aa4f8e96be30d28dad169b9d06a4d9894d`. All six Admiral RPMs were built separately with native Fedora and EL10 toolchains and placed in distro-specific local repositories. Fedora receives only `.fc46` RPMs; EL10 `.el10` binaries are not force-installed there. Scoped Single-Node probes passed on all four target OSes; scoped three-guest Multi-Node bootstrap, placement and selected recovery probes passed on all four. No full cell has passed; matrix completion remains **0/8**. Exact source SHAs, NEVRAs, RPM hashes, runtime evidence and remaining gaps are in `release67-candidate.md` and the linked per-OS reports. Release 66 is invalidated for active matrix credit by #266; its observations remain historical only. Issues remain open; none was closed.

This directory contains sanitized, non-secret audit artifacts from prior candidates. Source/RPM identity, lab preflight, guest snapshots, seed update results, lifecycle probes, Multi-Node placement and recovery, isolation probes, backups/restores, failure injection, concurrency probes, repository test results, and dependency screening are retained as candidate-specific history. They must not be used as Release 47 PASS evidence. Raw prior RC logs remain ignored because they have not passed a full secret-redaction review.

The Release 43 package manifest and its scoped guest observations are retained as historical evidence in `release43-candidate.md`. They do not validate Release 46.

The prepared seeds were sourced from official GenericCloud images, checked against official SHA-256 manifests, updated with `dnf -y update`, booted once with the updated kernel, and shut down cleanly. Source image SHA-256 values recorded during this preparation:

* AlmaLinux 10.2 `AlmaLinux-10-GenericCloud-10.2-20261012.0.x86_64.qcow2`: `cbee4726fc0f5a60694bb4f289003cc221e715dfbacebcce76b54daf386d8eca`.
* CentOS Stream 10 `CentOS-Stream-GenericCloud-10-20261019.0.x86_64.qcow2`: `61a925943be6f1352c5841d6d79e87f9864d265bb062495034408a83ea544b30`.

Official references: [AlmaLinux downloads](https://almalinux.org/get-almalinux/) and [CentOS Stream 10 cloud images](https://cloud.centos.org/centos/10-stream/x86_64/images/).
