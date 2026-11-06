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
