# Release 66 Go toolchain and HTTP/2 verification

Audit: `ADM-AUDIT-2026-10-21`
Candidate: RC5 Release 66, exact six-RPM candidate prepared at root commit `c5365da267eca6f1f5246c60a26c7875f07a5ffa`
Run date: 2026-10-23
Scope: x86_64 Go binaries and the Multi-Node worker-to-hub HTTP/2 authentication boundary.

## Exact candidate binary metadata

The three EL10 RPMs were extracted and inspected directly; this does not rely on the host Go compiler or source `go.mod` alone. All three RPMs report VCS revision `c5365da267eca6f1f5246c60a26c7875f07a5ffa`, `vcs.modified=false`, `GOARCH=amd64`, and Go `1.26.10 (Red Hat 1.26.10-1.el10_2)`.

| RPM | SHA-256 | Build metadata |
| --- | --- | --- |
| `admirald-0.0.1rc5-66.el10.x86_64` | `59d1f280e0103abe369159d1084dee85d0f4addafc682573a2e9beb3546eb560` | Go 1.26.10; `golang.org/x/text v0.41.0` |
| `admiral-fleet-0.0.1rc5-66.el10.x86_64` | `8c2bea5d4b02f822fa43984378bc40bb1732254447b311df1df7c87d12f92284` | Go 1.26.10 |
| `admiralctl-0.0.1rc5-66.el10.x86_64` | `df7fe8f357cd0897063ed76b49eb64727bfc72e0f1cd272935899a3fd5a50087` | Go 1.26.10 |

The restricted extracted-binary metadata capture is `/var/lib/libvirt/images/admiral-validation/evidence/r66-go-toolchain-verification-20261023/rpm-build-metadata.txt`, mode `0600`, SHA-256 `28e16acdcbf9c4a5834f3c94dcf918b842d8270b08c4b7b44ec76ab5ef9da770`.

## Vulnerability scan

`govulncheck v1.9.0` scanned `./...` separately in the exact selected `admirald`, `admiral-fleet`, and `admiralctl` source commits listed in [`release66-candidate.md`](release66-candidate.md). The scanner used Go 1.26.10 and the Go vulnerability database snapshot last updated `2026-10-21 00:27:29 UTC`.

| Module | Exact scanned SHA |
| --- | --- |
| `admirald` | `643d203576037a12eba59d534d51d170acae9b5d` |
| `admiral-fleet` | `0c805d6293bfb11fd4f015f1b0ccff520481e627` |
| `admiralctl` | `49cf2428c064434c65af9a14f96975c1bb2db637` |

| Component | Exit code | Reachable code findings |
| --- | ---: | --- |
| `admirald` | 0 | None; scanner also reported four vulnerabilities in required modules that it could not reach from this code |
| `admiral-fleet` | 0 | None |
| `admiralctl` | 0 | None |

Raw scanner output and the summary are mode `0600` in `/var/lib/libvirt/images/admiral-validation/evidence/r66-go-toolchain-verification-20261023/`. The local manifest covers the metadata capture, scanner logs, scanner binary and extracted RPM binaries; manifest SHA-256 is `feeba0e94533cb05ece8c79986dbf78582553e43a511d46ab4c0d0a10d8c1442`. Individual scanner-output SHA-256 values: `govulncheck-admirald.log` `cd603802373c0ab24cb1e859ec21635183b92cc81aeb083b21f3061103e3822f`; `govulncheck-admiral-fleet.log` `3016e51e4eac0d421674d2128bbbdefb2924b4646e0c14a1ab034977ad73fae5`; `govulncheck-admiralctl.log` `3016e51e4eac0d421674d2128bbbdefb2924b4646e0c14a1ab034977ad73fae5`; `govulncheck-summary.txt` `031db9d6300ba564461e9ea8edce12cf2159e1a9834b7a8456c64863049a204c`.

This is a source/symbol scan against the stated database snapshot. It is not a complete RPM/OS dependency audit, and the database timestamp is retained so later reviewers can judge its age.

## Runtime HTTP/2 and authorization probe

On the exact R66 CentOS Stream 10 three-guest lab, worker `centos-r66-w1` had an API-visible fresh heartbeat (12 seconds old) and a fresh WireGuard handshake (25.4 seconds old). Its installed `admiral-common` and `admiral-fleet` were Release 66. From that worker, an unauthenticated request to the hub's WireGuard address negotiated HTTP/2 and received HTTP 401:

```text
curl --http2 --connect-timeout 3 --max-time 10 -k -sS -o /dev/null \
  -w '%{http_version} %{http_code}\n' https://10.99.0.1:8080/api/v1/status
2 401
```

The hub reported all six installed EL10 RPMs at Release 66 and `admirald`, PostgreSQL and WireGuard active. The probe confirms that a cluster peer reaches the patched Go HTTP/2 implementation before application authorization; it does not claim network-level parser isolation. No malformed frames or denial-of-service payload were sent. The scoped runtime probe passed for protocol negotiation and the unauthenticated response boundary.

Restricted runtime evidence and its verified SHA-256 manifest are under `/var/lib/libvirt/images/admiral-validation/evidence/r66-centos-mn-http2-auth-20261023/`, mode `0600`; manifest SHA-256 `04b9c068524d1f6dd802b927aef225dc81d2dba29dcde2a184f3bacc0068ff46`.

## Disposition

The original HIGH Go HTTP/2/toolchain finding was reproduced on Release 42. For Release 66, the actual packaged binaries use the fixed Go toolchain and `x/text` version, all three exact source modules have zero scanner-reachable findings, and the live unauthenticated worker probe receives HTTP 401 through HTTP/2. This R66 evidence resolves the technical finding tracked by [#209](https://github.com/admiral-project/admiral/issues/209), which is already closed upstream. The historical Release 42 evidence remains valid for that old candidate. This result does not establish the full release matrix or complete security readiness.
