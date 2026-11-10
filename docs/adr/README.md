# Architecture Decision Records

Architecture Decision Records for Cozyll, the Hakyll-based static site generator.

| # | Slug | Title | Status | Introduced |
|---|------|-------|--------|------------|
| [0001](0001-content-generator-split.md) | `content-generator-split` | Content Generator Split | Accepted | 2026-10-09 |
| [0002](0002-golden-snapshot-testing.md) | `golden-snapshot-testing` | Golden Snapshot Testing | Accepted | 2026-10-09 |
| [0003](0003-build-time-accessibility.md) | `build-time-accessibility` | Build-Time Accessibility | Accepted | 2026-10-15 |
| [0004](0004-site-env-modes.md) | `site-env-modes` | Site Environment Modes | Accepted | 2026-10-15 |
| [0005](0005-release-as-distribution.md) | `release-as-distribution` | Release as Distribution | Accepted | 2026-10-17 |
| [0006](0006-generic-data-files.md) | `generic-data-files` | Generic Data Files | Accepted | 2026-10-19 |
| [0007](0007-theme-override-model.md) | `theme-override-model` | Theme Override Model | Proposed | 2026-10-23 |
| [0008](0008-authors-model.md) | `authors-model` | Authors Model | Accepted | 2026-11-01 |
| [0009](0009-structured-data-in-house.md) | `structured-data-in-house` | Structured Data In-House | Accepted | 2026-11-01 |
| [0010](0010-localization-model.md) | `localization-model` | Localization Model | Accepted | 2026-11-01 |
| [0011](0011-external-ruby-index.md) | `external-ruby-index` | External Ruby Index | Accepted | 2026-11-10 |

- **0001** — Splits site content into a separate content repo so the generator stays reusable.
- **0002** — Pins full-site golden output to catch template and context regressions.
- **0003** — Fails the build on rendered-HTML accessibility violations.
- **0004** — Defines `prod`/`dev`/`example` build modes through `SITE_ENV`.
- **0005** — Distributes a release kit instead of hosting generated sites.
- **0006** — Exposes arbitrary YAML data files to templates without typed schemas.
- **0007** — Lets content repos override vendored templates and CSS by filename.
- **0008** — Models authors in a single YAML map with a site-default author.
- **0009** — Emits Open Graph and schema.org JSON-LD in-house.
- **0010** — Supports open language codes and localized strings via `localization.yaml`.
- **0011** — Derives JLPT levels, coverage, and reading checks from a committed, external ruby index.
