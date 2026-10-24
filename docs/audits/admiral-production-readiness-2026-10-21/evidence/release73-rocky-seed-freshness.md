# Release 73 Rocky Linux 10 seed freshness

**Preflight result: PASS for seed freshness only.** This does not add runtime-matrix credit.

## Seed identity

- OS: Rocky Linux 10.2 x86_64.
- Seed file: /var/lib/libvirt/images/admiral-validation/seeds/Rocky-10.2-seed-20261024-r73-clean.x86_64.qcow2.
- SHA-256: 616820a180af2505201ae0db17a22b8c0c0516c692c958ac19920a4f078b859e.
- Seed preparation record: 2026-10-24T11:09:48Z; the seed was fully updated and its own dnf check-update returned 0.
- Kernel: 6.12.0-211.68.1.el10_2.x86_64.
- Repository configuration: Rocky BaseOS, AppStream, CRB and Extras; EPEL; Admiral COPR; and the signed local R73 EL10 repository.
- The seed contains the runtime dependency set used by R73, including Flask 3.1.3-3, Flask-Alembic 3.3.0-4, Flask-Login 0.6.3-9, Flask-SQLAlchemy 3.1.1-10, Mistune 3.4.0-1, SQLAlchemy 2.0.55-4, typing-extensions 4.16.0-1, and the EPEL pyOpenSSL 25.0.0-1.el10_1 validation pin. The six Admiral RPMs are installed by the validation installer, not baked into this OS seed.

## Fresh repository check

At 2026-10-24T13:18:39Z, a fresh guest overlay cloned from the seed ran `dnf -q --refresh check-update`. It returned exit 0 with no offered updates. The subsequent repository/package inventory at 13:19:13Z confirmed the repositories above were enabled and the Python dependency NEVRAs matched the R73 EL10 seed set.

Protected raw captures:

- packaging/build/validation/rc5-r73/runtime/seed-freshness/rocky-fresh-clone-check-20261024T131839Z.txt — SHA-256 36eaa172d2c333dade64adfdb383bc9328a749814d76e4adfd63903c8728e239.
- packaging/build/validation/rc5-r73/runtime/seed-freshness/rocky-fresh-clone-repos-20261024T131913Z.txt — SHA-256 1930218861f11b25caed2b185a79e15c20e284c5306e42c9d1aa33f40e1f22aa.
- The existing-candidate-guest SSH probe was reset before authentication and executed no command. Its protected capture is retained separately; it is not a product failure. The successful check used a new overlay from the immutable seed.

Because the updated repositories offered no newer packages at check time, no additional `dnf update` transaction was needed and the seed hash was left unchanged. This is time-bounded: run the same fresh-clone check immediately before the next validation series. The Rocky R73 Single-Node and Multi-Node guest overlays were created from this exact seed; their selected R73 RPM payload is unchanged.
