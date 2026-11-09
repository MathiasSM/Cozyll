# Consumer CI

Cozyll ships a reusable GitHub Actions workflow and a set of composite actions, so a content
repo can build a site and run optional checks without writing its own pipeline.

This page covers the overall setup. Details for each item live with the item:

- Workflow inputs and jobs: [`.github/workflows/site-ci.yml`](../.github/workflows/site-ci.yml).
- Each check's inputs, requirements and notes: its own
  [`.github/actions/<name>/action.yml`](../.github/actions).

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

The workflow checks your repository out under `content/` and downloads the kit release for
`cozyll-version` (or the latest release when it is `latest`). It builds the site and runs the
enabled checks. Add your own `deploy` job after `site` if you publish to GitHub Pages or elsewhere.

Use `@master` for the tip, or pin an exact release tag (the release workflow tags each version, for
example `v3.1.0.1`) so the workflow does not change under you.

## Local checks

Build the site, then run the default set:

```sh
cozyll build
scripts/check-site.sh all --content-dir content --site-dir _site --schema-dir schema
```

The script is included next to `cozyll` in the release kit. Run `scripts/check-site.sh --help` for
the available checks and their tool requirements.

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

- The workflow assumes your content repo is checked out at `content/`. That is the directory
  Cozyll reads for production builds.
- `site-domain` is passed as `SITE_DOMAIN`; leave it empty to use `website.yaml`.
- External link and spelling checks are advisory or opt-in on purpose.
