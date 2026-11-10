# 0004. Site Environment Modes

- Status: Accepted
- Date: 2026-10-15

## Context

The generator needs to build real content for production and development, and the bundled example content as a whole site, without these modes leaking into each other.

## Decision

`SITE_ENV` is one of `prod`, `dev`, or `example`. It is parsed by `parseEnv` in `src/Cozyll/Cli.hs`; unset means `prod`, and any other value fails the build.

- `prod` hides drafts.
- `dev` shows drafts for the real content.
- `example` builds the bundled `example-content/` as the whole site, with drafts hidden.

`contentDirFor` in `src/Cozyll/Cli.hs` selects the content directory, and the resulting `Env` is carried in `SiteConfig` (`src/Cozyll/Config.hs`).

## Consequences

- One CLI provides deterministic behavior across the three modes.
- Unknown `SITE_ENV` values fail fast rather than silently falling back.
- The example content serves as both a demo and the golden test fixture.
- Adding another mode would require changes in the CLI, configuration, and build rules.
- Later amended in 3.0.0.0 (2026-11-01): `SITE_ENV=example` was added to build the bundled example content.
- Amended in 3.4.0.0 (2026-11-10): the modes are enforced across builds. A build records its
  environment in `_cache/cozyll-build.json`; changing it clears `_site` and `_cache` together,
  and `cozyll check` refuses a tree built under another environment. See ADR 0013.
