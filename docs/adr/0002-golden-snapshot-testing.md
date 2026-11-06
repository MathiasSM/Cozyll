# 0002. Golden Snapshot Testing

- Status: Accepted
- Date: 2026-10-09

## Context

A generator's output is thousands of HTML files. Unit tests cover pure logic but not the end-to-end build. There was no regression safety across template and context changes.

## Decision

A `golden` test suite (`test/Golden.hs`) builds `example-content/` under the `Example` environment (equivalent to `SITE_ENV=example`) into a temporary directory, pins `siteCurrentYear = 2021` for determinism, and compares the result against `test/golden/`. Non-image files are compared byte-for-byte. Images are compared through `test/golden/images.txt`, which records each image's format and dimensions.

Snapshots are updated with `cabal test golden --test-options='--accept'`.

## Consequences

- Template, context, and rule regressions are caught by the full-site build.
- Output is deterministic because the current year is pinned.
- `example-content/` doubles as both the golden fixture and self-documentation.
- Intentional output changes require an explicit `--accept` snapshot update.
- Image comparison checks format and dimensions, not pixel content.
- Later amended in 3.0.0.0 (2026-11-01): golden snapshots switched from `test/fixtures/content` to `example-content/`.
