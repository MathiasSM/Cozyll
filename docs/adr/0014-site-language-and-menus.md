# 0013. Site Language and Menus

- Status: Accepted
- Date: 2026-11-10

## Context

ADR 0010 defines per-page language and localized UI strings, but the site itself had no
language: pages without `language:` defaulted to English, author pages hardcoded it, and the
header claimed `lang="en"` while containing a menu in other languages. Menu labels were a
single front-matter string, so a multilingual site could not localize its own menu even
though the theme already supported a `lang` attribute on entries.

## Decision

- `site.language` in `website.yaml` (ISO 639-1 with an optional region, default `en`)
  describes the site's own voice. It is the default for pages without `language:`, drives
  author pages and the `inLanguage`/`og:locale` fallbacks, and marks the site chrome (title
  and description) only on pages written in another language.
- `nav:` accepts a single string or a map of language to label. When a page is rendered its
  label resolves in this order: the page's language, its base language (`es-MX` → `es`), the
  site's language; if none matches the build fails naming the page, its language and the
  available labels. A label rendered in another language carries `lang`.
- The header no longer declares a language for the whole element; only the chrome and
  cross-language menu entries carry `lang`.

## Consequences

- A site can be primarily Spanish (or Japanese) without per-page overrides everywhere.
- A menu map missing the page's language is a build error, not an English fallback.
- Hakyll does not flatten nested front matter, so Cozyll parses the `nav` object itself and
  validates its shape; templates never see `nav.<lang>` keys.
