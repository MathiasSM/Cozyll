# Accessibility

Accessibility is a core priority for this project. We want everyone, including people with disabilities and people using assistive technology, to be able to read, navigate, and contribute.

This is a small project, and our accessibility work is best-effort. This document explains what we target, how we verify it, and how to report a barrier.

## Target

We work toward [WCAG 2.2 Level AA](https://www.w3.org/TR/WCAG22) as an aspirational target, not a claim of verified conformance. In practice we focus on:

- **Semantic HTML** - landmarks, headings, and lists that assistive technology can navigate.
- **Keyboard support** - interactive elements are reachable and operable with a keyboard, with a visible focus indicator and a logical tab order.
- **Screen reader support** - a logical heading hierarchy, accessible names, and correct language declaration.
- **Color contrast** - text and meaningful UI elements have sufficient contrast.
- **Readable content** - plain language, descriptive link text, and meaningful alternative text.

## Scope

The generator ships default templates and styles that aim to produce accessible HTML. This target covers that default output.

Custom templates, styles, and content you provide are processed on a best-effort basis; their accessibility is the responsibility of the site owner.

## How we verify

The generator runs automated accessibility checks on the final rendered HTML of every page at build time, and fails the build if a page violates them. The checks cover: image alternative text, the page `<title>`, the `<html lang>` attribute, heading structure and order, link accessible names, inline-SVG accessible names, duplicate `id`s, and the presence of a `<main>` landmark. See `src/Cozyll/Accessibility.hs` and `test/Cozyll/AccessibilitySpec.hs`.

These checks catch structural issues, not everything. `scripts/check-site.sh a11y` runs
pa11y-ci with the axe runner and groups findings by rule; it is advisory (an unset
`--a11y-fail` makes `all` exit 2), and color contrast is checked manually with axe
DevTools or `npx @axe-core/cli` for now. Focus visibility remains a review concern.

## Contributing

If your change touches templates, styles, or code that emits markup, review the accessibility checklist in the pull request template and run the test suite.

## Reporting accessibility issues

If you run into a barrier, please let us know. We treat accessibility reports as expertise, not complaints.

1. Open an issue using the [accessibility issue template](https://github.com/MathiasSM/Cozyll/issues/new?template=accessibility.yml).
2. Include, when possible:
   - What you were trying to do and what went wrong.
   - The page URL.
   - Steps to reproduce.
   - Your operating system, browser, and assistive technology (with versions).
   - A screenshot or recording, if you are comfortable sharing one.

We will not require you to disclose a diagnosis or other personal information, and we will acknowledge reports promptly and respectfully.

## Ownership

Accessibility is owned by [MathiasSM](https://github.com/MathiasSM). Reports are triaged as part of the project's normal issue flow.

## Feedback

Accessibility is an ongoing practice. To suggest improvements to this statement or our practices, open an issue or a pull request.

## Ruby

When a derived `ruby-data/index.json` is present, the build checks Japanese content:

- **Coverage** — every non-jōyō kanji (grade 1–6 and 8) must be inside a `<ruby>` base, or
  the containing word must be listed in `jaRubySkip`. `lang=` subtrees are respected, and
  `<code>`, `<pre>`, `<rt>`, and `<rp>` are ignored.
- **Readings** — every ruby with a kanji base must have an attested reading in the index;
  `jaRubyAllow` exempts names and creative readings. This proves the pair exists, not that it
  is the intended reading in context.

`jaRubyCheck` (`off`, `warn`, `error`) controls the severity, per site or page. Both checks
only inspect text whose effective `lang` is `ja*`; a page without the index is not checked.
