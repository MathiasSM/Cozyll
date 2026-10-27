# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to the [Haskell Package Versioning Policy](https://pvp.haskell.org/).

## [Unreleased]

### Added

- A per-page aside, rendered to the right of the article on desktop (and above
  it on mobile), that holds the reading controls and the table of contents. It
  only renders when it has something to show.
- An images toggle (`imagesToggle: <label>`) that hides a page's images by
  toggling a `no-images` class.
- The table of contents now lives in a collapsible `<details>` inside the aside.
- The table of contents label is configurable via `TOC: <label>` (markdown-rendered).
- A shared script (in `site-aside.html`) that wires every `data-toggle-class`
  checkbox, replacing each control's inline script.
- A README section, "Adding a control (toggle)", explaining how to add a new
  show/hide-by-class control.
- A `SITE_ENV=example` environment that builds the bundled `example-content/`
  as the whole site (drafts hidden, like `prod`).
- Self-documenting example content (`example-content/`) covering every front
  matter field, Markdown/Pandoc feature, and the engine's custom features; it
  doubles as the golden-test fixture.
- `shareTitle` and `shareDescription` front matter, overriding the social title
  and description.
- A `#main-image` image attribute that marks an image as the page's Open Graph /
  JSON-LD image.

### Changed

- The ruby toggle is now declared with `rubyToggle: <label>` (a markdown-rendered
  label) instead of `showRubyToggle: true`.
- Control templates moved to `templates/controls--<name>-toggle.html`, and the
  controls menu moved out of `as-post.html`/`as-page.html` into `site-aside.html`.
- The table of contents is no longer prepended to the article body; it is built
  as a context field and rendered in the aside (feeds no longer embed it).
- `SITE_ENV=dev` no longer publishes the `/example/` preview pages; that content
  moved to `example-content/`, built with `SITE_ENV=example`.
- The golden tests snapshot `example-content/` instead of `test/fixtures/content`
  and `dev/example/`.
- Social metadata is now generated in-house as Open Graph tags plus JSON-LD
  structured data, for posts, the home page, and standalone pages.
- Extracted the pure JSON-LD building blocks into a new `Cozyll.JsonLd`
  module (no behaviour change).

### Removed

- The `dev/example/` preview pages and `test/fixtures/content` fixtures,
  superseded by `example-content/`.
- Twitter card tags, along with the `site.twitterHandle` configuration field and
  the `TWITTER_HANDLE` environment override.

## [2.0.0.0] - 2026-10-23

### Added

- Posts now fail the build when `lastModifiedAt` is before `date`.
- Task-list checkboxes (from pandoc) are read-only by default; wrapping them in an `interactive` div keeps them editable.
- A ruby-text toggle: `showRubyToggle: true` front matter renders `templates/ruby-toggle.html` (a checkbox + inline script) above a post or page body, to hide/show reading annotations.
- Syntax-highlighting CSS is now generated at build time from pandoc (`styleToCss`), configurable via `highlight.style` in `website.yaml` (default `pygments`), with a `HIGHLIGHT_STYLE` env override.
- The content repository can now override the theme: `content/templates/<name>` shadows the vendored `templates/<name>` (file by file, including `$partial` references), and `content/css/*.css` is concatenated after the vendored styles. The generator keeps generic defaults so a bare content repo still builds.

### Changed

- Draft items (`draft: true`) now build only in dev (`SITE_ENV=dev`) and are excluded from prod builds; standalone pages now respect `draft:` too.
- Posts now honor `templated: true` (template syntax in their body), matching standalone pages.
- Japanese `language` code corrected from `jp` to `ja` (the `Language` constructor `Jp` is now `Ja`).
- Ruby annotations render as `<ruby>` without a hardcoded `lang="ja"`; the transform now lives in `Cozyll.Filters`.

### Fixed

- `TOC: true` now renders a table of contents (it was generated but never included in the output).

### Removed

- Vendored `assets/css/90-syntax-base.css`, replaced by the pandoc-generated highlight CSS.


## [1.0.0.0] - 2026-10-20

### Added

- Data list items can be hidden with `_show: false`, which omits them from the `$for(name)$` loop.
- A JSON Schema for the site configuration (`schema/website.schema.json`).
- Example configuration files (`schema/example.website.yaml` and `schema/example.socials.yaml`).

### Changed

- Moved `example.website.yaml` into `schema/`.
- Moved `socials.schema.json` into `schema/` from the content repository; the `website` and `socials` schemas are now closed (they reject unknown fields).

## [0.5.0.0] - 2026-10-19

### Added

- Generic data files: any YAML under `content/data/**/*.yaml` is exposed to templates by name, with no fixed schema (lists via `$for(name)$`, maps via `$name.key$`).
- An icon auto-transform: any field whose name contains `icon` also exposes `<field>Href` (its URL) and `<field>Raw` (the inlined SVG).
- Optional build-time JSON Schema validation for data files via a co-located `<name>.schema.json`.
- A Code of Conduct.

### Changed

- Replaced the hand-rolled `.githooks/pre-commit` hook with
  [pre-commit.com](https://pre-commit.com/), running `fourmolu`, `hlint`, and
  `actionlint`. The fourmolu hook now runs in check mode rather than rewriting
  files in place.
- Moved the mise configuration into a project-level `mise.toml` (declaring
  `pre-commit` and `actionlint`), replacing the parent `~/Desktop` config.
- `socials` icon fields renamed `iconPath`/`iconSource` to `iconHref`/`iconRaw`.
- Renamed `minimalCtx` to `globalContext`.
- Data files (`hobbies`, `experience`, `socials`) moved from TSV tables to YAML files.
- Split the test suite into `spec` (unit) and `golden` (snapshot) suites; CI publishes JUnit XML results to Codecov test analytics.

### Removed

- The strict `hobbies` and `experience` parsers and their schemas; these are now generic data files.
- The `validateHobbyPages` cross-check between hobbies and their posts.

### Fixed

- Removed a duplicated `pull_request` key in the OpenSSF Scorecard workflow,
  restoring the `branches: [master]` filter.
- Corrected the environment-variable documentation: removed the stale
  `TEMPLATES_DIR`/`ASSETS_DIR` references and clarified the variables are optional.

## [0.4.0.2] - 2026-10-17

### Added

- This CHANGELOG file. Added to the .cabal file to include in sdist package.
- A pre-commit git hook, opt-in, that runs hlint and fourmolu before a commit, and fails if it needed changes.
- A RELEASE-CHECKLIST, listing the steps to "release" a new version of this project.
- A CONTRIBUTING file, explaining briefly the expected workflow, the use of githooks and referencing RELEASE-CHECKLIST
- An OpenSSF Best Practices badge.
- A GitHub release workflow that tags the version and publishes GitHub and Hackage drafts.
- Basic styles for figures and images within posts.

### Changed

- README: Mentioning new githooks, referencing new CONTRIBUTING, RELEASE-CHECKLIST.
- Pinned dependencies via `cabal.project.freeze` and keyed the CI cache on it.
- CI: upload coverage to Codecov instead of GitHub Code Quality.
- Bumped GitHub Actions dependencies (scorecard-action, actions/cache, hlint-scan, download-artifact).

### Fixed

- Removed the broken `CONTENT_DIR`, `TEMPLATES_DIR`, and `ASSETS_DIR` environment-variable overrides.

### Security

- Hardened GitHub Actions (StepSecurity recommendations and `contents: read` permissions).
- Run OpenSSF Scorecard on pull requests.

## [0.4.0.0] - 2026-10-15

### Added

- Dev-only `/example/` preview pages behind the `SITE_ENV=dev` flag.
- Haddock documentation across all modules.
- Basic accessibility checks on the output HTML; e.g. every image requires `alt` text.

### Changed

- License changed to BSD-3-Clause.
- Site identity is read from content repo's `website.yaml`; some environment variables can override individual fields.
- Deployment configuration is read from the environment; the templates/assets directories and feed size are now configurable.
- Content model: pages and posts merged into `writings/`, post groups discovered from content, and the showcase treated as a group.
- Static site files are generated from `website.yaml`; dropped `assets/static`.
- Images moved into `content/media`.

### Fixed

- Sitemap no longer emits an empty `lastmod`.
- `just-one-title` accessibility validation.

### Security

- The build fails when `security.txt` is within a configured expiry margin.

## [0.3.0.0] - 2026-10-09

### Added

- Sitemap in `robots.txt`; `trust.txt`, `funding.json`, and `security.txt` well-known files.
- Atom feed.
- Navigation driven by content.
- Redirects/aliases from frontmatter.
- fourmolu + hlint formatting/linting.
- Snapshot (golden) testing.
- GitHub Actions CI.

### Changed

- Refactored rules to be filetype-agnostic; simplified single pages, metadata, and config.
- Moved content to the `web-writings` repository.
- Moved data to TSV with a typed parser (`Post`/`Project`/etc).
- Reorganized images/css/static into `assets/`; templated static files.

### Fixed

- Canonical paths/404s, post dates, favicon filenames, and the per-page `lang` attribute.

## [0.2.0.0] - 2024-04-07

### Changed

- New ghcup-based build configuration.

## [0.1.0.0] - 2021-12-05

### Added

- Initial version replicating a Gatsby site.
- GPL-3.0 license.



[Unreleased]: https://github.com/MathiasSM/Cozyll/compare/v2.0.0.0...master
[2.0.0.0]: https://github.com/MathiasSM/Cozyll/compare/v1.0.0.0...v2.0.0.0
[1.0.0.0]: https://github.com/MathiasSM/Cozyll/compare/v0.5.0.0...v1.0.0.0
[0.5.0.0]: https://github.com/MathiasSM/Cozyll/compare/v0.4.0.2...v0.5.0.0
[0.4.0.2]: https://github.com/MathiasSM/Cozyll/compare/v0.4.0.0...v0.4.0.2
[0.4.0.0]: https://github.com/MathiasSM/Cozyll/compare/v0.3.0.0...v0.4.0.0
[0.3.0.0]: https://github.com/MathiasSM/Cozyll/compare/v0.2.0.0...v0.3.0.0
[0.2.0.0]: https://github.com/MathiasSM/Cozyll/compare/v0.1.0.0...v0.2.0.0
[0.1.0.0]: https://github.com/MathiasSM/Cozyll/releases/tag/v0.1.0.0
