# 0011. Brand and Static Assets

- Status: Accepted
- Date: 2026-11-10

## Context

The vendored theme references a favicon set and a web manifest, but the generator only
produced them when `content/media/branding/logo.svg` happened to exist, and `site.logo` was
used only for JSON-LD. A site without that exact file got dead `<link rel="icon">` and
manifest entries, which `cozyll check` correctly reported. Media publication was a
whitelist (`photos/` rasters, `branding/`, `icons/` SVGs), so any other file under
`content/media/` was dropped without a warning, and there was no supported way to publish a
file at the site root (for example `CNAME`, `_headers`, or a hand-made icon).

## Decision

- **One brand source.** `content/media/branding/logo.svg` (preferred) or `logo.png` is the
  brand. The build derives the published logo, the `<link>` set (`favicon.ico`,
  `favicon.svg` for an SVG source, `apple-touch-icon.png`) and the manifest icons
  (`favicon-192.png`, `favicon-512.png`) from it, in one list shared by the head template
  and `manifest.webmanifest`. `site.logo` stays the published path used by JSON-LD and
  defaults to the brand logo.
- **No logo, no icons.** With no brand source the list is empty: no icon links and no
  manifest `icons` key are emitted, and the build says so. Nothing references a file that
  does not exist.
- **Wholesale media.** Every file under `content/media/` is published:
  `media/branding/x` → `/images/x`, any other `media/<dir>/x` → `/images/<dir>/x`, and
  `media/x` → `/images/x`. `.dot` sources still render to PNG. SVG files keep their
  compile-time roles (`$iconRaw$`, `$partial$` inlining).
- **Static passthrough.** `content/static/**` is copied verbatim to the site root. A static
  file with the same path as a generated icon wins, and the generator logs it.
- ImageMagick (`magick` or `convert`) is required only when a brand logo must be converted
  or a `.dot` source is present.

## Consequences

- A bare content repo builds and checks cleanly; adding a logo opts into the icon pipeline.
- The media rules are predictable: anything under `media/` is public, so private working
  files belong elsewhere.
- `content/static/` gives consumers a general root-level escape hatch without special cases.
- The head template and the manifest cannot drift: both render the same computed list.
