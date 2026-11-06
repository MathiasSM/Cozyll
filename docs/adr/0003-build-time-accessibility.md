# 0003. Build-Time Accessibility

- Status: Accepted
- Date: 2026-10-15

## Context

Accessibility is a core project priority (see `ACCESSIBILITY.md`). The generator ships default templates and styles, and wants to catch markup problems automatically rather than relying on manual review.

## Decision

Automated checks run on the final rendered HTML of every page at build time and fail the build on violation. The checks are implemented in `src/Cozyll/Accessibility.hs` and covered by `test/Cozyll/AccessibilitySpec.hs`.

The checks cover:

- image `alt` text
- page `<title>`
- `<html lang>`
- heading structure and order
- link accessible names
- inline-SVG accessible names
- duplicate `id`s
- the presence of a `<main>` landmark

## Consequences

- Structural accessibility issues are caught automatically and gate the build.
- Color contrast and focus visibility remain review-only concerns.
- Custom templates and styles are checked on a best-effort basis; fixing violations remains the site owner's responsibility.
- Later amended in 3.1.0.0 (2026-11-06): the inline-SVG accessible-name check was added.
