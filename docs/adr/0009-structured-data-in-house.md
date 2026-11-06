# 0009. Structured Data In-House

- Status: Accepted
- Date: 2026-11-01

## Context

Open Graph and schema.org JSON-LD are needed for social previews and SEO. Investigation found no stable, widely-used Haskell library for emitting JSON-LD, schema.org, or Open Graph: there is no `json-ld` package on Hackage, and the nearest options are `rdf4h` for RDF and JSON-Schema validators such as `jsonschema`, which is already a dependency for validation. Structured data is therefore generated in-house.

## Decision

Generate structured data in-house in `src/Cozyll/JsonLd.hs` and `src/Cozyll/Context/SocialMeta.hs`:

- Open Graph plus a schema.org `@graph` with stable `@id`s: `#website`, `#organization`, `<page-url>#article`, and `https://<domain>/authors/<id>#person`/`#organization`.
- Standalone pages set a whitelisted `schemaType` of `WebPage | AboutPage | ContactPage | CollectionPage | ProfilePage`; any other value fails the build. It is ignored on posts, which are always `BlogPosting`, and overridden on `home: true`/`index: true` pages (which become `WebSite`/`CollectionPage`).
- Group index pages are `CollectionPage` plus `ItemList` (the showcase has no `ItemList`); author pages are `ProfilePage`.
- Articles emit `article:author` and published/modified timestamps. An opted-in post carries `copyrightNotice`/`copyrightHolder`.
- `shareTitle`, `shareDescription`, and `#main-image` are supported.

Twitter card tags and `twitterHandle` were removed.

The resulting `opengraph` and `jsonld` context fields are emitted by `templates/site-head.html`.

## Consequences

- The project has full control over `@id`s and output.
- There is no external dependency for structured data.
- The schema is narrow and strict: unknown `schemaType` values fail the build.
- Twitter-card support was dropped.
