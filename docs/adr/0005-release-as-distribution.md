# 0005. Release as Distribution

- Status: Accepted
- Date: 2026-10-17

## Context

The primary consumption model is a "content repo" building its site in GitHub Actions without a Haskell toolchain. Cozyll therefore needs to ship a runnable generator rather than deploy a hosted site.

## Decision

There is no hosted site deployment. Releases ship the executable (not statically linked) plus `templates/` and `assets/` as `cozyll-kit.tar.gz`, with a `cozyll-kit.tar.gz.sha256` checksum. Content repos pull a release and run it in their CI.

The release workflow (`.github/workflows/release.yml`) auto-tags on a `version:` bump in `cozyll.cabal`, publishes a GitHub draft release and a Hackage candidate, and deploys documentation via GitHub Pages.

## Consequences

- Content repos need no Haskell toolchain to build their site.
- Templates and assets ship with the kit, so the released generator has its defaults available.
- The binary is ubuntu-only and not statically linked; other platforms must build from source and therefore still need ghc/cabal.
- Content repos must hand-roll the download and extraction step.
- The Hackage candidate is secondary and gated behind `HACKAGE_ENABLED`.
- Note: the `cozyll-kit.tar.gz` assembly and GitHub Pages docs deployment postdate the initial 2026-10-17 release workflow; see `.github/workflows/release.yml`.
