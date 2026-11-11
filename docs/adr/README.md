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
| [0012](0012-brand-and-static-assets.md) | `brand-and-static-assets` | Brand and Static Assets | Accepted | 2026-11-10 |
| [0013](0013-build-provenance-and-env-isolation.md) | `build-provenance-and-env-isolation` | Build Provenance and Environment Isolation | Accepted | 2026-11-10 |
| [0014](0014-site-language-and-menus.md) | `site-language-and-menus` | Site Language and Menus | Accepted | 2026-11-10 |
| [0015](0015-linux-binary-baseline.md) | `linux-binary-baseline` | Linux Binary Baseline | Accepted | 2026-11-10 |

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
- **0012** — Derives the icon set from one brand logo, publishes all media, adds `content/static`.
- **0013** — Stamps builds in `_cache` and resets output+cache when the environment changes.
- **0014** — Adds `site.language` and per-language menu labels; scopes `lang` correctly.
- **0015** — Builds the release binary on a pinned Debian 12 baseline (glibc 2.36).
