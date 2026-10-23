# RC5 Release 67 scoped Single-Node evidence

**Result: targeted install, lifecycle and reboot scenarios passed on all four target OSes; no OS cell is complete. Matrix remains 0/8.**

Run date: 2026-10-23 UTC  
Candidate source root: `833d15aa4f8e96be30d28dad169b9d06a4d9894d`  
Candidate: Admiral RC5 `0.0.1rc5-67`, x86_64  
Lab: Rocky Linux 10.2 host, KVM guests with 2 vCPU, 2 GiB RAM and 4 GiB host swap. Guests used strict SSH host-key pinning and disposable overlays from the updated R66 seeds. No production infrastructure was used.

## Candidate and seed identity

Fedora used only the Fedora 46 prerelease native candidate packages (`.fc46`); Rocky used only the EL10 native candidate (`.el10`). Each local repository has six Admiral RPMs plus eight distro-tagged Python support RPMs. The exact Admiral NEVRAs and RPM SHA-256 values are in the EL10 and Fedora manifests linked from [`release67-candidate.md`](release67-candidate.md). DNF installed packages normally. No EL10 RPM was installed on Fedora; no `--nodeps`, RPM force option or dependency bypass was used.

| OS / guest | Seed image | Seed SHA-256 | Installed Admiral packages |
| --- | --- | --- | --- |
| Fedora Rawhide 46 x86_64 / `adm-r67-fedora-single` | `Fedora-Rawhide-seed-20261023-r66.x86_64.qcow2` | `5e79471888e5e0bbc24a1d410b8cebc054d0c459b61f970cd89018eb04cb5b7c` | six exact Release 67 `.fc46` NEVRAs |
| Rocky Linux 10.2 x86_64 / `adm-r67-rocky-single` | `Rocky-10.2-seed-20261023-r66.x86_64.qcow2` | `64d918c2b1b8d69d210372d0e80252798178e3ae9b6b7f4af4dbec2b39b5b3d0` | six exact Release 67 `.el10` NEVRAs |
| AlmaLinux 10.2 x86_64 / `adm-r67-alma-clean-single` | `AlmaLinux-10.2-seed-20261023-r66.x86_64.qcow2` | `bcec85910c4ed224d967eb0f696a08af5b24e60d6c3547252bce9dc0a0f02118` | six exact Release 67 `.el10` NEVRAs |
| CentOS Stream 10 x86_64 / `adm-r67-centos-single` | `CentOS-Stream-10-seed-20261023-r66.x86_64.qcow2` | `2cbea69dd6f99334decc0c89441f54d7d78f1e6370e2ecd7771e9cc51096bf68` | six exact Release 67 `.el10` NEVRAs |

The Rocky seed includes the documented validation-only EPEL `python3-pyOpenSSL-25.0.0-1.el10_1` pin. The test skipped the full OS update because each VM was cloned from the updated seed. Consequently, these runs prove the candidate installation transaction in the seeded environment; they do **not** prove dependency closure from an empty OS image or exclude packages already present in the seed.

## Installation and service baseline

Both guests completed `admiral-install --single-node --validation-seed` against the exact native Release 67 repo. Ansible reported zero failed and unreachable tasks. The local release helper confirmed each package's expected release suffix; post-install and post-reboot checks confirmed the full six-package NEVRA set and absence of the other distro's Admiral packages.

| Test ID | OS | Installer result | Baseline observed | Status |
| --- | --- | --- | --- | --- |
| `R67-FEDORA-SN-INSTALL-01` | Fedora Rawhide 46 x86_64 | `ok=237 changed=99 unreachable=0 failed=0`; 441 seconds; installer exit 0 | SELinux Enforcing; no failed systemd units; admirald, Fleet, Harbor, PostgreSQL and firewalld active; CLI status succeeded; worker active/healthy/available | **PASS, scoped** |
| `R67-ROCKY-SN-INSTALL-01` | Rocky Linux 10.2 x86_64 | `ok=231 changed=97 unreachable=0 failed=0`; 920 seconds; installer exit 0 | Same baseline; exact `.el10` packages, SELinux Enforcing, no failed units, CLI status succeeded, worker active/healthy/available | **PASS, scoped** |
| `R67-ALMA-SN-INSTALL-01` | AlmaLinux 10.2 x86_64 / fresh `adm-r67-alma-clean-single` overlay | `ok=231 changed=97 unreachable=0 failed=0`; 379 seconds; installer/helper exit 0 | Six exact `.el10` packages; SELinux Enforcing; five core services active; no failed units; CLI healthy; worker active/healthy/available; rootless UID/GID maps include `720896:131072` | **PASS, scoped** |
| `R67-CENTOS-SN-INSTALL-01` | CentOS Stream 10 x86_64 / fresh `adm-r67-centos-single` overlay | `ok=230 changed=97 unreachable=0 failed=0`; 369 seconds; installer/helper exit 0 | Six exact `.el10` packages; SELinux Enforcing; five core services active; no failed units; CLI healthy; worker active/healthy/available; rootless UID/GID maps include `720896:131072` | **PASS, scoped** |

The Rocky host-side wrapper then emitted `unexpected EOF while looking for matching \`'` after its recorded `installer_exit_code=0` and `audit_end_utc`, and returned 2. The installer process itself and Ansible recap succeeded; independent package, service, API and post-reboot checks passed. This wrapper error is retained as a harness failure, not hidden or attributed to Admiral. Its cause is unresolved. The Fedora first install-helper attempt had a hard-coded `.el10` tag; the helper was corrected in root commit `491621f`, root CI passed, and a fresh Fedora guest then installed the `.fc46` set normally. No second Fedora build of Admiral RPMs was made because the fix changed only validation selection logic.

An earlier Alma attempt (`adm-r67-alma-single`) is excluded from clean runtime credit. While its installer was still configuring the host, a precheck invoked `podman ps` as `admiral-apps` before `/etc/subuid` and `/etc/subgid` had been populated. That initialized a single-ID user namespace; the subsequent PostgreSQL image unpack failed with `lchown /etc/gshadow: invalid argument`. After preserving the failure, confirming no containers remained, and running `podman system migrate`, the UID map included the configured subordinate range and a retry passed. To avoid crediting a manually changed guest, a fresh overlay was then installed without any Podman probe before installer completion; its first workload lifecycle passed without migration. The first failure is a validation-harness contamination, not a product finding. See the detailed harness record in [`release67-alma-harness-contamination.md`](release67-alma-harness-contamination.md).

Raw mode-0600 install logs are local and excluded from Git:

| Evidence | SHA-256 |
| --- | --- |
| Fedora `fedora-single-install-rerun.log` | `c210695727402b96ee109337c9b1df0878e15e9eca0d3fcaf9e7db8ec2c6db6c` |
| Rocky `rocky-single-install.log` | `a824bf0f4596df76ca565727883885a1b71145a79678eb2ec3c20993a072a5e1` |
| AlmaLinux `alma-clean-single-install.log` | `7069c07d8e712f47f89ecb1fbb9935e179aaa0dac7f95f3698cf67ee20593cb4` |
| AlmaLinux `alma-clean-single-postcheck.log` | `a5b7a995f3a98e1e025d831cd9790bff5afbeb8558af5e6f6693a44524dcaa24` |
| CentOS Stream `centos-single-install.log` | `0ae9a80bf103d0b01ffb44b850a5b3fdfa86b9c262381025ad246f8fa343b2e6` |
| CentOS Stream `centos-single-postcheck.log` | `8800c5972cc6f8ce3ddafd8c317b870d672da5e39def3e459aa5fca9ade20017` |

## Workload lifecycle and idempotency

The reproducible helper is [`scripts/r67/r67-single-node-lifecycle.sh`](../scripts/r67/r67-single-node-lifecycle.sh). It applies `examples/apps/e2e-whoami.yaml`, places one instance on the only registered worker, repeats provisioning with the same idempotency key, checks API/runtime health, waits for PostgreSQL, writes and reads a SQL marker, probes HTTP, deprovisions and checks containers, pods, volumes, units and files.

| Test ID | OS | Operation / instance | Observed result | Status |
| --- | --- | --- | --- | --- |
| `R67-FEDORA-SN-LIFECYCLE-01` | Fedora Rawhide 46 | `op_10ed80b1dcd6d9d0` / `inst_27e226d1d9c3e545` | Provision succeeded on `adm-r67-fedora-single`; same-key replay returned the same operation and instance; PostgreSQL ready on poll 2; SQL marker inserted/read back; app bound to loopback `127.0.0.1:40003` and returned HTTP 200; explicit test deprovision succeeded (`op_2dfabc65c76016d7`); zero matching runtime resources remained. | **PASS, scoped** |
| `R67-ROCKY-SN-LIFECYCLE-01` | Rocky Linux 10.2 | `op_52e42f2dae288bfd` / `inst_27285580ceeb6db5` | Provision succeeded on `adm-r67-rocky-single`; same-key replay returned the same operation and instance; PostgreSQL ready on poll 1; SQL marker inserted/read back; app bound to loopback `127.0.0.1:40000` and returned HTTP 200; deprovision succeeded (`op_d756ae135df9ba54`); zero matching runtime resources remained. | **PASS, scoped** |
| `R67-ALMA-SN-LIFECYCLE-01` | AlmaLinux 10.2, fresh overlay without pre-installer Podman probe | `op_c9f680efc7fc35f4` / `inst_35cd96a49ee5679b` | Provision succeeded; same-key replay returned the same operation/instance; PostgreSQL ready on first poll; SQL marker inserted/read; loopback app `127.0.0.1:40000` returned HTTP 200; deprovision succeeded (`op_aa8d0d9f89deb9e0`); zero matching containers, pods, volumes, units or files remained. | **PASS, scoped** |
| `R67-CENTOS-SN-LIFECYCLE-01` | CentOS Stream 10 | `op_508ae521882725c5` / `inst_b98418d391302827` | Provision succeeded; same-key replay returned the same operation/instance; PostgreSQL ready on first poll; SQL marker inserted/read; loopback app `127.0.0.1:40000` returned HTTP 200; deprovision succeeded (`op_52586499c588997a`); zero matching containers, pods, volumes, units or files remained. | **PASS, scoped** |

The first Fedora probe expected the Multi-Node WireGuard bind address and failed its harness assertion when the correct Single-Node endpoint was `127.0.0.1`. A corrected run established HTTP 200 on loopback. A subsequent non-TTY deprovision prompt was cancelled; the runner cleaned the disposable instance, then the successful run used `--force` only to skip the confirmation prompt for that test instance's deprovision. It did not force package installation or bypass DNF dependencies. The initial failures are not reported as product defects or successful tests.

Successful raw mode-0600 logs, excluded from Git:

| Evidence | SHA-256 |
| --- | --- |
| Fedora `fedora-single-lifecycle-final.log` | `fce0f37ccc1bc43f3e83bba7de48f6bdf7d6c2e75f9586373df3a0cccb4c6708` |
| Rocky `rocky-single-lifecycle.log` | `fa78d2492db6e502b485d3cbce864c804f2068865e72155d9531433d76c6b06c` |
| AlmaLinux `alma-clean-single-lifecycle.log` | `5434cc851d4b070496d03a15773584268296b63649a38e43ffa93a4d6c45066a` |
| CentOS Stream `centos-single-lifecycle.log` | `9e6de3dcf60eb2cbf9c9b94c5460618ce83adb01803b2db0be18ad1cceafd18e` |

## Real host reboot and data recovery

The R67 rerun used [`scripts/r65/r65-host-reboot.sh`](../scripts/r65/r65-host-reboot.sh) with `ADMIRAL_RC_RELEASE=67`; the helper now generates release-specific IDs and markers. It provisioned a PostgreSQL workload, wrote a marker, requested a real guest reboot, verified a changed kernel boot ID, sampled recovery, checked HTTP and SQL persistence, then deprovisioned and confirmed cleanup.

| Test ID | OS | Boot ID change | Recovery and data result | Status |
| --- | --- | --- | --- | --- |
| `R67-FEDORA-SN-REBOOT-01` | Fedora Rawhide 46 | `c1adc352-266f-4906-ba04-c1b7548e8b4c` → `b1576470-7dcc-4961-af16-10ae71c71acf` | First API sample: `running/healthy/unavailable`, 0 containers. Second sample: `running/healthy/available`, 3 containers and PostgreSQL ready. HTTP 200; `r67-reboot-persisted` survived; deprovision succeeded; no workload remained. | **PASS, scoped** |
| `R67-ROCKY-SN-REBOOT-01` | Rocky Linux 10.2 | `bea6b2e1-0c28-41f8-8626-c6d0e950f6e7` → `7f2f01d8-a369-46b8-8d31-cc95deb4c24f` | First API sample: `stopped/stopped/unavailable`, 1 container. Second sample: `running/healthy/available`, 3 containers and PostgreSQL ready. HTTP 200; `r67-reboot-persisted` survived; deprovision succeeded; no workload remained. | **PASS, scoped** |
| `R67-ALMA-SN-REBOOT-01` | AlmaLinux 10.2 | `5df41b1c-8a38-4a76-bb58-bae991948e82` → `bfbac0a1-8160-4dfd-ac2d-5e884865901b` | First sample: `running/healthy/unavailable`, 3 containers and DB not ready. Second sample: still unavailable with DB ready. Third sample: `running/healthy/available`; HTTP 200; SQL marker `r67-reboot-persisted` survived; deprovision succeeded. | **PASS, scoped** |
| `R67-CENTOS-SN-REBOOT-01` | CentOS Stream 10 | `144d6aaa-e186-497f-9467-c4bfce3c0c17` → `28087475-0a73-4c6b-8632-987a099ec8ce` | First sample: `running/healthy/unavailable`, one container and DB not ready. Second sample: unavailable with three containers and DB ready. Third sample: `running/healthy/available`; HTTP 200; SQL marker `r67-reboot-persisted` survived; deprovision succeeded. | **PASS, scoped** |

The two-second polling intervals are observation samples, not a recovery SLO. The transient unavailable/stopped states were visible; Admiral did not report available until all three containers and PostgreSQL were ready in the sampled recovery path. These two runs do not prove all crash windows or failure modes.

| Evidence | SHA-256 |
| --- | --- |
| Fedora `fedora-single-reboot-r67.log` | `2fac6ef99c4d98a706c811a25fa3d6b8c8923df77ad4761f353bab9620257c9a` |
| Rocky `rocky-single-reboot-r67.log` | `5acdc19f47408901ed18d126c0a5afed84a686ffb9f2fc8bd5412eb52592fce7` |
| Fedora `fedora-single-post-reboot-check.log` | `3d2701296dfa6dc46183cb0dd5900e4ec4b112b00421b425979a5d0118f2313b` |
| Rocky `rocky-single-post-reboot-check.log` | `2edf62cc19d7e07bf51ef8b7f740230e526fb79fd0187f871f086d7377a557d0` |
| AlmaLinux `alma-clean-single-reboot.log` | `079a30ead13f661dadc0412b28d3dc0d328fb7108f548ef9adeadedfe1a39c38` |
| AlmaLinux `alma-clean-single-post-reboot-check.log` | `7f5c6ceba60a59a4e505f947a4ca73fb582a7afa5640a66ae64c918c73553125` |
| CentOS Stream `centos-single-reboot.log` | `242cb611267188472f3ee1a74dc5ef295d0ba97de379f4e2e47d976decb3ba8a` |
| CentOS Stream `centos-single-post-reboot-check.log` | `d401f98cace4f5a9a83a94f10e1d047cfa97c5ac2a51578ccbc2cb9f627a9253` |

## Remaining Single-Node work

These results are not complete OS cells. All four target OSes now have scoped R67 Single-Node installation, basic workload lifecycle and reboot evidence. The following remain open or not tested for R67: fresh-image dependency closure without preinstalled helper packages; public DNS/TLS routing; backup/restore and external storage; configuration/secret lifecycle; same-host cross-workload isolation negatives; concurrent conflicting operations; Podman/systemd error injection; process/task interruption; memory/disk pressure; orphan reconciliation; and controlled performance/stress measurements. No new product defect was identified by these scoped R67 scenarios. The active matrix stays **0/8**.
