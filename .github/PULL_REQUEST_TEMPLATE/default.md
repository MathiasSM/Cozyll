<!--
  Branch: <type/description>
  Target: master
  Keep it short; delete sections you don't need.
-->

## What & why

<!-- One or two sentences: the problem and how this fixes it. -->

## Testing

<!-- What you ran and the result, e.g. `cabal test` -->

## Checklist

- [ ] I have read `CONTRIBUTING.md`
- [ ] `fourmolu` and `hlint` clean
- [ ] Tests pass (`cabal test`)
- [ ] `CHANGELOG.md` updated
- [ ] Docs updated (`README.md` / `CONTRIBUTING.md`) if the behavior changed

## Accessibility

If your change touches user-facing output, review [ACCESSIBILITY.md](ACCESSIBILITY.md) and check the items below that apply. Items are optional and only some will be relevant to your change.

### Content (docs, README, example-content)

- [ ] Headings follow a logical hierarchy and don't skip levels.
- [ ] Link text is descriptive (no "click here" / "read more").
- [ ] Images have meaningful alternative text or are marked decorative.

### UI / code (templates, styles, markup-emitting Haskell)

- [ ] Semantic HTML is used (landmarks, headings, lists).
- [ ] Interactive elements are keyboard-operable with a visible focus indicator.
- [ ] Forms have associated labels.
- [ ] Color isn't the only way meaning is conveyed.
- [ ] `prefers-reduced-motion` is respected (if animations were added).
- [ ] Screen reader behavior was checked at least once.
- [ ] The automated accessibility checks pass (`cabal test`).

## Follow-ups

<!-- Deferred work this PR intentionally leaves out, if any. -->
