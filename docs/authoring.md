# Authoring

How to lay out a Cozyll content directory: the required files, pages and posts, groups,
front matter, media, and feeds.

This guide is about the files under `content/`. The templates and styles that render them
are covered in [theming.md](theming.md).

## The content directory

Cozyll reads a content directory named `content/` (or `example-content/` when
`SITE_ENV=example`). A site needs these files:

| File | Purpose | Example |
|---|---|---|
| `website.yaml` | Site identity and output switches | [`schema/example.website.yaml`](../schema/example.website.yaml) |
| `socials.yaml` | Accounts linked from the site | [`schema/example.socials.yaml`](../schema/example.socials.yaml) |
| `authors.yaml` | Author map, with exactly one `siteDefault: true` | [`schema/example.authors.yaml`](../schema/example.authors.yaml) |
| `localization.yaml` | UI strings per language | [`schema/example.localization.yaml`](../schema/example.localization.yaml) |
| `writings/` | Your pages and posts | this guide |

Optional directories are `media/` (images and other assets), `static/` (files copied to
the site root), `data/` (YAML exposed to templates), `projects/` (the showcase), `templates/`
(theme overrides) and `css/` (extra styles).

If `content/website.yaml` is missing, the build stops before Hakyll runs and prints the
required tree above, with the schema example for each file. Missing required files are
reported the same way. `scripts/check-site.sh content-schema` validates the YAML files that
are present against the schemas in `schema/`.

## Writing content

### Pages and posts

There are two kinds of item under `writings/`:

* **Pages** are flat files under `writings/`, such as `writings/about.md`. They have no
  `date:`.
* **Posts** live in a group folder, such as `writings/blog/hello.md`. They need a
  `date:`.

Every item needs an explicit `path:`; see [Every item needs a path](#every-item-needs-a-path).

A page:

```yaml
---
title: About
path: /about
---

This is the about page.
```

A post:

```yaml
---
title: Hello
date: 2025-01-31
path: /blog/hello
---

This is a blog post.
```

Dates are ISO `YYYY-MM-DD`, on purpose: the same value is used for sorting, the `<time
datetime="…">` attribute, the visual date and the feed entry. Cozyll does not localise the
date text; use a template override if you need another presentation.

### Groups

A group is four things together:

1. An index page at `writings/<group>.md`.
2. A folder at `writings/<group>/` holding the group's posts.
3. A feed at `/<group>/atom.xml`.
4. A listing page, rendered from the index body plus the group's newest posts.

The index page is a flat page with `index: true`, its group name, and its own path:

```yaml
---
title: Blog
index: true
group: blog
path: /blog
description: Notes and longer posts.
---
```

The folder then looks like this:

```text
writings/
├── blog.md
└── blog/
    ├── hello.md
    └── another-post.md
```

The index page's `path:` is what the group is served at, and its `title:` and
`description:` become the feed's title and subtitle. The group's feed lists the newest
`feed.size` posts, as configured in `website.yaml`.

If a group folder has no index page, the build fails and names the page to create:

```text
no index page for the group "blog": create content/writings/blog.md with
  index: true
  group: blog
  path: /blog
(see docs/authoring.md, "Groups")
```

`group:` can also be set on an individual post to override the folder-derived group, but
the index page still describes the group as a whole.

The group named `showcase` is special: its items are the YAML files in `projects/`, not
files under `writings/showcase/`.

### Every item needs a path

`path:` is the output URL, not a file name. A path without an extension becomes a
directory with an `index.html` (`/about` → `about/index.html`); a path with an extension is
written as-is (`/404.html` → `404.html`).

The build validates the whole content tree before rendering. If items are missing `path:`,
it lists every offender in one go, with the line to add:

```text
Missing `path` front matter:
  content/writings/about.md: add `path: /about` (the output URL)
```

Drafts hidden by the current `SITE_ENV` are skipped, exactly as they are during the build.

### Drafts

Set `draft: true` on a page or post to keep it out of the published site:

```yaml
draft: true
```

`SITE_ENV=prod` (the default) and `SITE_ENV=example` hide drafts; `SITE_ENV=dev` builds
them. Because a draft must never survive into a production build, changing `SITE_ENV`
clears `_site/` and `_cache/` together before the next build.

### Aliases

`aliases:` publishes redirect pages from old paths to the item's `path:`:

```yaml
path: /blog/new-name
aliases: [/blog/old-name, /old-name]
```

Aliases must be absolute paths, must not be `/`, and must be unique. They cannot be the
item's own path or another item's path.

## Front matter

These are the keys most pages and posts use. The canonical list of every key is the
[`Cozyll.Metadata`](https://cozyll.mathiassm.dev/cozyll/Cozyll-Metadata.html) module
(source: `src/Cozyll/Metadata.hs`); this table only covers the ones authors reach for.

| Key | Required | Meaning |
|---|---|---|
| `title` | yes | The item's title. |
| `path` | yes | The output URL (see [Every item needs a path](#every-item-needs-a-path)). |
| `date` | posts | Publication date, ISO `YYYY-MM-DD`. Also the feed date. |
| `description` | no | Short summary, used by feeds and page metadata. |
| `draft` | no | `true` builds the item only in `dev`. |
| `group` | no | The post group; defaults to the folder under `writings/`. |
| `index` | no | `true` marks a page as its group's index page. |
| `home` | no | `true` marks the site's home page. |
| `aliases` | no | Old paths that redirect to this item. |
| `author` | no | An author id (or list) from `authors.yaml`; defaults to the site-default author. |
| `language` | no | The item's language (`en`, `ja`, `pt-BR`, …); defaults to `en`. |
| `nav`, `navOrder` | no | Add the page to the site menu, in order. |
| `sitemap` | no | `false` keeps the item out of `sitemap.xml`. |
| `schemaType` | no | The schema.org type of a standalone page; posts are always `BlogPosting`. |
| `templated` | no | `true` lets the body use template syntax such as `$partial(...)$`. |
| `TOC`, `rubyToggle`, `imagesToggle` | no | Enable the table of contents, ruby annotations or the image toggle; the value is the label. |

Any other front-matter key is available to that item's templates as a context field.

## Media and static files

Everything under `content/media/` is published. There is no extension allow-list, and
`content/static/` is copied verbatim to the site root:

| Source | Published |
|---|---|
| `content/media/photos/x.png` | `/images/photos/x.png` |
| `content/media/icons/x.svg` | `/images/icons/x.svg` (also inlined for `$iconRaw$`) |
| `content/media/branding/x` | `/images/x` (also inlined for `$partial$` when it is an SVG) |
| `content/media/<any>/x` | `/images/<any>/x` |
| `content/media/x` | `/images/x` |
| `content/media/**/*.dot` | the same path with `.png`, rendered with Graphviz `dot` |
| `content/static/x` | `/x` |
| `content/static/a/x` | `/a/x` |

`branding/` is the one flattening special case, so `media/branding/logo.svg` becomes
`/images/logo.svg`. `.dot` sources are the only converted files: everything else is copied
byte for byte.

`content/static/` is for files that must sit at the site root: `CNAME`, `.nojekyll`,
`_headers`, verification files, or hand-made icons. A static file wins over a generated
file at the same path. Files that would escape the site root (absolute paths or `..`
segments) fail the build.

### Logo, favicons and the manifest

The brand asset is `content/media/branding/logo.svg` or `content/media/branding/logo.png`;
SVG wins when both exist. The logo drives:

* the favicon set (`favicon.ico`, `favicon.svg` for an SVG source, `apple-touch-icon.png`,
  `favicon-192.png` and `favicon-512.png`);
* the `icons` in `manifest.webmanifest`.

With no logo there are no icon `<link>`s and no manifest `icons`; nothing points at a file
that does not exist. A file under `content/static/` at one of those paths replaces the
generated icon at that path.

Generating icons needs ImageMagick (`magick`, or `convert`) when there is a logo to convert;
copying an SVG favicon does not. `site.logo` in `website.yaml` is the published path used for
JSON-LD; when it is unset it defaults to the brand logo's published path.

## Feeds

Every post group has its own Atom feed at `/<group>/atom.xml`, built from the group's
newest posts. The feed's title and subtitle come from the group's index page, and its size
is `feed.size` in `website.yaml`. The page head links every group feed it finds. There is
no site-wide feed yet.

## What the build checks

Besides the checks above, the build fails once, naming the files, when:

* a required content file is missing;
* a page or post has no `path:`;
* a group folder has no index page;
* an `author:` id is not in `authors.yaml`;
* a `nav:` entry is invalid;
* an alias is invalid or claimed twice;
* a static file would be published outside the site root.

Run `cozyll build` to see the errors, and `cozyll check` after a build to validate links in
the generated `_site/`.
