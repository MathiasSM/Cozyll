# 0011. External Ruby Index

- Status: Accepted
- Date: 2026-11-10

## Context

Ruby (furigana) existed as a Markdown-link syntax, with an all-or-nothing toggle. Deriving
JLPT levels and checking that non-jōyō kanji are annotated requires lexical data: kanji
grades and levels, word readings, and per-character alignment. Shipping that data inside
Cozyll would bloat the Hackage package, mix CC BY-SA data into a BSD-3 distribution, and
make the generator's output depend on a fetch at build time.

## Decision

The content repo commits a single derived `ruby-data/index.json`; the build reads it
offline.

- `cozyll data fetch` reads a sources file: the content repo's
  `ruby-data/sources.yaml` when present, else the embedded
  `schema/example.ruby-sources.yaml` (schema `schema/ruby-sources.schema.json`). Each
  source is a repository file or a release asset with a `{ref}` URL; `latest` resolves via
  the GitHub API, and release assets are checked against the API digest when present.
  `data verify`, `data fmt`, and `data sources` maintain it.
- There is no manifest or index hash: git protects the committed index, and `data fetch`
  prints the resolved refs (the sources file records any customisation).
- The index stores a `kanji` table (grade and nullable JLPT), a `words` table
  (surface, reading, level), and `segments` (kanji-run, reading) for verification.
  It is canonically encoded: sorted arrays of tuples, one per line, fixed top-level order.
- Builds never fetch or re-derive. A missing index leaves behaviour unchanged; a malformed
  or non-canonical one fails with a fix.
- Coverage is jōyō-only (grade 1–6 and 8): a Japanese text node may not contain a non-jōyō
  kanji outside a `<ruby>` base unless the word is in `rubySkip`.
- Reading verification uses a dynamic program over `segments`, so multi-kanji runs,
  sokuon, rendaku, and `々` are accepted; `rubyAllow` exempts names and creative readings.
- `rubyCheck` (`off`, `warn`, `error`) is a site-level key with a per-page override.
- The reader control is a threshold `<select>` plus an independent unknown-level checkbox;
  the choice lives in `localStorage`, not in front matter.
- The index size limit is `COZYLL_RUBY_INDEX_LIMIT` (default 8 MiB); there are no
  per-table row caps.

## Consequences

- Builds are deterministic given the committed index and cozyll version.
- The data stays under its upstream licences (CC BY-SA 4.0 and CC BY); content repos carry
  attribution. Cozyll ships no data.
- Updating the index is an explicit, reviewable commit; `gh`/CI builds do not need network.
- Sources are user-overridable (location and version) without rebuilding Cozyll.
- The index is not a Hakyll dependency: after replacing it, run `cozyll rebuild` (or restart
  `watch`).
- Verification proves a reading is attested, not that it is intended in context; names and
  creative readings need `rubyAllow`.
- Consumers must add `ruby.all` to `localization.yaml` for the select label.
