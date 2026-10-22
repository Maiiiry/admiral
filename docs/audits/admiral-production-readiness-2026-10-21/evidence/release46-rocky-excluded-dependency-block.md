# Rocky Linux 10 Release 46 dependency-resolution block

Audit: `ADM-AUDIT-2026-10-21`  
Candidate under investigation: Admiral RC5 Release 46, six coordinated RPMs  
Disposition: **historical Release 46 dependency-resolution block; not an Admiral runtime finding and not a PASS**

## Scope change

At the time of this Release 46 run, the active target matrix had temporarily removed Rocky Linux 10 after its fresh-install EPEL dependency chain could not be satisfied in the tested Rocky Linux 10.2 environment. The current matrix includes Fedora Rawhide, Rocky Linux 10, AlmaLinux 10 and CentOS Stream 10, each in Single-Node and Multi-Node. Rocky's prepared seed pins the archived EPEL `python3-pyOpenSSL-25.0.0-1.el10_1` RPM to keep the seed's Python dependency set coherent; this historical Release 46 probe remains excluded from matrix evidence.

## Observed dependency conflict

On a fresh Rocky Linux 10.2 x86_64 guest with the Rocky BaseOS/AppStream/CRB repositories and EPEL enabled, DNF could not resolve installation of the exact Release 46 Admiral RPM set. `admirald` requires `certbot`; EPEL's `certbot` depends on `python3-certbot`, then `python3-acme`, which requires `python3.12dist(pyopenssl) >= 25`. The available EPEL candidate was `python3-pyOpenSSL-26.3.0-1.el10_3`, which requires `python3.12dist(cryptography) >= 49` and `< 50`. The enabled Rocky 10.2 BaseOS repositories offered `python3-cryptography` 43.0.0, so DNF reported that no provider could satisfy the EPEL package requirement.

This records an inability of the enabled repositories to solve an external package dependency during the Release 46 installation attempt. It is not evidence of an Admiral runtime defect. To make the exploratory workaround reproducible, the check pinned the exact archived RPM `python3-pyOpenSSL-25.0.0-1.el10_1.noarch` (SHA-256 `eb5d2a6be0e47099c63fa042f83afac12021820bfc0d79fa0f9dcd57b71941dc`). The local RPM is byte-for-byte identical to the object at the [official Fedora EPEL 10.1 archive URL](https://dl.fedoraproject.org/pub/archive/epel/10.1/Everything/x86_64/Packages/p/python3-pyOpenSSL-25.0.0-1.el10_1.noarch.rpm), and `rpmkeys --checksig` reports `digests signatures OK`. Fedora's package catalog lists this build for EPEL 10.2; the current EPEL 10.4 listing is `26.3.0-1.el10_3`. The version pin is an explicit Rocky seed preparation constraint; it does not change normal public DNF resolution and does not count as matrix evidence.

## Execution boundary

Three disposable Rocky Linux guests had been prepared for an exploratory three-node attempt. The normal fresh RPM dependency resolution failed before an ordinary install path could proceed. After the workaround, the exploratory hub installer began its system update; the process was stopped when the scope changed. The guests were shut down. No Release 46 Multi-Node test was run, and no Rocky result contributes to the Release 46 matrix.

An earlier bootstrap helper attempt also failed because it disabled repositories other than the local candidate repository. That was a harness configuration problem and is not the basis for excluding Rocky; the exclusion is based on the separate fresh-guest DNF resolution log below.

## Reproduction

On the fresh Rocky Linux 10.2 guest, enable the normal Rocky BaseOS/AppStream/CRB, EPEL and local candidate repositories, refresh metadata, then install the six Release 46 Admiral RPMs through DNF without pinning or replacing EPEL dependencies. The solver error identifies the `certbot → python3-certbot → python3-acme → pyOpenSSL → cryptography` chain and the unavailable `cryptography >= 49, < 50` provider.

The following ignored local logs remain in `packaging/build/validation/rc5-r46/`, each mode `0600`; hashes allow verification without committing raw guest output:

| Log | SHA-256 | Relevance |
|---|---|---|
| `rocky-hub-rpm-install.log` | `36b0abf5e101ad2b2118a1e7200716ab76da9cde2d471cc8bf8eafe3695ea1dc` | Fresh DNF resolution failure for the Release 46 RPM set. |
| `rocky-hub-direct-epel-query.log` | `0680e770d5ed66e7138f6700b96fed78f0a358c6cd2a9b45fba329026ee3225f` | Versions visible from the enabled repositories, including EPEL pyOpenSSL 26.3 and Rocky cryptography 43. |
| `rocky-hub-certbot-resolution.log` | `f46d37cf061bd1f97a1631d7d456fbac798f55769139df5b3538621ddeb71cde` | Dependency versions after the archived compatibility package was made available. |
| `rocky-hub-rpm-install-compat.log` | `73b38e9210c478248e503ec345a83aff17f98c6ae2a84ee7c5271b2974fdcdf3` | Exploratory installation using the archived EPEL compatibility package; excluded from matrix evidence. |
| `rocky-hub-admin-portal-install.log` | `da967f5d65de98913815ac8846e17620971cadd745ea3673f6c8de2629f2f754` | Installer/system update activity before the exploratory run was stopped. |
| `rocky-hub-repo-diagnostics.log` | `07d27d830d07b29ce108e726c8ed768fa6876068477cc3c267725cc540cc785f` | Earlier mirror/metadata transport diagnostics; not the dependency-resolution basis. |

The compatibility RPM itself remains ignored local data; its exact URL, NEVRA and checksum above identify the fixed version without committing the binary. No credentials or raw logs are committed.
