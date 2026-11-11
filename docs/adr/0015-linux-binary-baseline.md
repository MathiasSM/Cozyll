# 0015. Linux Binary Baseline

- Status: Accepted
- Date: 2026-11-10
- Amended: 2026-11-11 (static executable)

## Context

ADR 0005 ships the binary from a GitHub Actions build. That build ran on `ubuntu-latest`,
which migrated from Ubuntu 24.04 (glibc 2.39) to 26.04 (glibc 2.43) in late 2026. Because
the binary was dynamically linked, it recorded the newer symbol versions and refused to
start on Debian 13 (glibc 2.41). The artifact was also built with HPC coverage, so every run
wrote `cozyll.tix` into the consumer's working directory.

Pinning an older build image (the first fix) works but ties the kit to a glibc floor and to a
second build environment.

## Decision

- Build the kit binary as a **fully static executable** on the normal Ubuntu runner:
  `cabal build exe:cozyll --enable-executable-static` (GHC links the RTS and every
  Haskell/C dependency, including glibc's static libraries), then `strip`.
- Assert the result (`file` says `statically linked`, `ldd` says `not a dynamic
  executable`) and run `--version` in the same job.
- The job is coverage-free, so it never writes `cozyll.tix`; the coverage-instrumented CI
  artifact is named `artifact-executable-dev` so it cannot be published by mistake.
- No container, no pinned distribution image, and no glibc/runtime-library floor in the
  docs or the release checklist.

## Consequences

- The binary runs on any Linux x86_64 distribution, regardless of its glibc version.
- Static glibc has known NSS caveats: `getaddrinfo`/NSS still loads the system's NSS
  modules at runtime, so the only network-using command (`cozyll data fetch`) relies on the
  host's resolver like any other program. This is documented in the README.
- The executable is larger (about 110 MB stripped) because the RTS and dependencies are
  linked in.
- If a future dependency makes static linking impractical, the fallback is per-distribution
  binaries built on the GitHub Ubuntu images (no containers): `ubuntu-24.04` and, while it
  exists, `ubuntu-22.04`.
