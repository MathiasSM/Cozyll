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

## Usage

You may download the [latest release](https://github.com/MathiasSM/Cozyll/releases/latest), which should include an executable for ubuntu (I can tweak the release thing to provide statically-linked executables, or builds for other platforms, but I don't know of anyone needing them as of writing). Keep in mind the main reason for the release is more easy integration with Github actions to publish a "content repo" using this. You may run the executable in a directory with:

- `templates/` vended hakyll templates that define components of each (usually html) pages. There are included files in the release tarball and this repo, but you may change them as you need to.
- `assets/` vended styles and potentially other files, either too basic or coupled with the vended templates.
- `content/` where all writing, images and other stuff lives. To build my personal site, I use a separate repo that holds these files. It expects these files:
  - `website.yaml` (see `schema/example.website.yaml`), a file with metadata about the site, for use during generation. Required.
  - `socials.yaml` (see `schema/example.socials.yaml`), a file with a list of accounts linked to you/your site, used for templates to build links to those profiles, and for some `.well-known` files. Required.
  - `authors.yaml` (see `schema/authors.schema.json`), a map keyed by author id: each author's name, links, profile image, and the one flagged `siteDefault: true` (see [Authors](#authors)). Required.
  - `localization.yaml`, a map of UI string id → `{ locale: translation }` (plus the reserved `_ogLocaleDefaultRegion` key) that backs the templates' `$t("id")$` lookups and `og:locale`. Required, even for a single-language site; the build fails on a missing translation.
  - `writings/` shall contain any and all markdown/djot/whatever files, each of which will become a specific page in your site. Each file has a frontmatter yaml which adds some metadata to the processed page (see [Frontmatter](#frontmatter)).
  - `data/` may hold yaml files, which are translated into usable context fields, usable in templates or templated pages (see [Data Files](#data-files)).
  - `media/` may hold images and other binary files which can be included in the site and linked to.
  - `projects/` may hold YAML files, each becoming an item on the projects (showcase) page.
  - Optionally, a `templates/` directory may hold additional templates, or override existing ones (by using the same name).
  - Optionally, a `css/` directory may hold additional stylesheets, or override existing ones (by using the same name).


The way to execute this is same as any hakyll site; if you build it from source, you can use `cabal exec cozyll <CMD>` instead.

- `<CMD>` is any of:
  - `build` (generate site)
  - `clean` (cleanup and remove cache)
  - `rebuild` (clean and build again)
  - `server` (run server on what's built)
  - `watch` (recompile server)
  - `check` (validate the already-built HTML in `_site` for broken links; run `build` first)
    - Only internal links are checked: `cabal.project` sets `constraints: hakyll -checkexternal`, which compiles out Hakyll's external-link check, so external URLs are skipped silently. Upstream's `checkExternal` flag defaults to on; see the comment in `cabal.project` for why it is off here.

You may set environment variables to override some `website.yaml` fields; export them manually, use a `.env` file, or your preferred method. See `.env.example`.

```sh
# Environment:

# prod: production build of the real content; drafts hidden (default)
SITE_ENV=prod

# dev: development build of the real content; drafts shown
# SITE_ENV=dev

# example: build the example content at the site root; drafts hidden
# SITE_ENV=example
```

## Development

### Local

#### Setup

1. Install ImageMagick (e.g. via `sudo apt install imagemagick`).
2. Install ghcup (e.g. using `mise use -g ghcup`).
3. Use ghcup to install `ghc`, `cabal` (both required)
4. Install the repo's `mise.toml` tools (`pre-commit`, `actionlint`):

   ```sh
   mise install
   ```

  - You may install `hls`, `fourmolu`, `hlint`, `apply-refact` with it, or use `cabal install PKG-VERSION` (see [CONTRIBUTING.md](CONTRIBUTING.md); CI reads the fourmolu, GHC, and cabal versions from the `FOURMOLU_VERSION`, `GHC_VERSION`, and `CABAL_VERSION` repository variables)
  - Remember to `ghcup set <TOOL>` (in particular, match CI with `ghcup set cabal <CABAL_VERSION>`)
5. Enable the git hooks (runs `fourmolu` and `hlint` before each commit) via
   [pre-commit](https://pre-commit.com/); see [CONTRIBUTING.md](CONTRIBUTING.md).

#### Build

1. `cabal build all`: First time will take a while, but dependencies won't need to recompile often.

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

Either

- Via your editor (in my case, NeoVim's lsp registering the installed `hls`, configured with `hlint` and `fourmolu`).
- Calling the executables directly over `app/`, `src/`, `test/`.

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
site, and runs the enabled checks (content schema, HTML, accessibility, JSON-LD, well-known files,
XML). External links and spelling checks are opt-in. See
[docs/consumer-ci.md](docs/consumer-ci.md) for the full input list, the individual composite
actions, and migration notes. Pin an exact release tag instead of `@master` for stability.

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
