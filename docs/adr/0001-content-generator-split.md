# 0001. Content Generator Split

- Status: Accepted
- Date: 2026-10-09

## Context

Cozyll began as a generator for the maintainer's personal site. The content was eventually split out. The generator must be reusable by other sites, people, and organizations — not just the personal site, and it may generate sites for others even if only the maintainer uses it today. Keeping personal content in a separate repository serves that goal.

## Decision

Site identity and all content live in a separate "content repo" holding `website.yaml`, `socials.yaml`, `authors.yaml`, `localization.yaml`, `writings/`, `data/`, `media/`, `projects/`, and optional `templates/` and `css/`. The generator itself stays content-agnostic.

A small set of environment variables overrides fields from `website.yaml`: `SITE_TITLE`, `SITE_DESCRIPTION`, `SITE_COPYRIGHT_YEAR`, `SITE_DOMAIN`, `MATHJAX_VERSION`, and `HIGHLIGHT_STYLE` (see `loadSiteConfig` in `src/Cozyll/Cli.hs`).

Required content is enforced at build time: `ensureContentExists` in `src/Cozyll/Cli.hs` checks the `requiredContent` list defined in `src/Cozyll/Config.hs`. A bundled `example-content/` provides self-documenting example output.

## Consequences

- The generator is reusable across sites and carries no site-specific content.
- Missing required content files fail the build instead of silently producing an incomplete site.
- Environment overrides create a second source of truth that must be reasoned about alongside `website.yaml`.
- `SITE_ENV=example` builds the bundled `example-content/` as a complete example site.
- Later amended in 3.0.0.0 (2026-11-01): the bundled `example-content/` replaced the earlier dev-time `/example/` preview pages.
