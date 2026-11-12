# Theming

How the vendored theme is put together, which templates you can override, what fields each
template receives, and which CSS custom properties are available.

The theme lives in `templates/` and `assets/css/` in the kit. Your content directory can
override both without forking the kit.

## Overriding a template

Create a file with the same name under `content/templates/`:

```text
content/templates/post-list.html
```

It shadows `templates/post-list.html` for every page that uses it. The override is
file-by-file: every other template still comes from the vendored set. `$partial("templates/…")$`
paths are rewritten through the same resolution, so a content-provided partial is picked up
by vendored templates and by your own overrides. Templated page bodies (`templated: true`)
use the same rewriting.

Overrides take effect on the next `cozyll build`; you do **not** need `cozyll clean`.
Adding or removing an override changes the set of available templates, which invalidates
every rendered page, feed, sitemap and redirect. Editing an override rebuilds the pages that
depend on it, like any other file.

## Incremental builds

A `cozyll build` keeps `_cache/` and rebuilds only what changed. Besides the templates and
styles above, the build records a dependency on the site inputs: `website.yaml`,
`authors.yaml`, `socials.yaml`, `localization.yaml` and the brand logo under
`media/branding/logo.*`. Editing any of them updates the pages, feeds, sitemap,
`styles.css`, the manifest and the other well-known files on the next build, with no
`cozyll clean`.

`cozyll watch` reads the configuration when it starts, so restart it after editing those
files; watching content changes does not reload them.

Hakyll never deletes a route that leaves the rule set: removing the brand logo leaves the
previously generated `favicon.*` files in `_site/` until a `cozyll clean`.

`content.html` is a special case in how it is found, not in how it is overridden:

```haskell
-- Cozyll.Rules.SinglePages
applyTemplates ctx' ([contentTemplate cfg] <> pageTemplates <> [pageTemplate cfg]) item'
```

The builder applies `content.html` between the page body and `as-page.html`/`as-post.html`;
it is not referenced with `$partial("templates/content.html")$`. Grepping `templates/` will
not show it being used. Override it like any other template when you want to change the
`<div class="content">` wrapper.

## Template inventory

Every template receives the shared context: site fields (`site-title`, `site-description`,
`site-copyrightYear`, `site-copyrightRange`, `site-baseUrl`, `site-domain`,
`mathjax-version`), the page's `language`, the `t("id")` translation function, feeds, social
links, data files, authors and the page's own front matter. The table lists the fields the
template itself uses; see the module Haddocks for the complete context.

| Template | Purpose | Fields it uses |
|---|---|---|
| `site.html` | The page shell (`<html>`, `<body>`) | `language`, `body` |
| `site-head.html` | `<head>`: metadata, feeds, favicons, manifest | `jsonld`, `opengraph`, `feeds` (`title`, `href`), `site-baseUrl`, `path`, `home`, `title`, `description`, `site-title`, `site-description`, `favicons` (`href`, `rel`, `type`, `sizes`), `math`, `mathjax-version` |
| `site-header.html` | Site title, description and menu | `site-title`, `site-description`; renders `site-menu.html` |
| `site-menu.html` | The `nav:` menu | `nav` (`label`, `href`, `active`, `lang`) |
| `site-footer.html` | The footer | renders `copyright.html` |
| `copyright.html` | Copyright line | `site-title`, `site-copyrightRange` |
| `content.html` | Wrapper between the body and the page template (applied by the builder) | `body` |
| `as-page.html` | Standalone page | `title`, `body`; renders `site-aside.html` |
| `as-post.html` | Post page | `title`, `body`, `postCopyright`; renders `post-date.html`, `site-aside.html`, `post-copyright.html` |
| `post-date.html` | Byline, date and update date | `language`, `author` (`path`, `displayName`), `date`, `lastModifiedAt`, `t("post.updated")` |
| `post-copyright.html` | Per-post copyright notice | `postCopyrightHolders` (`name`), `postCopyrightYears` |
| `post-list.html` | A list of posts | `posts` (`url`, `slug`, `language`, `title`, `date`, `description`); renders `post-date.html` |
| `project-list.html` | A list of showcase projects | `projects` (`href`, `slug`, `status`, `title`, `shortDescription`, `longDescription`); renders `project-date.html` |
| `project-date.html` | Project dates | `language`, `startDate`, `endDate`, `t("project.started")`, `t("project.finished")` |
| `with-posts.html` | Group index: body plus post list | `body`; renders `post-list.html` |
| `with-projects.html` | Showcase index: body plus project list | `body`; renders `project-list.html` |
| `author.html` | Author profile page | `name`, `profileImage`, `description`, `links` (`url`); renders `post-list.html` |
| `site-aside.html` | Per-page aside with controls and table of contents | `hasAside`, `hasControls`, `rubyToggleLabel`, `imagesToggleLabel`, `toc`, `tocLabel` |
| `controls--ruby-toggle.html` | The ruby toggle control | `rubyToggleLabel` |
| `controls--images-toggle.html` | The image toggle control | `imagesToggleLabel` |
| `social-links.html` | The social account list | `socials` |
| `social-link-item.html` | One social link | `href`, `iconRaw`, `username` |
| `atom-feed.xml` | A group's Atom feed | `title`, `description`, `root`, `url`, `authorName`, `updated`, `body` |
| `atom-item.xml` | One Atom entry | `title`, `root`, `url`, `published`, `updated`, `description` |
| `sitemap.xml` | `sitemap.xml` | `entries` (`home`, `site-baseUrl`, `url`, `lastModifiedAt`, `date`) |

The contexts behind these fields are documented per module:

* [`Cozyll.Context`](https://cozyll.mathiassm.dev/cozyll/Cozyll-Context.html) — the shared global context.
* [`Cozyll.Context.Site`](https://cozyll.mathiassm.dev/cozyll/Cozyll-Context-Site.html) — site fields and favicons.
* [`Cozyll.Context.Author`](https://cozyll.mathiassm.dev/cozyll/Cozyll-Context-Author.html) — author and copyright fields.
* [`Cozyll.Context.Nav`](https://cozyll.mathiassm.dev/cozyll/Cozyll-Context-Nav.html) — menu entries.
* [`Cozyll.Context.Aside`](https://cozyll.mathiassm.dev/cozyll/Cozyll-Context-Aside.html) — controls and table of contents.
* [`Cozyll.Context.Feed`](https://cozyll.mathiassm.dev/cozyll/Cozyll-Context-Feed.html) — feed links.
* [`Cozyll.Context.Project`](https://cozyll.mathiassm.dev/cozyll/Cozyll-Context-Project.html) — project fields.
* [`Cozyll.Context.Social`](https://cozyll.mathiassm.dev/cozyll/Cozyll-Context-Social.html) — social accounts and inlined icons.
* [`Cozyll.Context.Language`](https://cozyll.mathiassm.dev/cozyll/Cozyll-Context-Language.html) — the page language.
* [`Cozyll.Config`](https://cozyll.mathiassm.dev/cozyll/Cozyll-Config.html) — `SiteConfig`, the template names and the source directories.

## Styles

Cozyll assembles one stylesheet, `styles.css`, from:

1. every `assets/css/*.css`, in filename order;
2. every `content/css/*.css`, in filename order;
3. the Pandoc syntax-highlighting stylesheet for `highlight.style`.

The numeric prefixes in `assets/css/` (`00-`, `05-`, `10-`, …) make the vendored order
explicit; your files always come after them, so the cascade works without `!important`.

In `SITE_ENV=dev`, the concatenated CSS and the highlighting CSS are left readable (comments
and formatting survive). `prod` and `example` minify both. Switching `SITE_ENV` clears
`_site/` and `_cache/`, so a readable development stylesheet cannot leak into production.

### Custom properties

`assets/css/00-variables.css` defines the theme's custom properties on `:root`. Override
them from a `content/css/*.css` file (or replace the file with a `content/css/00-variables.css`
override, which is concatenated after the vendored one).

Colours:

```css
--color-brand
--color-accent
--color-bg
--color-fg
--color-fg-muted
--color-bg-highlight
--color-interactive
--color-interactive-hover
--color-interactive-selected
--color-surface-weak
--color-surface-strong
--color-surface-brand
--color-surface-brand-fg
--color-surface-weak-border
--color-surface-strong-border
```

Borders and fonts:

```css
--round-corners
--font-mono
--font-latin-sans
--font-latin-serif
--font-cjk-ja-sans
--font-cjk-ko-sans
--font-cjk-zh-hant-sans
--font-cjk-zh-hans-sans
--font-cjk-ja-serif
--font-cjk-ko-serif
--font-cjk-zh-hant-serif
--font-cjk-zh-hans-serif
```

The file also sets `color-scheme: light dark` and uses `light-dark()` for the colour
values, so a replacement should keep a light and a dark value for each colour.
