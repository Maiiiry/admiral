# Target Single-Node live probes

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Source: root `748b703662eafdaf3919bad28787d0264f06bf16`; Release 42 x86_64 RPM candidate.<br>
Execution date: 2026-10-21 UTC. These were already-installed RC42 VMs, booted for live checks; they were not clean installs in this audit.

| Environment | Guest | Package/OS evidence |
| --- | --- | --- |
| Rocky Linux 10.2 x86_64 | `rc5-r42-rocky-x86-single` | Candidate `0.0.1rc5-42.el10`; Rocky 10.2; SELinux Enforcing |
| Fedora Rawhide x86_64 | `rc5-r42-fedora-x86-single` | Candidate `0.0.1rc5-42.el10`; Fedora Linux 46 Cloud Edition prerelease; SELinux Enforcing |

Both VMs reported healthy through `admiralctl status`; `postgresql`, `admirald`, `admiral-fleet`, Harbor, Flagship and Caddy were active. An unauthenticated request to the loopback status endpoint returned HTTP 401 on each guest. `admirald` and `admiral-fleet` were restarted independently on each VM; both remained active and the platform returned to healthy.

The audit applied `examples/apps/e2e-whoami.yaml`, then ran the same `admiralctl instances provision --app e2e-whoami --tier small --customer audit_20261021_<os> --wait --quiet --output json` command twice per guest. Each request returned `status=succeeded` and a different `inst_*` ID. Both instances ran on the Single-Node guest. This reproduces `ADM-F-001` on both requested x86_64 target distributions. The four instances were deprovisioned through the supported CLI; each operation returned `succeeded`, their durable records ended `deprovisioned`, and rootless `podman ps -a` returned zero containers on both guests. The definition remained available for repeat testing.

The deployed Harbor helper was tested directly from `/usr/lib/admiral/harbor/app/markdown.py` with the system RPM-provided Mistune library. On Rocky, `python3-mistune` was `3.2.1-7.el10`; on Fedora, `3.2.1-6.fc45`. The harmless render-only payload `[probe](javascript%3Aalert%281%29)` produced `<a href="javascript%3Aalert%281%29">probe</a>` on both guests. This confirms the unsafe URL survives the shipped renderer; JavaScript was not executed in a browser. Harbor uses this renderer for `app.description_md` on the public app detail page. The content-edit route is protected by `@admin_required`, so exploitability depends on malicious Markdown reaching that field; no ordinary customer write route was found in the reviewed path. See `ADM-F-004` and the linked Mistune advisory.

The repeated-provision execution window was 13:57:35–13:57:53 UTC on each guest. Cleanup completed by 13:58:49 UTC. The direct Markdown probes were run afterward. Full logs, including operation IDs, remain ignored and mode `0600` under `packaging/build/validation/rc5-r42/`; this tracked record contains only synthetic identifiers and sanitized outcomes.

Reproduction prerequisites: boot the named guest, use the audit `known_hosts` file and validator SSH identity, copy `examples/apps/e2e-whoami.yaml`, and run the commands above. For cleanup, list synthetic customer `audit_20261021_rocky` or `audit_20261021_fedora`, then run `admiralctl instances deprovision <instance_id> --force --wait --output json` for each returned instance. Verify every record is deprovisioned and `sudo -u admiral-apps podman ps -a` is empty.
