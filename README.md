# Cozyll

[![Haskell](https://img.shields.io/badge/Haskell-5e5086?logo=haskell&logoColor=white)](https://www.haskell.org/)
[![License](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](https://github.com/MathiasSM/Cozyll/blob/master/LICENSE.txt)
[![GitHub release](https://img.shields.io/github/v/release/MathiasSM/Cozyll)](https://github.com/MathiasSM/Cozyll/releases/latest)
[![Hackage](https://img.shields.io/hackage/v/mathiassm?label=Hackage)](https://hackage.haskell.org/package/cozyll)

[![CI](https://img.shields.io/github/actions/workflow/status/MathiasSM/Cozyll/_ci.yml?label=CI)](https://github.com/MathiasSM/Cozyll/actions/workflows/_ci.yml)
[![CodeQL](https://img.shields.io/github/actions/workflow/status/MathiasSM/Cozyll/codeql.yml?label=CodeQL)](https://github.com/MathiasSM/Cozyll/actions/workflows/codeql.yml)
[![Codecov](https://img.shields.io/codecov/c/github/MathiasSM/Cozyll)](https://app.codecov.io/github/MathiasSM/Cozyll)
[![Dependabot](https://img.shields.io/badge/Dependabot-enabled-025E8C?logo=dependabot&logoColor=white)](https://github.com/MathiasSM/Cozyll/blob/master/.github/dependabot.yml)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](.pre-commit-config.yaml)

[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/15535/badge)](https://www.bestpractices.dev/projects/15535)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/MathiasSM/Cozyll/badge)](https://scorecard.dev/viewer/?uri=github.com/MathiasSM/Cozyll)


This is a [hakyll](https://hackage.haskell.org/package/hakyll)-based site generator. It's main purpose is to build [mathiassm.dev (my personal site)](https://mathiassm.dev), but it can be used to build other kinds of sites with similar needs. In essence, it's a thin-ish layer of extra logic, some premade templates and styling, on top of the actual generator library by [jaspervdj](https://jaspervdj.be/).

## Usage

You may download the [latest release](https://github.com/MathiasSM/Cozyll/releases/latest), which should include an executable for ubuntu (I can tweak the release thing to provide statically-linked executables, or builds for other platforms, but I don't know of anyone needing them as of writing). Keep in mind the main reason for the release is more easy integration with Github actions to publish a "content repo" using this. You may run the executable in a directory with:

- `templates/` vended hakyll templates that define components of each (usually html) pages. There are included files in the release tarball and this repo, but you may change them as you need to.
- `assets/` vended styles and potentially other files, either too basic or coupled with the vended templates.
- `content/` where all writing, images and other stuff lives. To build my personal site, I use a separate repo that holds these files. It expects some files:
  - `website.yaml` (see `schema/example.website.yaml`), a file with metadata about the site, for use during generation. The `site:` block supports `name`, `description`, `author`, `copyrightYear`, `domain`, and optionally `alternateName` (a list of alternate site names) and `logo` (a site-relative path to a raster logo, e.g. `images/logo.png`; Google wants it at least 112×112).
  - `socials.yaml` (see `schema/example.socials.yaml`), a file with a list of accounts linked to you/your site, used for templates to build links to those profiles, and for some `.well-known` files.
  - `writings/` shall contain any and all markdown/djot/whatever files, each of which will become a specific page in your site. Each file has a frontmatter yaml which adds some metadata to the processed page (see [Frontmatter](#frontmatter)). 
  - `data/` may hold yaml files, which are translated into usable context fields, usable in templates or templated pages (see [Data Files](#data-files)).
  - `media/` may hold images and other binary files which can be included in the site and linked to.
  - Optionally, a `templates/` directory may hold additional templates, or override existing ones (by using the same name). 
  - Optionally, a `css/` directory may hold additional stylesheets, or override existing ones (by using the same name). 


The way to execute this is same as any hakyll site; if you build it from source, you can use `cabal exec cozyll <CMD>` instead.

- `<CMD>` is any of:
  - `build` (generate site)
  - `clean` (cleanup and remove cache)
  - `rebuild` (clean and build again)
  - `server` (run server on what's built)
  - `watch` (recompile server)
  - `check` (check the built html for broken links)
    - Note: By default hakyll checks external links as well, but due to some broken external sites, I decided to disable it via compilation flags.

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

  - You may install `hls`, `fourmolu`, `hlint`, `apply-refact` with it, or use `cabal install PKG-VERSION` (see [CONTRIBUTING.md](CONTRIBUTING.md) for the expected `fourmolu`/`hlint` versions)
  - Remember to `ghcup set <TOOL>` (in particular, you might need to `ghcup set cabal 3.14` because of hlint support)
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

---


## Data files

Any YAML under `content/data/**/*.yaml` becomes a template context named after its path: directories are joined with `-` and the `.yaml` extension is dropped. So `content/data/team/members.yaml` is available as `team-members`. Avoid `-` inside file and directory names themselves, since it doubles as the directory separator.

- A file holding a top-level **list** is looped with `$for(name)$`; each item's keys are exposed as fields (`$name$`, `$href$`, …).
- A file holding a top-level **map** is read with dotted keys (`$name.key$`); nested maps flatten the same way (`$name.address.city$`).
- Scalars render as strings (booleans as `true`/`false`, numbers without scientific notation).

Any scalar field whose name contains `icon` also gets two derived fields: `<field>Href` (the icon URL, a bare name resolved to `images/icons/<name>.svg`) and `<field>Raw` (the SVG markup, inlined). For example, `icon: book` provides `$icon$`, `$iconHref$` and `$iconRaw$`.

A data file may ship a JSON Schema, co-located as `content/data/name.schema.json` next to `content/data/name.yaml`; it is validated at build time (and the YAML's `$schema` points at the local file for editor hints).

## Frontmatter

See `src/Cozyll/Metadata.hs` or its documentation for a full list of supported fields. Other fields become available as part of the page/post's context, which you may use in templates or templates markup.

### Social metadata

Open Graph tags and JSON-LD structured data are emitted on posts, the home page, and standalone pages automatically.

- `shareTitle` and `shareDescription` override the social title and description (which otherwise fall back to `title` and `description`).
- `#main-image` on an image (`![alt](src){#main-image}`) marks it as the Open Graph / JSON-LD image; its URL is resolved to an absolute one.

## Adding a control (toggle)

A control is a checkbox in a page's aside that toggles a CSS class on `<html>`
(e.g. `no-images`), so you can show/hide elements by classname. To add one:

1. Pick the class to toggle (`no-images`) and add a front-matter key whose value
   is the control's label (`imagesToggle: "Images"`); add a `Metadata.Key` for it.
2. List it in `controlKeys` in `src/Cozyll/Context/Aside.hs`, and add its
   `toggleLabelField <Key> "<name>ToggleLabel"` line to `asideContext`.
3. Add `templates/controls--<name>-toggle.html`: a `<label>` with
   `<input type="checkbox" checked data-toggle-class="no-images">` and `$<name>ToggleLabel$`.
4. Add a gated `<li>` to `templates/site-aside.html`.
5. Add the hiding CSS (`.no-images img { display:none }`). The shared script needs no change.
