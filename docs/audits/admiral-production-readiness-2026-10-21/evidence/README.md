# Evidence directory

## Current candidate

Release 46 source pins and package fields were prepared at root commit `7223561646b60d3c24e8bfb257d544a5eb6dea04`; all six RPMs were built and targeted Single-Node probes were recorded. Release 47 was partially tested and invalidated by #237. Release 48 was built from root package commit `5bb18b1` and staged locally, but no VM execution started. It was superseded before testing because the pinned common source lacked the #234 Ansible facts migration. The fix is pushed in root `be20545` with CI green; Release 49 source pin, six `Release` bumps and helper defaults are prepared locally, but its RPMs are not built and completion remains 0/8. The #237 product fix is in R48 at `admirald@d50523f` with CI green; #238's helper fix/test is pushed with CI green. Exact historical R48 metadata and hashes are in `release48-candidate.md` and `release48-rpm-sha256.txt`; R47 invalidation evidence remains in the Release 47 files. Rocky's seed pins EPEL `python3-pyOpenSSL` 25.0.0 as a visible environment exception; historical dependency evidence remains in `release46-rocky-excluded-dependency-block.md`.

This directory contains sanitized, non-secret audit artifacts from prior candidates. Source/RPM identity, lab preflight, guest snapshots, seed update results, lifecycle probes, Multi-Node placement and recovery, isolation probes, backups/restores, failure injection, concurrency probes, repository test results, and dependency screening are retained as candidate-specific history. They must not be used as Release 47 PASS evidence. Raw prior RC logs remain ignored because they have not passed a full secret-redaction review.

The Release 43 package manifest and its scoped guest observations are retained as historical evidence in `release43-candidate.md`. They do not validate Release 46.

The prepared seeds were sourced from official GenericCloud images, checked against official SHA-256 manifests, updated with `dnf -y update`, booted once with the updated kernel, and shut down cleanly. Source image SHA-256 values recorded during this preparation:

* AlmaLinux 10.2 `AlmaLinux-10-GenericCloud-10.2-20261012.0.x86_64.qcow2`: `cbee4726fc0f5a60694bb4f289003cc221e715dfbacebcce76b54daf386d8eca`.
* CentOS Stream 10 `CentOS-Stream-GenericCloud-10-20261019.0.x86_64.qcow2`: `61a925943be6f1352c5841d6d79e87f9864d265bb062495034408a83ea544b30`.

Official references: [AlmaLinux downloads](https://almalinux.org/get-almalinux/) and [CentOS Stream 10 cloud images](https://cloud.centos.org/centos/10-stream/x86_64/images/).
