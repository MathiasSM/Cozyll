# 0006. Generic Data Files

- Status: Accepted
- Date: 2026-10-19

## Context

Earlier bespoke typed TSV parsers (`hobbies`, `experience`) were rigid and required code changes for every new dataset. The project wanted template-drivable data with no fixed schema.

## Decision

Any `content/data/**/*.yaml` file is exposed to templates as a context named by its path: directories are joined with `-`, and `.yaml` is dropped. Names should therefore avoid `-`.

- Lists are looped with `$for(name)$`.
- Maps are read with dotted keys (`$name.key$`), with nested maps flattened.
- Scalars render as strings.
- `_show: false` hides a list item.
- Any field whose name contains `icon` also exposes `<field>Href` and `<field>Raw`.

An optional co-located `<name>.schema.json` is validated at build time.

This is implemented in `src/Cozyll/Context/Data.hs`, with the data and schema patterns defined in `src/Cozyll/Config.hs`.

## Consequences

- Adding a data set no longer requires generator code changes.
- Schema validation is opt-in per data file.
- The former `validateHobbyPages` cross-check and typed parsers were removed.
- The path-to-context mapping reserves `-` as the directory separator, and dotted keys are significant in template lookups.
