# 0008. Authors Model

- Status: Accepted
- Date: 2026-11-01

## Context

Bylines, feeds, `funding.json`, and JSON-LD all need author metadata from a single source. Hardcoding the site author was insufficient.

## Decision

`content/authors.yaml` is a map keyed by author id, and exactly one author sets `siteDefault: true` (validated in `src/Cozyll/Domain/Author.hs`).

- `author:` front matter accepts an id or a list of ids and resolves per-post authors, falling back to the site-default author (`resolveAuthors` in `src/Cozyll/Context/Author.hs`).
- Every author gets a profile page at `/authors/<id>` (see `src/Cozyll/Rules/AuthorPages.hs`), included in `sitemap.xml` (`src/Cozyll/Rules/Sitemap.hs`) and credited by profile URL in JSON-LD (`src/Cozyll/Context/SocialMeta.hs`).
- `addCopyrightNotice: true` opts into a per-post copyright notice.

## Consequences

- Authors are reusable across posts, feeds, and structured data.
- A mandatory site-default author must exist, or the build fails.
- Author pages add URL surface that must be kept in the sitemap.
- The `author: []` empty-list edge is an accepted known edge with no fallback.
