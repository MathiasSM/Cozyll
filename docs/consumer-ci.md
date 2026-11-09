# Consumer CI

Cozyll ships a reusable GitHub Actions workflow and a set of composite actions, so a content
repo can build a site and run optional checks without writing its own pipeline.

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

## Inputs

| Input | Type | Default | Meaning |
| --- | --- | --- | --- |
| `cozyll-version` | string | `latest` | Kit release tag, for example `v3.1.0.1`. |
| `site-domain` | string | empty | Value for `SITE_DOMAIN`. Empty uses `website.yaml`. |
| `run-links-internal` | boolean | `true` | Run `cozyll check` (internal links). |
| `run-content-schema` | boolean | `true` | Validate content YAML against the shipped schemas. |
| `run-html` | boolean | `true` | Validate HTML, CSS and SVG with the W3C Nu checker. |
| `run-a11y` | boolean | `true` | Accessibility audit with pa11y and axe. |
| `run-jsonld` | boolean | `true` | Validate JSON-LD blocks in generated HTML. |
| `run-wellknown` | boolean | `true` | Validate security.txt, funding.json, manifest, robots, trust and sitemap. |
| `run-xml` | boolean | `true` | Validate that generated XML is well formed. |
| `run-links-external` | boolean | `false` | Check external links with lychee. |
| `run-spelling` | boolean | `false` | Run typos. Advisory. |

Every check is a separate job, so a disabled check is skipped and never blocks the others.

## Checks

- **Build and internal links.** `cozyll build`, then `cozyll check`. Only internal links are
  checked; Hakyll external checking is compiled out.
- **Content schema.** `check-jsonschema` against `schema/website.schema.json`,
  `schema/authors.schema.json` and `schema/socials.schema.json`.
- **HTML.** W3C Nu (`vnu.jar`) over the built site, including CSS and SVG.
- **Accessibility.** `pa11y-ci` with the axe runner over every generated HTML page, served locally.
- **JSON-LD.** Every `<script type="application/ld+json">` block must parse and declare
  `@context` plus `@type` or `@graph`.
- **Well-known files.** Presence and shape of `robots.txt`, `manifest.webmanifest`, `funding.json`,
  `sitemap.xml`, `.well-known/security.txt` (Contact plus a future Expires) and
  `.well-known/trust.txt`.
- **XML.** `xmllint --noout` over generated XML (Atom feeds, sitemap).
- **External links.** `lychee` over the built site. Advisory by default; enable it on a schedule
  rather than on every pull request, because the internet is not deterministic.
- **Spelling.** Advisory and opt-in.

## Composite actions

If you would rather compose your own workflow, the individual actions live under
`.github/actions/` and can be referenced directly:

| Action | Purpose |
| --- | --- |
| `setup-cozyll` | Download and unpack a kit (release or local tarball), put `cozyll` on PATH. |
| `check-content-schema` | Validate content YAML against the shipped schemas. |
| `check-html` | Validate HTML, CSS and SVG with the W3C Nu checker. |
| `check-a11y` | Accessibility audit with pa11y and axe. |
| `check-links-external` | Check external links with lychee. |
| `check-xml` | Validate generated XML. |
| `check-jsonld` | Validate JSON-LD blocks. |
| `check-wellknown` | Validate well-known and metadata files. |
| `check-spelling` | Run typos (advisory). |

Reference them as `MathiasSM/Cozyll/.github/actions/<name>@<ref>`.

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
