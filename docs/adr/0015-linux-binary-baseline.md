# 0014. Linux Binary Baseline

- Status: Accepted
- Date: 2026-11-10

## Context

ADR 0005 ships the binary from a GitHub Actions build. That build ran on `ubuntu-latest`,
which migrated from Ubuntu 24.04 (glibc 2.39) to 26.04 (glibc 2.43) in late 2026. Because
the binary is dynamically linked, it recorded the newer symbol versions and refused to start
on Debian 13 (glibc 2.41) with `GLIBC_2.43 not found`. The artifact was also built with HPC
coverage, so every run wrote `cozyll.tix` into the consumer's working directory.

## Decision

- Build the kit binary in a **digest-pinned `debian:12` container** (glibc 2.36) in a
  release-only job, with the same GHC/cabal repository variables as CI and without coverage.
- Assert the floor in the job (`readelf --version-info`, no `GLIBC_2.37+`) and prove the
  binary starts on `debian:12` (floor) and `debian:13` (the reported failure).
- Document the floor and runtime libraries (`libgmp10`, `libffi8`, `libnuma1`, `zlib1g`) in
  the README and on the release checklist.
- The coverage-instrumented CI artifact is named `artifact-executable-dev` so it cannot be
  published by mistake.
- A fully static musl build (Alpine, `--enable-executable-static`) is the intended end state;
  it removes the glibc floor but needs its own LGPL/GMP decision and a second toolchain.

## Consequences

- The binary runs on Debian 12+, Ubuntu 24.04+ and Debian 13, with a documented floor.
- The baseline is explicit and pinned; bumping it is a deliberate change with a smoke test.
- The musl follow-up remains open, recorded here rather than implied by a comment.
