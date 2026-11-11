## [Unreleased]

## [3.4.4.0] - 2026-11-11

### Changed

- Release kits are now statically linked: the binary has no glibc version requirement and needs no shared runtime libraries, and it no longer writes `cozyll.tix`.

## [3.4.3.0] - 2026-11-11

## [3.4.2.0] - 2026-11-11

## [3.4.1.0] - 2026-11-10

## [3.4.0.0] - 2026-11-10

### Added

- `cozyll init` scaffolds a working `content/` (four configs, a home page, `.gitignore`).
- `site.language` in `website.yaml` (ISO 639-1 with an optional region, default `en`) sets the site's own language: it is the default page language, drives author pages and social metadata, and marks only the site chrome of pages written in another language.
- `nav:` accepts a map of language to label (e.g. `nav: {en: Guides, es: Guías}`) in addition to a single string; labels resolve for the rendering page's language, then its base language, then the site's language.
- A site-wide Atom feed at `/atom.xml`, aggregating every group's posts newest first (up to `feed.size`), listed first in every page head; per-group feeds are unchanged.

## [3.3.1.0] - 2026-11-10

### Fixed

- `cozyll --help` and `--version` work without a content repo; unknown commands are rejected instead of silently building, and `clean`/`check` no longer require content or a valid `SITE_ENV`.
- Non-ASCII content no longer crashes the build under a non-UTF-8 locale (`LC_ALL=C`); the build pins UTF-8 for its inputs and output.
- Template overrides in `content/templates/` now take effect on the next `cozyll build`; no `clean` needed.
- Drafts from a `dev` build no longer survive a `prod` build: changing `SITE_ENV` clears `_site` and `_cache` together before rebuilding.
- `cozyll check` now refuses a missing or foreign-env `_site` instead of silently passing, and warns when content is newer than the last build.
- Favicon and web-manifest icon links are no longer dead references when there is no `media/branding/logo.svg`: icons, their `<link>`s and the manifest `icons` key are only emitted when a logo exists.
- Author pages show the author's full name as the heading (no "By:" prefix), and their profile image is a page-relative URL instead of an absolute one.
- The site header no longer declares `lang="en"` for non-English pages; menu entries carry their own language.
- The sitemap's home entry now ends with a trailing slash, matching the canonical URL.
- Links inside prose are underlined, so in-text links no longer rely on colour alone (WCAG 1.4.1).

### Added

- `docs/authoring.md`, a guide to pages, posts, groups, `path`, drafts, aliases, front matter, media routes and feeds; the build's group and required-content errors now point at it instead of the README.
- `docs/theming.md`, the theme contract: which templates exist and what they receive, `content.html` being applied by the builder, the CSS custom properties and the override/caching rules.
- Raster logos are supported: `media/branding/logo.png` is used when no `logo.svg` exists, and `content/static/` files override the generated icon at the same path.
- `content/static/` is copied verbatim to the site root, for files such as `CNAME`, `.nojekyll` and verification files.
- `schema/example.authors.yaml`, `schema/example.localization.yaml` and `schema/localization.schema.json`, so every required config file has an example and a schema; the content-schema check now validates `localization.yaml` too.

### Changed

- The README now documents the workspace layout (kit vs content repo), install, commands, authoring, localisation, theming and checks, and the kit ships those docs.
- `-v`/`--verbose` now enables debug output, including the resolved `SITE_ENV` and content directory.
- Site chrome and author pages now follow `site.language` instead of assuming English; the chrome only claims a language on pages written in another language.
- `scripts/check-site.sh` treats accessibility findings as advisory unless `--a11y-fail true` is passed, matching CI.
- `funding:` may be omitted from `website.yaml`; a site without it publishes no `funding.json` and no `.well-known/funding-manifest-urls`.
- Every file under `content/media/` is now published (previously a whitelist silently dropped files); `media/branding/*` still flattens to `/images/*` and `.dot` sources still render to PNG.
- Build errors now list the required content tree, explain a group without an index page, and report every item missing `path:` in one go.

## [3.3.0.0] - 2026-11-10

### Added

- `cozyll data fetch|verify|fmt|sources`: derive and maintain the committed ruby index
  (`ruby-data/index.json`) from configurable upstream sources. The default list is
  `schema/example.ruby-sources.yaml`; copy it to `ruby-data/sources.yaml` to override
  versions or locations. Builds read the index offline; the content repo commits it.
- Ruby coverage check: Japanese content must annotate non-jōyō kanji with ruby; `jaRubySkip`
  exempts words. Requires `content/ruby-data/index.json`.
- Rendered ruby carries `data-jlpt` and `data-jlpt-source` (`word`, `kanji`, or `unknown`).
- `jaRubyCheck` (`off`, `warn`, `error`) controls the Japanese ruby checks per site
  (`website.yaml`) or page.
- Japanese ruby readings are checked against the derived alignment index; `jaRubyAllow`
  exempts a surface or a `surface:reading` pair.

### Changed

- The ruby control is a threshold `<select>` (`All`/`N5`–`N1`) with an independent
  unknown-level checkbox (`rubyControl`/`rubyUnknown`); the reader's choice is stored in
  `localStorage` and there is no article default. Content repos must add `ruby.all` to
  `localization.yaml` if they use the new control.
- The ruby filter HTML-escapes base and reading; every `[base](-reading)` link still becomes ruby.

### Deprecated

- `rubyToggle` is deprecated in favour of `rubyControl`; it still works as the legacy
  all-or-nothing toggle and will be removed in a future major release.

## [3.2.0.0] - 2026-11-10

### Fixed

- Author pages omit the profile image when an author has no image, instead of rendering an `img` with an empty `src`.

### Added

- Reusable `setup-cozyll` action, which installs the kit from a release or a local tarball.
- Reusable `check-content-schema` action, which validates content YAML against the shipped schemas.
- Reusable `check-html` action, which validates generated HTML, CSS and SVG with the W3C Nu checker.
- Reusable `check-a11y` action, which audits the built site with pa11y-ci and the axe runner.
- Reusable `check-links-external` action, which checks external links with lychee (advisory by default).
- Reusable `check-xml` action, which validates that generated XML files are well formed.
- Reusable `check-jsonld` action, which validates JSON-LD blocks in generated HTML.
- Reusable `check-wellknown` action, which validates security.txt, funding.json, manifest, robots, trust and sitemap.
- Reusable `check-spelling` action, which runs typos (advisory, and not a hard gate for mixed-language content).
- Reusable `site-ci.yml` workflow, which builds a content repo and runs the enabled checks.
- Added `scripts/check-site.sh`, a local runner for the same checks, also shipped in the kit.

### Changed

- Release kit now bundles `schema/*.schema.json` (editor hints and consumer schema validation).
- Release kits are smoke-tested (example build plus checks) before publishing.
- Documented the consumer CI workflow and actions in `docs/consumer-ci.md`.
- `mise.toml` provides the tools used by the local site checks, with `mise run example-checks`, `mise run format` and `mise run docs` mirroring the CI steps.
- The accessibility check in `site-ci.yml` is advisory (non-blocking) for now; it reports findings without failing the workflow.

### Removed

- Removed the hardcoded `kit-released` dispatch to `MathiasSM/web-writings` (`notify-content.yml`). Consumers now trigger their own rebuilds.

## [3.1.0.1] - 2026-11-07

### Added

- ADRs

### Changed

- Documentation changes (updates to reflect real state)

## [3.1.0.0] - 2026-11-06

### Changed

- Icons are neutral SVG graphics; templates now set each inline icon's
  accessibility (decorative icons wrapped in `aria-hidden="true"`, meaningful
  icons via `role="img"` + `aria-label` or a `<title>`), and the build fails
  when an inline SVG is neither hidden nor named.
- Group index, author, and showcase list-item links now carry `aria-labelledby`
  pointing at the item title's slug `id` (posts: the hyphenated `path:` front
  matter, e.g. `blog-el-garson`; projects: the project file name), so each link's
  accessible name is the title only.
- Adjusted the color palette to meet WCAG 2.2 AA contrast ratios.

### Fixed

- `sitemap.xml` now computes a `<lastmod>` for group index pages.

## [3.0.0.2] - 2026-11-02

### Changed

- Adds "By:" to author pages header

## [3.0.0.1] - 2026-11-01

### Changed

- Minor style changes for header tags (h1, h2, ...)
- Minor style fix for social icons/buttons.

## [3.0.0.0] - 2026-11-01

### Added

- Author pages are `ProfilePage` nodes (with the author as `mainEntity` and
  `hasPart` mirroring the listed posts) and group index pages are
  `CollectionPage` nodes whose `mainEntity` is an `ItemList` in DOM order (the
  showcase index has no `ItemList`).
- schema.org `@graph` structured data: the home page carries the `WebSite`,
  `Organization`, and default-author entities with stable `@id`s, posts are
  `BlogPosting` nodes, and standalone pages can set a whitelisted `schemaType`
  (`WebPage`, `AboutPage`, `ContactPage`, `CollectionPage`, `ProfilePage`).
  Articles also emit `article:published_time`/`article:modified_time`, and an
  opted-in post carries `copyrightNotice`/`copyrightHolder`.
- Author profile pages at `/authors/<id>`, listing each author's posts and
  included in `sitemap.xml`; articles credit their authors by profile URL
  (`article:author` and JSON-LD `author[].url`).
- An opt-in per-post copyright notice (`addCopyrightNotice: true` on an author):
  a `© <authors> <years>` line at the end of the post, years from `date` to
  `lastModifiedAt`, shown only on the post page (not in lists or feeds).
- `author:` front matter (an id or list of ids from `authors.yaml`) resolves to
  per-post authors, shown as bylines and used in JSON-LD; posts without it fall
  back to the site-default author.
- `authors.yaml` (a map keyed by author id) with a required site-default author,
  now the source of author metadata for feeds, `funding.json`, and JSON-LD.
- `site.logo` and `site.alternateName` in `website.yaml`, published and surfaced
  in JSON-LD.
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
- A required `localization.yaml` (`{id: {locale: string}}`) plus a `t("id")`
  template function for localized strings; a lookup resolves the page language
  and falls back `xx-YY` → `xx`, failing the build when a string a template
  consumes is missing. A reserved `_ogLocaleDefaultRegion` key supplies each
  language's `og:locale` (fails when a used language lacks one).
- An open `Language` model: `language:` accepts any 2-letter ISO 639-1 code plus
  an optional region (e.g. `pt-BR`), replacing the hardcoded `en`/`es`/`ja` enum,
  so any locale is supported. Date, project-date, and control labels are
  localized through `t("id")` (dates stay `YYYY-MM-DD`).

### Changed

- The footer now reads `© <site.title> <firstYear>–<currentYear>`: `copyrightYear`
  is the first year and the build year is the end of the range (a single year
  when they are equal).
- `site.name` and `site.author` collapse into a single required `site.title`
  (breaking): `$site-name$`/`$site-author$` become `$site-title$`, and the
  `SITE_NAME`/`SITE_AUTHOR` env overrides become `SITE_TITLE`.
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
- Social accounts use a single `_show` flag — shown by default, hidden with
  `_show: false` — replacing `showContact`/`showAbout` and the
  `socials-contact`/`socials-about` lists with one `socials` list (breaking).
- The `minimal.html` wrapper is now `content.html` (a classed content wrapper);
  the images toggle class is `images-toggle` (was `class-toggle`); social links
  use `rel="me"` with a hidden decorative icon and no redundant `title`; and
  menu entries carry their `lang` attribute.

### Removed

- The `dev/example/` preview pages and `test/fixtures/content` fixtures,
  superseded by `example-content/`.
- Twitter card tags, along with the `site.twitterHandle` configuration field and
  the `TWITTER_HANDLE` environment override.

### Fixed

- Author page URLs are slash-less (`/authors/<id>`) and JSON-LD author `@id`s
  use a `#person`/`#organization` fragment.
- Unknown `SITE_ENV` values now fail the build (previously they silently fell
  back to `prod`).

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



[Unreleased]: https://github.com/MathiasSM/Cozyll/compare/v3.3.0.0...master
[3.4.4.0]: https://github.com/MathiasSM/Cozyll/compare/v3.4.3.0...v3.4.4.0
[3.4.3.0]: https://github.com/MathiasSM/Cozyll/compare/v3.4.2.0...v3.4.3.0
[3.4.2.0]: https://github.com/MathiasSM/Cozyll/compare/v3.4.1.0...v3.4.2.0
[3.4.1.0]: https://github.com/MathiasSM/Cozyll/compare/v3.4.0.0...v3.4.1.0
[3.4.0.0]: https://github.com/MathiasSM/Cozyll/compare/v3.3.1.0...v3.4.0.0
[3.3.1.0]: https://github.com/MathiasSM/Cozyll/compare/v3.3.0.0...v3.3.1.0
[3.3.0.0]: https://github.com/MathiasSM/Cozyll/compare/v3.2.0.0...v3.3.0.0
[3.2.0.0]: https://github.com/MathiasSM/Cozyll/compare/v3.1.0.1...v3.2.0.0
[3.1.0.1]: https://github.com/MathiasSM/Cozyll/compare/v3.1.0.0...v3.1.0.1
[3.1.0.0]: https://github.com/MathiasSM/Cozyll/compare/v3.0.0.2...v3.1.0.0
[3.0.0.2]: https://github.com/MathiasSM/Cozyll/compare/v3.0.0.1...v3.0.0.2
[3.0.0.1]: https://github.com/MathiasSM/Cozyll/compare/v3.0.0.0...v3.0.0.1
[3.0.0.0]: https://github.com/MathiasSM/Cozyll/compare/v2.0.0.0...v3.0.0.0
[2.0.0.0]: https://github.com/MathiasSM/Cozyll/compare/v1.0.0.0...v2.0.0.0
[1.0.0.0]: https://github.com/MathiasSM/Cozyll/compare/v0.5.0.0...v1.0.0.0
[0.5.0.0]: https://github.com/MathiasSM/Cozyll/compare/v0.4.0.2...v0.5.0.0
[0.4.0.2]: https://github.com/MathiasSM/Cozyll/compare/v0.4.0.0...v0.4.0.2
[0.4.0.0]: https://github.com/MathiasSM/Cozyll/compare/v0.3.0.0...v0.4.0.0
[0.3.0.0]: https://github.com/MathiasSM/Cozyll/compare/v0.2.0.0...v0.3.0.0
[0.2.0.0]: https://github.com/MathiasSM/Cozyll/compare/v0.1.0.0...v0.2.0.0
[0.1.0.0]: https://github.com/MathiasSM/Cozyll/releases/tag/v0.1.0.0
