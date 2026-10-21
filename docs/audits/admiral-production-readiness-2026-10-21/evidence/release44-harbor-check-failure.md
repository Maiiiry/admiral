# Release 44 Harbor package check failure

Date: 2026-10-21 UTC. Scope: disposable Rocky Linux 10.2 x86_64 audit build host; no production system was touched.

## Reproduction

The coordinated Release 44 RPM build reached Harbor `%check` and failed in `test_render_markdown_rejects_encoded_and_mixed_case_executable_urls` after 202 tests had passed. The rendered HTML retained the percent-encoded JavaScript URL:

```html
<a href="javascript%3aalert%281%29">probe</a>
```

The command was the `rpm-admiral-harbor` target with local RPM dependency checks bypassed using `rpmbuild --nodeps`; the host Python 3.12 environment supplied Mistune 3.2.1. This was a packaging test failure, not a runtime VM result. The candidate was not promoted and no Release 44 matrix cell was counted.

## Cause and fix

`HTMLRenderer(escape=True)` escapes raw HTML but does not filter link schemes. The prior dependency update to Mistune 3.4.0 did not replace the need for application-level URL validation. Harbor commit `4dfce69a13a632f6e49e5168fae99233e0f94314` adds an explicit scheme sanitizer and regression coverage.

After the fix, Harbor's full 347-test suite passed in the local package check. The six focused Markdown and public-route tests passed both with host Mistune 3.2.1 and with the packaged Mistune 3.4.0 RPM. CI is recorded in `release45-candidate.md`.

This finding remains open in GitHub issue [#210](https://github.com/admiral-project/admiral/issues/210) until the rebuilt candidate is installed and verified in the target matrix.
