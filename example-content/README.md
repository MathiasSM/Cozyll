Example content
===============================================================================

This directory is the *example* content for the site generator. It is fake,
self-documenting content — not a replica of any real site — and serves two
purposes:

1. It is the fixture for the golden (snapshot) tests.
2. It is what `SITE_ENV=example` builds at the site root (drafts hidden, like
   `prod`).

Structure
-------------------------------------------------------------------------------

- `website.yaml` — site identity, contact, manifest, highlight, feed, robots,
  security, trust, and funding. Neutral values.
- `socials.yaml` — example accounts exercising `showContact`/`showAbout` and
  icon inlining.
- `data/` — YAML data files exposed to templates. `groups.yaml` is a list of
  the post groups (looped with `$for(groups)$`) with a schema and icons;
  `features.yaml` is a list of demonstrated features; `meta.yaml` is a map read
  with dotted keys (`$meta.author.location$`).
- `writings/` — every page and post. See below for the groups.
- `projects/` — YAML projects listed on the showcase page.
- `media/` — the logo (for favicons) and icons inlined into templates and data
  files.
- `templates/` — content-provided templates: one override of a vendored
  template (`minimal.html`, which adds a class), and new partials used via
  `$partial(...)$`.
- `css/` — additional styles. New classes only; nothing vendored is overridden.

Writings
-------------------------------------------------------------------------------

Standalone pages: `home` (root), `about`, `contact`, `colophon`, and `404`.

Post groups, each focused on one area:

- `prose` — core Markdown text: headings, emphasis, links, quotes, code,
  footnotes, lists, smart typography, and a long document with a table of
  contents.
- `tables` — the four Pandoc table syntaxes (pipe, simple, grid, multiline),
  alignment, captions, and a deliberately too-wide table.
- `code` — syntax-highlighted code blocks, fenced attributes, and MathJax math.
- `languages` — `language:` front matter (Spanish, Japanese), embedded Chinese
  and Korean via `lang` spans, and ruby text with its toggle.
- `elements` — raw HTML, forms, fenced divs, definition lists, task lists
  (read-only vs interactive), bracketed spans, figures, and the images toggle.

`showcase` is the projects group; its items live in `projects/`.

The golden tests build this content with `SITE_ENV=example`, so draft posts and
pages (for example `writings/prose/draft.md`) are present here but excluded
from the output — the snapshot confirms they are hidden.
