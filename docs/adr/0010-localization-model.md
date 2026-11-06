# 0010. Localization Model

- Status: Accepted
- Date: 2026-11-01

## Context

The project wanted multi-language support beyond the earlier hardcoded `en`/`es`/`ja` enum.

## Decision

A required `localization.yaml` with the shape `{id: {locale: string}}` plus a `t("id")` template function provides localized strings.

- The language model is open: `language:` accepts any 2-letter ISO 639-1 code plus an optional region (`pt-BR`), normalized in `src/Cozyll/Domain/Language.hs`.
- Lookup resolves the page language and falls back `xx-YY` → `xx`; the build fails when a string a template consumes is missing (`src/Cozyll/Localization.hs`).
- A reserved `_ogLocaleDefaultRegion` key supplies each language's `og:locale`.
- Dates stay `YYYY-MM-DD` (`src/Cozyll/Metadata.hs`).

`localization.yaml` is part of `requiredContent` in `src/Cozyll/Config.hs`.

## Consequences

- Any locale is supported without code changes.
- The file is required even for single-language sites.
- Missing translations fail the build rather than rendering an empty string.
- Locale fallback is deterministic.
