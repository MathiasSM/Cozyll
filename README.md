# Cozyll

[![Haskell](https://img.shields.io/badge/Haskell-5e5086?logo=haskell&logoColor=white)](https://www.haskell.org/)
[![License](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](https://github.com/MathiasSM/Cozyll/blob/master/LICENSE.txt)
[![GitHub release](https://img.shields.io/github/v/release/MathiasSM/Cozyll)](https://github.com/MathiasSM/Cozyll/releases/latest)
[![Hackage](https://img.shields.io/hackage/v/cozyll?label=Hackage)](https://hackage.haskell.org/package/cozyll)

[![CI](https://img.shields.io/github/actions/workflow/status/MathiasSM/Cozyll/_ci.yml?label=CI)](https://github.com/MathiasSM/Cozyll/actions/workflows/_ci.yml)
[![CodeQL](https://img.shields.io/github/actions/workflow/status/MathiasSM/Cozyll/codeql.yml?label=CodeQL)](https://github.com/MathiasSM/Cozyll/actions/workflows/codeql.yml)
[![Codecov](https://img.shields.io/codecov/c/github/MathiasSM/Cozyll)](https://app.codecov.io/github/MathiasSM/Cozyll)
[![Dependabot](https://img.shields.io/badge/Dependabot-enabled-025E8C?logo=dependabot&logoColor=white)](https://github.com/MathiasSM/Cozyll/blob/master/.github/dependabot.yml)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](.pre-commit-config.yaml)

[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/15535/badge)](https://www.bestpractices.dev/projects/15535)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/MathiasSM/Cozyll/badge)](https://scorecard.dev/viewer/?uri=github.com/MathiasSM/Cozyll)


This is a [hakyll](https://hackage.haskell.org/package/hakyll)-based site generator. It's main purpose is to build [mathiassm.dev (my personal site)](https://mathiassm.dev), but it can be used to build other kinds of sites with similar needs. In essence, it's a thin-ish layer of extra logic, some premade templates and styling, on top of the actual generator library by [jaspervdj](https://jaspervdj.be/).

## Documentation

API reference (per-module Haddock) is published at <https://cozyll.mathiassm.dev>.

It is generated with:

```sh
cabal haddock-project --hackage \
  --haddock-options="--show-all" \
  --haddock-options="--quickjump"
```

The published site reflects the documentation of the **latest release**, not `master`. To read
the docs for unreleased changes, run the command above locally; the output lands in
`haddocks/` (gitignored).

## The two things that live here

A Cozyll site is a workspace with two separate parts:

* **The kit** — a release download: the `cozyll` binary, plus the vendored theme
  (`templates/`, `assets/`), schemas (`schema/`), scripts (`scripts/`) and these docs. It is
  not installed as a package and not committed to your content repo. Replace it whole when
  you upgrade.
* **The content repo** — everything you write and commit: the four YAML files, `writings/`,
  `media/`, `static/`, optional overrides, and your CI workflow. It is a normal git
  repository.

A workspace looks like this:

```text
site/
├── cozyll                    # kit (downloaded, not committed)
├── templates/
├── assets/
├── schema/
├── scripts/
├── README.md
├── docs/
├── content/                  # your content repo (checked out here)
│   ├── website.yaml
│   ├── socials.yaml
│   ├── authors.yaml
│   ├── localization.yaml
│   ├── writings/
│   ├── media/
│   ├── static/
│   ├── templates/            # optional overrides
│   ├── css/                  # optional extra styles
│   └── .github/workflows/ci.yml
├── _site/                    # generated
└── _cache/                   # generated
```

Generated files are written in the working directory, next to `content/`, and must not be
committed. A content repo's `.gitignore` should include:

```gitignore
_site/
_cache/
*.tix
```

`*_cache` and `_site/` are also harmless when you run the kit from a scratch directory.
`*.tix` only appears when you build Cozyll from source with coverage enabled.

The consumer workflow belongs in the content repo at `.github/workflows/ci.yml` (GitHub
only reads workflows from the repository root). When the reusable workflow checks the
content repo out under `content/`, that file is at `content/.github/workflows/ci.yml` in the
workspace.

## Install

Download the latest `cozyll-kit.tar.gz` and its checksum from the
[releases page](https://github.com/MathiasSM/Cozyll/releases/latest), verify, and extract it
into the workspace:

```sh
curl -fsSLO https://github.com/MathiasSM/Cozyll/releases/latest/download/cozyll-kit.tar.gz
curl -fsSLO https://github.com/MathiasSM/Cozyll/releases/latest/download/cozyll-kit.tar.gz.sha256
sha256sum -c cozyll-kit.tar.gz.sha256
tar -xzf cozyll-kit.tar.gz
```

The kit targets Linux x86_64; the release notes state the platform baseline for each
release.

A normal build needs no extra tools. ImageMagick (`magick`, or `convert`) is needed only
when a brand logo has to be converted into favicons. Graphviz (`dot`) is needed only when
the content includes `.dot` sources.

## Ruby data and licensing

Cozyll is BSD-3-Clause (see `LICENSE.txt`). The released library and CLI ship **no
dictionary data**: the `ruby-data/index.json` your site builds from is generated by
`cozyll data fetch` in your content repo and is owned and committed there.

The upstream sources, their licences and the attribution obligations are documented in
[`Cozyll.Ruby.Sources`](https://cozyll.mathiassm.dev/cozyll/Cozyll-Ruby-Sources.html) and
[`Cozyll.Ruby.Index`](https://cozyll.mathiassm.dev/cozyll/Cozyll-Ruby-Index.html). In short:
the index is CC BY-SA 4.0; credit KANJIDIC/JMdict/JMnedict (EDRDG),
JmdictFurigana/JmnedictFurigana, yomitan-jlpt-vocab, Waller and kanji-data; link their
licences and [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/); state what you
changed; do not claim copyright over the data; and keep it reasonably current.

If you enable the feature, copy `schema/example.ruby-data.NOTICE` to `ruby-data/NOTICE`
(adjust it if you changed `sources.yaml`) and carry an acknowledgement on the generated
site. If you never provide `ruby-data/index.json`, no dictionary data is used and none of
this applies.

## Your first site

Run `cozyll init` to create a working `content/` (the four configs, a home page and a
`.gitignore`), or write them yourself. The files are:

* [`schema/example.website.yaml`](schema/example.website.yaml) — site identity and output
  switches.
* [`schema/example.socials.yaml`](schema/example.socials.yaml) — the accounts linked from
  the site.
* [`schema/example.authors.yaml`](schema/example.authors.yaml) — the author map; exactly one
  author sets `siteDefault: true`.
* [`schema/example.localization.yaml`](schema/example.localization.yaml) — the UI strings
  for each language.
* `content/writings/` — your pages and posts, starting with a home page.

Then build and check:

```sh
cozyll build
cozyll check
cozyll watch
```

`SITE_ENV` selects the content and the draft policy:

* `prod` (the default) builds `content/` and hides drafts.
* `dev` builds `content/` and shows drafts.
* `example` builds the bundled `example-content/` at the site root, with drafts hidden.

```sh
SITE_ENV=dev cozyll build
SITE_ENV=example cozyll build
```

Changing `SITE_ENV` clears `_site/` and `_cache/` before the next build, so a development
build cannot leak into production.

## Commands

```text
cozyll [(-v|--verbose)] COMMAND
```

| Command | What it does |
|---|---|
| `build` | Generate the site into `_site/`. `build --dry-run` lists the out-of-date items without writing. |
| `clean` | Remove `_site/` and `_cache/` (including `_cache/tmp/`). Needs no content. |
| `rebuild` | `clean` followed by `build`. |
| `server` | Serve the files already built in `_site/`. |
| `watch` | Build, serve, and rebuild pieces as content changes. |
| `check` | Validate links in the built `_site/`. Needs no content. |
| `data` | `fetch`/`verify`/`fmt`/`sources` maintain the optional derived ruby index; see [Ruby and JLPT levels](#ruby-and-jlpt-levels). |
| `init` | Create a starter `content/` (four configs, a home page, `.gitignore`). |

`init` creates the required `content/` tree from the kit's `schema/` examples; it refuses a
non-empty `content/` unless you pass `--force`, and `init --dir DIR` scaffolds elsewhere.

`cozyll` has no `deploy` or `preview` command: publish `_site/` with your own tooling,
and use `cozyll watch` to preview locally. `cozyll <command> --help` prints that command's
help; `cozyll --help` prints the list above.

`clean` and `check` work without a content directory or a valid `SITE_ENV`. `check` refuses
a missing `_site/` and a tree built with another `SITE_ENV`, and warns when content is newer
than the last build. It checks internal links only; external links are not fetched (see
`cabal.project`).

`-v`/`--verbose` enables debug output, including the resolved `SITE_ENV`, content directory
and build-state decision:

```sh
cozyll -v build
```

`--help` prints the command list, and `--version` prints the version:

```sh
cozyll --help
cozyll --version
```

## Authoring

Pages are flat files under `content/writings/`; posts sit in a group folder and carry a
`date:`. A group is an index page (`writings/<group>.md` with `index: true`, `group:` and
`path:`) plus a `writings/<group>/` folder, and it gets a listing and a feed at
`/<group>/atom.xml`. The site as a whole has `/atom.xml` (every group's posts, newest
first, up to `feed.size`). Every item needs an explicit `path:`; drafts use `draft: true`, and
`aliases:` publishes redirects. Dates stay ISO `YYYY-MM-DD` by design.

The full guide — front matter, groups, media routes, `content/static/`, feeds and the
errors the build raises — is in [docs/authoring.md](docs/authoring.md).

## Ruby and JLPT levels

`[base](-reading)` renders ruby. When the content repo provides a derived
`ruby-data/index.json`, each ruby carries `data-jlpt` (`n1`–`n5` or `unknown`) and
`data-jlpt-source` (`word`, `kanji`, or `unknown`), and readers get a threshold
`<select>` plus an independent unknown-level checkbox. Their choice is stored in
`localStorage`; there is no article default, so without JS all ruby is shown.

Generate (and refresh) the data with the CLI, then commit it:

```sh
cozyll data fetch     # resolve sources, derive ruby-data/index.json
cozyll data verify    # schema and canonical form
cozyll data fmt       # rewrite the index canonically
cozyll data sources   # print the effective sources file
```

The default source list is `schema/example.ruby-sources.yaml`; copy it to
`ruby-data/sources.yaml` (or run `cozyll data sources --write`) to pin versions or change
locations. `ref: latest` resolves via the GitHub API; non-GitHub hosts need a pinned ref.
Builds are offline and never re-derive: the next `cozyll build` picks up a replaced
`ruby-data/index.json` (no `clean` needed); restart `watch` after replacing it. The index
size limit is `COZYLL_RUBY_INDEX_LIMIT` bytes (default 8 MiB).

Front matter (per page):

| Key | Meaning |
|---|---|
| `rubyToggle: <label>` | **Deprecated** legacy all-or-nothing toggle; use `rubyControl`. Kept until the next major. |
| `rubyControl: <label>` | enables the threshold `<select>` |
| `rubyUnknown: <label>` | enables the unknown-level checkbox |
| `jaRubySkip: [...]` | words that may appear without ruby |
| `jaRubyAllow: [...]` | surfaces or `surface:reading` pairs accepted without a dictionary match |
| `jaRubyCheck: off\|warn\|error` | overrides the site's check severity |

`jaRubyCheck` is also read from `website.yaml` (default `error`). These keys only govern the
**Japanese** checks: coverage and reading verification inspect text whose effective `lang` is
`ja*`; non-Japanese ruby is controlled but not checked. Content repos add `ruby.all` to
`localization.yaml` for the “All” option.

## Localisation

`content/localization.yaml` is required even for a single-language site. It maps a UI string
id to a map of locale → string:

```yaml
post.updated:
  en: Updated
  es: Actualizado
  ja: 更新済み
```

The templates call strings with `$t("id")$`; lookup falls back from `xx-YY` to `xx`. The
reserved `_ogLocaleDefaultRegion` key provides the `og:locale` value. The current ids are
`aside.controls`, `post.updated`, `project.started`, `project.finished`, `ruby.all` and `author.by`
(the last one is kept for compatibility and is no longer used by the stock theme). See
[`schema/example.localization.yaml`](schema/example.localization.yaml).

`site.language` in `website.yaml` is the site's own language (ISO 639-1 with an optional
region, default `en`):

```yaml
site:
  language: en
```

It is the default for pages without `language:`, is used for author pages and for
`inLanguage`/`og:locale` fallbacks, and marks the site chrome (title and description) with
`lang` only on pages written in another language. A page overrides it with `language:` in its
front matter (`language: es-MX`).

Menu labels are a single string, used on every page:

```yaml
nav: Guides
navOrder: 2
```

or a map of language to label:

```yaml
nav: {en: Guides, es: Guías, ja: ガイド}
navOrder: 2
```

When a page is rendered, its label is looked up for the page's language, then its base
language (`es-MX` → `es`), then the site's language; if none matches, the build fails naming
the page and the available languages. A label rendered in a language other than the page's
carries `lang`.

## Theming

Override a template by putting a file with the same name in `content/templates/`; it
shadows the vendored one on the next `cozyll build`, no `clean` needed. `content.html` is
applied by the builder rather than through `$partial$`. Extra styles in `content/css/*.css`
are concatenated after the vendored CSS; `SITE_ENV=dev` keeps the CSS readable while
`prod`/`example` minify it.

The template inventory, context fields and CSS custom properties are in
[docs/theming.md](docs/theming.md).

## Checks

`scripts/check-site.sh` runs the same checks locally as the consumer CI:

```sh
scripts/check-site.sh content-schema --content-dir content
scripts/check-site.sh all --content-dir content --site-dir _site --a11y-fail false
```

`all` exits 0 when everything is clean, 1 when a hard check fails or `--a11y-fail true`
finds issues, and 2 when the only findings are advisory accessibility ones. Pass
`--a11y-fail false` for a green advisory run.

The available checks are `content-schema`, `html`, `a11y`, `links-external`, `xml`,
`jsonld`, `wellknown` and `spelling`; `all` runs the default CI set (`content-schema`,
`html`, `a11y`, `xml`, `jsonld`, `wellknown`). `links-external` and `spelling` are optional
and not part of `all`. Run `scripts/check-site.sh --help` for the tools each check needs.

Accessibility findings are advisory unless you pass `--a11y-fail true`, matching CI. The
script groups findings by axe rule and prints the page and node counts; pass
`--a11y-report FILE` to keep the raw pa11y-ci JSON. Contrast ratios are not in pa11y's
axe output, so check them with axe DevTools or `npx @axe-core/cli`. The script runs
`pa11y-ci` with the **axe** runner; bare `npx pa11y` defaults to HTML_CodeSniffer and can
report a different set of issues, so use the script for the authoritative local run.

`cozyll check` is the link check for the generated site. The content-schema check validates
`website.yaml`, `authors.yaml`, `socials.yaml` and `localization.yaml` against the schemas in
`schema/`.

## Development

### Local

#### Setup

1. Install ImageMagick (e.g. via `sudo apt install imagemagick`) — needed for the example
   build, which resolves `site.logo` to `example-content/media/branding/logo.svg` and
   generates favicons from it.
2. Install Graphviz if you build content with `.dot` sources.
3. Install ghcup (e.g. using `mise use -g ghcup`).
4. Use ghcup to install `ghc`, `cabal` (both required)
5. Install the repo's `mise.toml` tools:

   ```sh
   mise install
   ```

  - You may install `hls`, `fourmolu`, `hlint`, `apply-refact` with it, or use `cabal install PKG-VERSION` (see [CONTRIBUTING.md](CONTRIBUTING.md); CI reads the fourmolu, GHC, and cabal versions from the `FOURMOLU_VERSION`, `GHC_VERSION`, and `CABAL_VERSION` repository variables)
  - Remember to `ghcup set <TOOL>` (in particular, match CI with `ghcup set cabal <CABAL_VERSION>`)
6. Enable the git hooks (runs `fourmolu` and `hlint` before each commit) via
   [pre-commit](https://pre-commit.com/); see [CONTRIBUTING.md](CONTRIBUTING.md).

#### Build

1. `cabal build all`: First time will take a while, but dependencies won't need to recompile often.

#### Checks

`mise run example-checks` builds `example-content` and runs the same
[`scripts/check-site.sh`](scripts/check-site.sh) checks as CI. Accessibility findings are advisory,
as in CI. The script's `--help` lists the checks and the tools they need.

#### Dependencies

Dependency versions are pinned in `cabal.project.freeze` so builds stay
reproducible and the CI cache stays valid. To update them:

```sh
cabal update                          # refresh the Hackage index
cabal outdated                        # optional: see what's stale
rm cabal.project.freeze && cabal freeze --enable-tests --enable-benchmarks
git add cabal.project.freeze && git commit
```

`--enable-tests --enable-benchmarks` matches the CI build flags, so test and
benchmark dependencies are pinned too.

#### Format and lint

- Via your editor (in my case, NeoVim's lsp registering the installed `hls`, configured with `hlint` and `fourmolu`).
- Calling the executables directly over `app/`, `src/`, `test/`.
- Running the CI formatting check with `mise run format`.

#### Test

Using [Tasty](https://hackage.haskell.org/package/tasty) to organize/run tests.

- Run all tests: `cabal test`.
- Only Unit tests: `cabal test spec`
- Only Golden tests: `cabal test golden`
  - Golden files are stored in `test/golden`
  - Updating golden files: `cabal test golden --test-options='--accept'`

### Workflow

Changes land on `master` through pull requests from short-lived feature
branches named `type/description`. See [CONTRIBUTING.md](CONTRIBUTING.md) for
details, and [RELEASE-CHECKLIST.md](RELEASE-CHECKLIST.md) for the release
process.

### CI / CD

Configured via Github Actions within `.github` directory.

This project "deploys" as a release, via the CI workflow. Content repos can pull their preferred release (ideally latest, I suppose) and execute it against their files. The release includes both the executable (not statically linked as of writing), as well as templates and assets.

#### Consumer CI

Content repos can also reuse a ready-made workflow instead of hand-writing one. Add this to
`.github/workflows/ci.yml` in the content repo:

```yaml
name: Site CI

on:
  push:
    branches: [master]
  pull_request:
  workflow_dispatch:

jobs:
  site:
    uses: MathiasSM/Cozyll/.github/workflows/site-ci.yml@master
    with:
      cozyll-version: latest
      site-domain: example.com
```

The workflow checks the content repo out under `content/`, installs the kit release, builds the
site, and runs the enabled checks. To run it from a separate CI repository, set
`content-repo` to `owner/repo` and pass `content-token` from a secret; when `cozyll-version` is
unset the workflow reads `content/.cozyll-version`, and `content/config/lychee.toml` is picked up
by the external-link check when present. See [docs/consumer-ci.md](docs/consumer-ci.md) for the
overall setup and migration notes; each composite action documents its own inputs and
requirements in its `action.yml`. Pin an exact release tag instead of `@master` for stability.

The checks can also be run locally with `scripts/check-site.sh` and its helper files in `scripts/`, which ship in the release kit.
Run `scripts/check-site.sh --help` for the available checks and their tool requirements.

---


## Features how-to (?)

### Data files

Any YAML under `content/data/**/*.yaml` becomes a template context named after its path.
See the [`Cozyll.Context.Data` docs](https://cozyll.mathiassm.dev/cozyll/Cozyll-Context-Data.html)
(source: `src/Cozyll/Context/Data.hs`) for list/map access, `_show`, icon `Href`/`Raw` and
accessibility, and `*.schema.json` validation.

### Authors

Authors live in the required `content/authors.yaml` (see
[`Cozyll.Domain.Author`](https://cozyll.mathiassm.dev/cozyll/Cozyll-Domain-Author.html),
source `src/Cozyll/Domain/Author.hs`). Post author resolution and the `$for(author)$` template
fields are documented in
[`Cozyll.Context.Author`](https://cozyll.mathiassm.dev/cozyll/Cozyll-Context-Author.html).

### Frontmatter

See [`Cozyll.Metadata`](https://cozyll.mathiassm.dev/cozyll/Cozyll-Metadata.html) (source:
`src/Cozyll/Metadata.hs`) for the full list of supported fields. Other fields become available as
part of the page/post's context, which you may use in templates or templated markup.

### Social metadata

Open Graph and JSON-LD are generated automatically for posts, the home page, standalone
pages, group indexes, and author pages. Keys are listed under *Frontmatter*
(`shareTitle`, `shareDescription`, `schemaType`); the emission rules and `@id` graph are
documented in
[`Cozyll.Context.SocialMeta`](https://cozyll.mathiassm.dev/cozyll/Cozyll-Context-SocialMeta.html).

### Per-article controls

A control is a checkbox in a page's aside that toggles a class on `<html>`. The contract lives in
[`Cozyll.Context.Aside`](https://cozyll.mathiassm.dev/cozyll/Cozyll-Context-Aside.html); the
step-by-step recipe is in [CONTRIBUTING.md](CONTRIBUTING.md#adding-a-control-toggle).
