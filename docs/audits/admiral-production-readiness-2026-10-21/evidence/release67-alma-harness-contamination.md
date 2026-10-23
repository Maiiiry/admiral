# R67 AlmaLinux audit-harness contamination record

**Disposition: NOT A PRODUCT FINDING; EXCLUDED FROM RELEASE 67 runtime credit.**

Audit ID: `ADM-AUDIT-2026-10-21`  
Candidate: Admiral RC5 `0.0.1rc5-67.el10`, x86_64  
Guest: `adm-r67-alma-single`, AlmaLinux 10.2, 2 vCPU / 2 GiB  
Date: 2026-10-23 UTC

## What happened

While `admiral-install --single-node --validation-seed` was still running, an
audit postcheck queried Podman as `admiral-apps`:

```text
runuser -u admiral-apps -- podman ps -aq
```

At that point `/etc/subuid` and `/etc/subgid` did not yet contain an
`admiral-apps` range. Podman initialized its rootless user namespace with only
the account's single host UID/GID mapping (`0 992 1`). Ansible later configured
`admiral-apps:720896:131072`, but the already-running rootless namespace kept
the old map.

The first test workload then failed while unpacking `docker.io/library/postgres:16`:

```text
potentially insufficient UIDs or GIDs available in user namespace
(requested 0:42 for /etc/gshadow)
...
lchown /etc/gshadow: invalid argument
```

Fleet could not find the DB container during its readiness check, the provision
operation failed, and the helper's cleanup completed. A subsequent Podman
inventory returned no containers; pods, volumes, units and files were not
independently enumerated during this contaminated attempt. The observed raw test was
`packaging/build/validation/rc5-r67/alma-single-lifecycle.log` (SHA-256
`ffdc641da15de66d252aa60c0d44608454b5126b8d07cdf92cd76bc9ba1abfe9`). The
installer itself completed with `ok=231 changed=97 unreachable=0 failed=0`,
but this guest is not used as clean R67 runtime evidence because the audit
probe altered rootless Podman state during setup.

## Diagnosis check

After preserving the failed run and confirming the workload resources were
absent, `podman system migrate` was run on this disposable guest. The resulting
UID and GID maps included the configured `1 720896 131072` subordinate ranges.
A retry then passed the lifecycle (`op_b89b43ffc7b0f4bd`,
`inst_42016c2aa8b044c1`; raw-log SHA-256
`859deecfadcfc405973b3e64b41fd39f92b3fedf6a417f9e178c781c8406c194`). This
retry confirms the guest-state diagnosis but is also excluded from clean
candidate credit because it followed a manual migration.

## Clean reproduction on a fresh overlay

A fresh overlay, `adm-r67-alma-clean-single`, was created from the same updated
seed. Before installer completion, checks were limited to OS identity, SELinux,
SSH readiness and package inventory; no Podman command ran. The secure installer
completed with `ok=231 changed=97 unreachable=0 failed=0` in 379 seconds. The
post-install rootless UID/GID maps included `1 720896 131072`, and the first
workload lifecycle passed without `podman system migrate`:

* provision `op_c9f680efc7fc35f4` succeeded;
* replay with the same idempotency key returned the same operation and instance
  `inst_35cd96a49ee5679b`;
* PostgreSQL became ready on the first poll; a SQL marker round-tripped;
* the loopback application endpoint returned HTTP 200;
* deprovision `op_aa8d0d9f89deb9e0` succeeded and left no matching runtime
  resources.

The clean lifecycle raw-log SHA-256 is
`5434cc851d4b070496d03a15773584268296b63649a38e43ffa93a4d6c45066a`.
Installation, postcheck, reboot and post-reboot logs and hashes are in
[`release67-single-node-targeted.md`](release67-single-node-targeted.md).

## Conclusion and prevention

The first failure was caused by an audit command running Podman before the
installer finished, not by RPM packaging or the clean installer flow. The clean
overlay passed without manual migration. Future install runs must not invoke
rootless Podman probes until the secure installer has exited successfully and
the subordinate UID/GID ranges are present. No Admiral product defect or
release-blocking issue was opened from this contaminated run.
