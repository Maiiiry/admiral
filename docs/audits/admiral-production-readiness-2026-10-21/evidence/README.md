# Evidence directory

This directory contains sanitized, non-secret audit artifacts. Source/RPM identity, lab preflight, guest snapshots, seed update results, Rocky/Fedora Single-Node live probes, Rocky/Fedora Multi-Node placement and recovery, Fedora same-worker isolation probes, AlmaLinux Single-Node and three-node execution, CentOS Stream Single-Node execution, CentOS Stream three-node install/placement/cleanup, local PostgreSQL backup/restore, hub peer-loss/recovery, failed-service injection, concurrent duplicate provisions across workers, worker outage/stale-instance-state/recovery, repository test-suite results, and Go/Python dependency screening are captured here. The CentOS Stream Multi-Node cell remains incomplete: it reproduced peer loss on hub restart, false healthy state with a failed DB service, duplicate provisions, and stale healthy instance state during worker loss. Database process outage, network partition, task replay/lease behavior, conflicting updates/deletes, security, external S3 and volume backup/restore, and performance scenarios remain untested. New installer and full scanner logs remain in the ignored local `packaging/build/validation/rc5-r42/` directory with mode `0600`; their hashes and sanitized summaries are recorded. Raw prior RC logs remain ignored because they have not passed a full secret-redaction review.

The locally built Release 43 package manifest, source pins, CI status and RPM SHA-256 values are in `release43-candidate.md`. Release 42 runtime logs above are preserved as historical evidence; Release 43 still needs fresh guest validation.

The two new x86_64 seeds were sourced from official GenericCloud images, checked against official SHA-256 manifests, updated with `dnf -y update`, booted once with the updated kernel, and shut down cleanly. Source image SHA-256 values recorded during this preparation:

* AlmaLinux 10.2 `AlmaLinux-10-GenericCloud-10.2-20261012.0.x86_64.qcow2`: `cbee4726fc0f5a60694bb4f289003cc221e715dfbacebcce76b54daf386d8eca`.
* CentOS Stream 10 `CentOS-Stream-GenericCloud-10-20261019.0.x86_64.qcow2`: `61a925943be6f1352c5841d6d79e87f9864d265bb062495034408a83ea544b30`.

Official references: [AlmaLinux downloads](https://almalinux.org/get-almalinux/) and [CentOS Stream 10 cloud images](https://cloud.centos.org/centos/10-stream/x86_64/images/).
