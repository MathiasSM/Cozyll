# 0007. Theme Override Model

- Status: Proposed
- Date: 2026-10-23

## Context

The generator needs a vendored default theme plus site-specific tweaks without forking the whole theme.

This is recorded as an implementation contract rather than a fully blessed architectural decision: the Haskell code references specific entry-point template names, and the CSS is largely base-style reuse.

## Decision

Vendored defaults in `templates/` and `assets/css/` ship in the release kit. A content repo overrides them per file:

- `content/templates/<name>` shadows `templates/<name>`, including `$partial` references, with fallback to the vendored copy.
- `content/css/*.css` is concatenated after the vendored styles, relying on the cascade.

`resolveTemplate` in `src/Cozyll/Config.hs` picks the content override when present, else the vendored default. `discoverContentTemplateNames` in `src/Cozyll/Theme.hs` is non-recursive, so only top-level template files are discovered.

## Consequences

- Generic defaults mean a bare content repo still builds.
- The theme contract is simply "override by filename".
- The status is Proposed because the mechanism is a contract, not a deeply considered trade-off.
- Non-recursive discovery means nested content template directories are not picked up as overrides.
- Amended in 3.4.0.0 (2026-11-10): overrides take effect on the next build. Every render path
  records a pattern dependency over the union of vendored and content templates (and template
  compilation records it too, because `$partial$` paths are rewritten at compile time), so
  adding or removing an override invalidates pages, feeds, sitemap and redirects without a
  `clean`. The contract is documented in `docs/theming.md`, which ships in the kit.
