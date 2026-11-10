# 0012. Build Provenance and Environment Isolation

- Status: Accepted
- Date: 2026-11-10

## Context

ADR 0004 promises that `prod`, `dev` and `example` do not leak into each other, but Hakyll
only writes the items of the current run: it never prunes `_site` and never checks that an
existing output file corresponds to the current inputs. A `dev` build followed by a `prod`
build therefore left draft pages in `_site`, and `cozyll check` happily audited them. The
same gap means deleting `_site` while keeping `_cache` leaves a partial tree with a success
exit, and `check` cannot tell whether it is looking at the current site at all.

## Decision

- After a successful `build`/`rebuild`, write `_cache/cozyll-build.json` with the tool
  version, the environment, the build timestamp and the content directory.
- Before a `build`/`rebuild`, if the recorded environment differs from the current one, or
  `_site` exists without a record, remove `_site` **and** `_cache` together and say why;
  `_site` cannot be invalidated independently of the cache. `watch`/`server` and
  `build --dry-run` never reset or stamp anything.
- `check` refuses a missing/empty `_site` and a tree built with another `SITE_ENV`, warns
  when the provenance is unknown or content is newer than the build, and never validates a
  stale tree.
- The state lives in `_cache`, which `clean` removes and which is never deployed.

## Consequences

- `_site` is a function of the current inputs and environment: a production artifact never
  contains dev-only output.
- Switching environments costs one full rebuild; the alternative (a partial tree) is worse.
- A deleted `_site` is caught by `check` instead of passing silently.
