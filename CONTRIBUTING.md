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

Overrides are discovered only at the top level of `content/templates/` (the lookup is
non-recursive); a template in a nested directory is not shadowable.

Templates read a fixed set of fields (the site identity, `nav`, `socials-*`,
`posts`, `projects`, `feeds`, `math`, and the data-file names under
`content/data/`); the vendored templates are the reference for that contract.

## Development tools

Install these with ghcup, or via `cabal install PKG-VERSION`:

- **fourmolu** `0.20.1.0` - pinned to match CI (`FOURMOLU_VERSION`).
- **hlint** - use the **latest** if in doubt. It's intentionally not pinned
  here: CI runs hlint from inside the `haskell-actions/hlint-scan` action
  image, which bundles its own hlint version, so there's no in-repo version
  to mirror. Any recent hlint is fine for local use.

## Commits

Keep commits clean and focused. Run `fourmolu` and `hlint` before committing;
the repository ships a [pre-commit](https://pre-commit.com/) hook that does
this automatically. Install it with `mise install` (declared in `mise.toml`),
then enable the hook:

```sh
pre-commit install
```

Run it manually over the whole tree with `pre-commit run --all-files`.

## Releases

Version bumps happen only in a dedicated release PR: bump `version:` in
`cozyll.cabal` and add a matching `[version]` entry to `CHANGELOG.md`.

Follow [RELEASE-CHECKLIST.md](RELEASE-CHECKLIST.md) for details.