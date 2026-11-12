# Consumer CI

Cozyll ships a reusable GitHub Actions workflow and a set of composite actions, so a content
repo can build a site and run optional checks without writing its own pipeline.

This page covers the overall setup. Details for each item live with the item:

- Workflow inputs and jobs:
  [`site-ci.yml`](https://github.com/MathiasSM/Cozyll/blob/master/.github/workflows/site-ci.yml).
- Each check's inputs, requirements and notes: its own
  [`.github/actions/<name>/action.yml`](https://github.com/MathiasSM/Cozyll/tree/master/.github/actions).

## Kit layout

The release tarball contains the generator and the theme; it does not contain the content
repo, the GitHub workflows, or the ADRs:

```text
cozyll
templates/            # vendored theme templates
assets/               # vendored CSS
schema/               # the four YAML schemas and their examples
scripts/check-site.sh # the local check runner
README.md
docs/authoring.md
docs/theming.md
docs/consumer-ci.md
```

The kit is unpacked into the workspace root. `cozyll build` reads `content/` next to it.
The ADRs under `docs/adr/` stay in the Cozyll repository; the kit only ships the four files
above.

## Quick start

Create `.github/workflows/ci.yml` in your content repo:

```yaml
name: Site CI

on:
  push:
    branches: [master]
  pull_request:
  schedule:
    - cron: "0 6 1 * *"
  workflow_dispatch:

jobs:
  site:
    uses: MathiasSM/Cozyll/.github/workflows/site-ci.yml@master
    with:
      cozyll-version: latest
      site-domain: example.com
```

GitHub only reads workflows from the repository root, so the file lives at
`.github/workflows/ci.yml` in the content repo. The reusable workflow checks that repository
out under `content/` in the runner workspace, installs the kit next to it, and builds there.

Use `@master` for the tip, or pin an exact release tag (the release workflow tags each version, for
example `v3.1.0.1`) so the workflow does not change under you.

## What the workflow does

The `site` job checks the content repo out under `content/`, installs the kit release for
`cozyll-version` (or the latest release when it is `latest`), builds the site, runs
`cozyll check`, and uploads `_site/` as an artifact. Add your own deploy job after `site` if
you publish to GitHub Pages or elsewhere.

The remaining jobs are opt-in through the workflow inputs:

- `content-schema` validates `website.yaml`, `authors.yaml`, `socials.yaml` and
  `localization.yaml` against the shipped schemas; missing files are skipped.
- `html`, `jsonld`, `xml` and `wellknown` validate the generated output.
- `a11y` runs the accessibility audit. It is advisory (`continue-on-error`), so findings
  do not fail the workflow. The check uses `pa11y-ci` with the **axe** runner; bare
  `npx pa11y` defaults to HTML_CodeSniffer and can report different findings.
- `links-external` and `spelling` are opt-in and are not part of the default set.

`site-domain` is passed as `SITE_DOMAIN`; leave it empty to use `website.yaml`.

## The content repo

The content repo contains everything you write and commit: the four YAML files,
`writings/`, `media/`, `static/`, optional `templates/` and `css/` overrides, and the
workflow file. It is checked out under `content/`, which is the directory Cozyll reads for
production builds.

Its `.gitignore` should include the generated files:

```gitignore
_site/
_cache/
*.tix
```

`_site/` and `_cache/` are written in the working directory when you run `cozyll` locally;
`*.tix` is only produced when you build Cozyll from source with coverage enabled.

## Funding is optional

`funding:` may be omitted from `website.yaml`. A site without it publishes no
`funding.json` and no `.well-known/funding-manifest-urls`; the well-known check validates
`funding.json` when it is present and skips it otherwise.

## Platform

The kit targets Linux x86_64. The release notes state the platform baseline for each release.

## Local checks

Build the site, then run the default set:

```sh
cozyll build
scripts/check-site.sh all --content-dir content --site-dir _site --schema-dir schema --a11y-fail false
```

The script and its helper files in `scripts/` are included next to `cozyll` in the release kit. Run `scripts/check-site.sh --help`
for the available checks and their tool requirements. `all` exits 0 when clean, 1 on a hard
failure, and 2 when the only findings are advisory accessibility ones. Accessibility findings
are advisory unless `--a11y-fail true` is passed.

## Migrating from a hand-written workflow

- Remove the Lighthouse step. Cozyll no longer recommends it; accessibility is covered by
  `check-a11y`.
- Remove `repository_dispatch: [kit-released]`. The dispatch workflow was removed, so consumers
  pick up new kits through their own schedule or a manual run.
- Optional: run the spelling check as a local pre-commit hook instead of a CI gate. Mixed-language
  content makes a spelling gate too noisy:

  ```yaml
  # .pre-commit-config.yaml in the content repo
  repos:
    - repo: local
      hooks:
        - id: typos
          name: typos
          entry: typos
          language: system
          types: [text]
  ```

  Add a `.typos.toml` allow-list for names and non-English words.

## Notes

- External link and spelling checks are advisory or opt-in on purpose.
- Authoring is covered in [authoring.md](authoring.md); the template and CSS contract is in
  [theming.md](theming.md).
