# Go dependency and build-toolchain scan

Audit ID: `ADM-AUDIT-2026-10-21`<br>
Scanned: 2026-10-21 UTC.<br>
Tool: `govulncheck v1.9.0`, source/symbol mode, vulnerability database last modified `2026-10-21T00:27:29Z`.<br>
Raw scanner output remains outside Git in ignored `packaging/build/validation/rc5-r42/` files with mode `0600`; hashes follow.

## Candidate binary identity

Go build metadata was read from the installed Release 42 binaries. `admirald`, `admiral-fleet` and `admiralctl` were built with `go1.26.7 (Red Hat 1.26.7-2.el10_2)`, `GOARCH=amd64`, `vcs.modified=false`, and VCS revision `748b703662eafdaf3919bad28787d0264f06bf16`. This matches the root candidate under test. The Go runtime fixes below are therefore relevant to the deployed candidate, not only to the audit host compiler.

| Binary/source module | Reachable advisories reported | Additional uncalled module/package advisories | Scanner result |
| --- | ---: | ---: | --- |
| `admirald` | 11 (10 Go standard-library symbols and `golang.org/x/text@v0.40.0`) | 8 reported as imported/required but not reached | Findings; scanner exited nonzero |
| `admiral-fleet` | 10 Go standard-library symbols | 4 reported as imported/required but not reached | Findings; scanner exited nonzero |
| `admiralctl` | 10 Go standard-library symbols | 4 reported as imported/required but not reached | Findings; scanner exited nonzero |

The reachable IDs in `admirald` were `GO-2026-6809`, `GO-2026-6629`, `GO-2026-6617`, `GO-2026-6613`, `GO-2026-6612`, `GO-2026-6611`, `GO-2026-6610`, `GO-2026-6608`, `GO-2026-6607`, `GO-2026-6605`, and `GO-2026-6603`. The `admiral-fleet` and `admiralctl` scans reported the same ten standard-library IDs, excluding the `x/text` issue.

Examples with fixes available in the advisory database:

| Advisory | Relevant impact in Go vulnerability database | Fixed version |
| --- | --- | --- |
| [GO-2026-6617](https://pkg.go.dev/vuln/GO-2026-6617) | A malicious HTTP/2 client can race HPACK encoder updates and crash an HTTP/2 server | Go 1.26.9 |
| [GO-2026-6603](https://pkg.go.dev/vuln/GO-2026-6603) | HTTP/2 `Trailer` headers can cause disproportionate server memory allocation | Go 1.26.9 |
| [GO-2026-6611](https://pkg.go.dev/vuln/GO-2026-6611) | Excessive CPU from repeated HTTP/2 initial-window changes | Go 1.26.9 |
| [GO-2026-6629](https://pkg.go.dev/vuln/GO-2026-6629) | Crafted `x/text/secure/precis` input can panic; scanned version is v0.40.0 | `golang.org/x/text` v0.41.0 |
| [GO-2026-6809](https://pkg.go.dev/vuln/GO-2026-6809) | `crypto/x509` does not correctly distrust compromised intermediate certificates in affected verification paths | Go 1.26.10 |

Other reachable standard-library IDs are recorded in the raw scanner results; all ten standard-library findings are fixed by the listed Go 1.26.9 or 1.26.10 releases. The Go vulnerability pages do not provide a severity score for every report; audit severity is based on Admiral's reachable attack surface and production impact.

## Runtime reachability check

From connected worker1, the following unauthenticated probe completed TLS/HTTP/2 negotiation to the hub's WireGuard-bound Admirald listener:

```text
curl --http2 -k -sS -o /dev/null -w "http_version=%{http_version} status=%{http_code}\n" https://10.99.0.1:8080/api/v1/status
http_version=2 status=401
```

This confirms that a cluster peer can reach the vulnerable Go HTTP/2 parser before Admirald's application authorization returns 401. It does not demonstrate the CVE-triggering frame sequence or an actual process crash. The HTTP/2 DoS path is treated as a HIGH finding because a connected/compromised worker can target the single control-plane hub; no exploit payload was run.

## Sanitized raw-output hashes

| Ignored raw file | Mode | SHA-256 |
| --- | ---: | --- |
| `audit-govulncheck-admirald.txt` | `0600` | `387793c56abae012b9b1f531796e1d4a7594a40796babb5ebde8f26c375e92b0` |
| `audit-govulncheck-admiral-fleet.txt` | `0600` | `d44a10788a6cbb1931b2e720dc6d9e745f63bc4b3a4c17f8a9b7585080bea129` |
| `audit-govulncheck-admiralctl.txt` | `0600` | `eeb0b9e629d00c2151f6a78040d916fe0e54d8aa318ba2489bd5025c306fbc27` |

This source-mode scan does not cover Python RPM dependencies, the guest OS RPM advisory state, or every runtime-only package. Those scans remain open. No product or RPM change was made as part of this scan.
