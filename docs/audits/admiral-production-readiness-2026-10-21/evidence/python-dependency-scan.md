# Python dependency screening

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Date: 2026-10-21 UTC. Package metadata came from the AlmaLinux 10.2 x86_64 three-node hub (Release 42 candidate), with direct runtime validation of Harbor's Markdown helper on the Rocky Linux 10.2 and Fedora Rawhide x86_64 Single-Node guests.

The screen queried OSV's public API with PyPI names and versions for 24 installed top-level Python runtime packages. The response contained 57 advisory records across six package names; aliases reduce these to 28 unique CVE IDs. This is an upstream version screen, not a scan of RPM source patches or binary reachability. Raw API response is kept only in the ignored mode-0600 validation directory; SHA-256: `6486018623b65699cbe0019814a4b5e1281f4b9aa5be574eb6d4914c06e3952c`.

| RPM-provided Python package | AlmaLinux version | Unique CVE aliases returned |
| --- | --- | ---: |
| Werkzeug | 3.1.3 | 4 |
| requests | 2.32.4 | 1 |
| cryptography | 43.0.0 | 5 |
| Mistune | 3.2.1 | 10 |
| urllib3 | 1.26.19 | 7 |
| idna | 3.7 | 1 |

The direct Mistune probe is stronger evidence than the package-version match: the installed Harbor helper emitted a Markdown link with a percent-encoded `javascript:` scheme on both Rocky 10.2 and Fedora Rawhide. This reproduces the unsafe output described by [Mistune advisory GHSA-8c25-4j27-2rv3](https://github.com/lepture/mistune/security/advisories/GHSA-8c25-4j27-2rv3), fixed upstream in Mistune 3.3.0. No browser execution was performed. Its use of `escape=True` escapes HTML markup but does not block the rendered URL scheme. The content authoring path is admin-protected; see `ADM-F-004` for the bounded impact statement.

Other OSV matches remain triage signals, not confirmed Admiral findings. For example, some cryptography advisories concern OpenSSL bundled in PyPI wheels, whereas these RPM packages use the distribution build; several other matches concern utility functions or input paths not yet shown reachable from Admiral. RPM changelogs/backports, call-site reachability, and the complete Fedora Python package set were not audited. A DNF `updateinfo list --security` query on the AlmaLinux hub showed no available security advisories at that metadata snapshot; that result does not prove the installed RPMs are free of vulnerabilities.

Reproduce by querying OSV `POST https://api.osv.dev/v1/querybatch` with `ecosystem: "PyPI"`, each package name above and its listed version. Recheck RPM NEVRAs and changelogs on each target guest before treating any upstream match as an affected installed package.
