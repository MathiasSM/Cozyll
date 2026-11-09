# Contributing

## Branches

Work happens on short-lived feature branches named `type/description`, merged
to `master` ONLY via a pull request. You may use
the [Conventional Commits](https://www.conventionalcommits.org/) types
(`feat/`, `fix/`, `docs/`, `chore/`, `ci/`, `refactor/`, `test/`, ...); not a strict policy.

## Theme override

Templates and styles are split between a vendored generic default (this repo's
`templates/` and `assets/css/`) and the content repository. A content repo
overrides either, file by file:

- `content/templates/<name>` shadows `templates/<name>` — including `$partial`
  references inside other templates. Missing files fall back to the vendored set.
- `content/css/*.css` is concatenated after the vendored styles, so it overrides
  them through the cascade.

Templates read a fixed set of fields (the site identity, `nav`, `socials`,
`posts`, `projects`, `feeds`, `math`, and the data-file names under
`content/data/`); the vendored templates are the reference for that contract.

## Development tools

Install these with ghcup, or via `cabal install PKG-VERSION`:

- **fourmolu** — CI installs whatever version the `FOURMOLU_VERSION` repository
  variable holds (Settings → Secrets and variables → Actions → Variables; read
  by `.github/workflows/_ci.yml` and passed to the format job). Use that same
  version locally, e.g. `cabal install fourmolu-<that version>`; as of writing
  it is `0.20.1.0`. There is no in-repo pin to keep in sync.
- **hlint** — use the **latest** if in doubt. It's intentionally not pinned
  here: CI runs hlint from inside the `haskell-actions/hlint-scan` action
  image, which bundles its own hlint version (`.github/workflows/hlint.yml`
  passes no version), so there's no in-repo version to mirror. Any recent
  hlint is fine for local use.

## Adding a control (toggle)

The contract lives in `Cozyll.Context.Aside`. To add a control:

1. Pick the class to toggle (`no-images`) and add a front-matter key whose value
   is the control's label (`imagesToggle: "Images"`); add a `Metadata.Key`
   constructor **and** its `keyName` case (e.g. `ImagesToggle -> "imagesToggle"`)
   in `src/Cozyll/Metadata.hs`.
2. List it in `controlKeys` in `src/Cozyll/Context/Aside.hs`, and add its
   `toggleLabelField <Key> "<name>ToggleLabel"` line to `asideContext`.
3. Add `templates/controls--<name>-toggle.html`: a `<label class="<name>-toggle">`
   wrapping `<input type="checkbox" checked data-toggle-class="no-images" />` and
   `$<name>ToggleLabel$` (mirror `controls--images-toggle.html`).
4. Add a gated `<li>` to `templates/site-aside.html`, inside
   `$if(<name>ToggleLabel)$ … $endif$` (mirror the `rubyToggleLabel` /
   `imagesToggleLabel` blocks). `controlKeys` plus the label field drive both
   `hasControls` and that gate.
5. Add the hiding CSS (e.g. `.no-images img, .no-images figure {display: none;}`).
   The shared script in `site-aside.html` needs no change: it wires every
   `[data-toggle-class]` checkbox and toggles the class while unchecked.

## Commits

Keep commits clean and focused. Run `fourmolu` and `hlint` before committing;
the repository ships a [pre-commit](https://pre-commit.com/) hook that does
this automatically. Install it with `mise install` (declared in `mise.toml`),
then enable the hook:

```sh
pre-commit install
```

Run it manually over the whole tree with `pre-commit run --all-files`.

## CI workflows

Workflows and actions split into two groups:

- **Internal** (not a consumer contract): workflows prefixed with `_` (for example `_ci.yml`,
  `_build-test.yml`, `_hlint.yml`, `_fourmolu.yml`, `_example-checks.yml`), plus the release and
  repository automation workflows. These may change freely.
- **Consumer-facing**: `.github/workflows/site-ci.yml` and the composite actions under
  `.github/actions/`. These are the reusable surface documented in
  [docs/consumer-ci.md](docs/consumer-ci.md); change them with care and keep the docs in sync.

`_example-checks.yml` runs the consumer checks against `example-content`, so a change to a consumer
check or to the vendored templates and styles is exercised here before it reaches a release.

## Releases

Version bumps happen only in a dedicated release PR: bump `version:` in
`cozyll.cabal` and add a matching `[version]` entry to `CHANGELOG.md`.

Follow [RELEASE-CHECKLIST.md](RELEASE-CHECKLIST.md) for details.

## Architecture decisions

Significant, hard-to-reverse design decisions are recorded as ADRs under
`docs/adr/` — see [docs/adr/README.md](docs/adr/README.md) for the index.
