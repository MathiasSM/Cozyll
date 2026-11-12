# 0012. Brand and Static Assets

- Status: Accepted
- Date: 2026-11-10
- Amended: 2026-11-12

## Context

The vendored theme references a favicon set and a web manifest, but earlier versions
produced them only when `content/media/branding/logo.svg` happened to exist, while
`site.logo` was used only for JSON-LD. The two could disagree (`images/logo.png` in
JSON-LD vs the SVG brand), and a `site.logo` pointing at a missing file was advertised as
a 404. Media publication was a whitelist (`photos/` rasters, `branding/`, `icons/` SVGs),
so any other file under `content/media/` was dropped without a warning, and there was no
supported way to publish a file at the site root (for example `CNAME`, `_headers`, or a
hand-made icon).

## Decision

- **`site.logo` is the single brand source.** It accepts a site path
  (`images/logo.svg`) or an absolute URL (`https://…`, `//…`) and drives the header logo,
  the favicon `<link>` set, the manifest icons and JSON-LD. A local path resolves to the
  file that publishes it: `content/static/<path>` first, then `content/media/<rest>` or
  `content/media/branding/<rest>` for `images/<rest>`. An SVG or PNG source generates the
  icon set (`favicon.ico`, `favicon.svg` for an SVG source, `apple-touch-icon.png`,
  `favicon-192.png`, `favicon-512.png`); any other source is used as a single icon. There
  is no implicit `media/branding/logo.*` discovery: `media/branding` is only one place a
  local source may live.
- **No logo, no icons.** With no `site.logo` the icon list is empty: no icon links, no
  manifest `icons` key, no JSON-LD `logo` and no header logo.
- **Missing source.** A local `site.logo` that the build cannot publish warns and omits
  the logo everywhere; the next major will likely make it a build error. `data:` URLs are
  rejected, because the logo is repeated in every page and manifest.
- **Wholesale media.** Every file under `content/media/` is published:
  `media/branding/x` → `/images/x`, any other `media/<dir>/x` → `/images/<dir>/x`, and
  `media/x` → `/images/x`. `.dot` sources still render to PNG. SVG files keep their
  compile-time roles (`$iconRaw$`, `$partial$` inlining).
- **Static passthrough.** `content/static/**` is copied verbatim to the site root. A static
  file with the same path as a generated icon wins, and the generator logs it.
- ImageMagick (`magick` or `convert`) is required only when a brand source must be
  converted or a `.dot` source is present.

## Consequences

- A bare content repo builds and checks cleanly; adding `site.logo` opts into the icon
  pipeline.
- The head template, the header, the manifest and JSON-LD cannot drift: all render from
  the same resolved brand.
- Sites that relied on implicit `media/branding/logo.*` discovery must set `site.logo`.
  Until the next major, a missing source warns and omits the logo instead of failing.
- The media rules are predictable: anything under `media/` is public, so private working
  files belong elsewhere.
- `content/static/` gives consumers a general root-level escape hatch without special cases.
