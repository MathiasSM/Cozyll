{- | Front-matter keys the site knows about, and how they are spelled.
This is the canonical reference for the front-matter keys; the README's
*Frontmatter* section points here.
-}
module Cozyll.Metadata (
    Key (..),
    keyName,
    lookupKey,
    lookupKeyList,
)
where

import Hakyll (Metadata, lookupString, lookupStringList)

{- | Every known front-matter key the content may use. A user may add more fields to
any given file's frontmatter, to use the value within that page's context
(templates, or templated pages)
-}
data Key
    = -- | __Required__. The item's title.
      Title
    | -- | __Required__. The output path/URL (required for posts and pages). Same format as 'Date'.
      Path
    | -- | __Required__. A post's publication date (@YYYY-MM-DD@), used to sort posts and as the feed date.
      Date
    | -- | An explicit feed publish date; Hakyll's feed rendering falls back to 'Date'.
      Published
    | -- | When the item was last updated (must not precede 'Date'!). Same format as 'Date'.
      LastModifiedAt
    | -- | Create paths that redirect to this page (use to redirect old paths to new ones). See 'Path'.
      Aliases
    | -- | A short description, used for the feed and page metadata.
      Description
    | -- | Overrides 'Description' in social metadata (Open Graph and JSON-LD); falls back to 'Description' when unset.
      ShareDescription
    | -- | Overrides 'Title' in social metadata (Open Graph and JSON-LD); falls back to 'Title' when unset.
      ShareTitle
    | -- | The post's author(s): an id (or list of ids) from @authors.yaml@.
      Author
    | {- | The schema.org type of a standalone page (default @WebPage@). One of
      @WebPage@, @AboutPage@, @ContactPage@, @CollectionPage@, or
      @ProfilePage@; any other value fails the build. Ignored on posts
      (always @BlogPosting@) and overridden on pages marked 'Home'
      (@WebSite@) or 'Index' (@CollectionPage@). See
      "Cozyll.Context.SocialMeta".
      -}
      SchemaType
    | -- | An icon name, resolved to @images/icons/<name>.svg@.
      Icon
    | {- | The item's language: a 2-letter ISO 639-1 code with an optional
      region (@en@, @pt-BR@); defaults to @en@. Lookup falls back from
      @xx-YY@ to @xx@. See "Cozyll.Domain.Language" and
      "Cozyll.Localization".
      -}
      Language
    | {- | Marks an item as a draft: the page is built only if @SITE_ENV=dev@,
      hidden otherwise.
      -}
      Draft
    | -- | The post group an item belongs to (otherwise its folder under @writings/@).
      Group
    | -- | Marks a page as a group's index page (@index: true@).
      Index
    | -- | Marks a standalone page as the site's home page (@home: true@).
      Home
    | -- | Include the page as a menu label (requires 'NavOrder').
      Nav
    | -- | The menu sort order (lower first).
      NavOrder
    | -- | Exclude from the sitemap when @false@.
      Sitemap
    | -- | A project's start date.
      StartDate
    | -- | A project's status (@alpha@, @finished@, @ongoing@, or @unmaintained@).
      Status
    | -- | A project's URL or a social account's profile.
      Href
    | -- | A project's team (a list of names).
      Team
    | -- | Enables: Process the body as a template (@templated: true@).
      Templated
    | {- | Enables: Generate a table of contents from the headings; the value is
      the table of contents' label (@TOC: Contents@).
      -}
      TOC
    | -- | Enables: The ruby-level control; the value is the control's label (markdown).
      RubyControl
    | -- | Enables: The unknown-level ruby checkbox; the value is its label (markdown).
      RubyUnknown
    | -- | Words that may appear without furigana (coverage exemption).
      RubySkip
    | -- | Ruby surfaces (or @surface:reading@ pairs) accepted without a dictionary match.
      RubyAllow
    | -- | Overrides the site's ruby check severity (@off@, @warn@, @error@).
      RubyCheck
    | -- | Enables: The hide-images toggle; the value is the control's label (markdown).
      ImagesToggle
    | -- | A social account's username/handle.
      Username
    | -- | Whether to show this social account (shown by default; @_show: false@ hides it).
      Show
    | -- | A project's end date (optional).
      EndDate
    | -- | A project's showcase priority (lower sorts first).
      Priority
    | -- | A project's short description.
      ShortDescription
    | -- | A project's long description.
      LongDescription
    deriving (Eq, Show, Enum, Bounded)

-- | The key as spelled in front matter
keyName :: Key -> String
keyName key = case key of
    Title -> "title"
    Date -> "date"
    Published -> "published"
    Description -> "description"
    Aliases -> "aliases"
    Draft -> "draft"
    EndDate -> "endDate"
    Group -> "group"
    Home -> "home"
    Href -> "href"
    Icon -> "icon"
    Index -> "index"
    Language -> "language"
    LastModifiedAt -> "lastModifiedAt"
    LongDescription -> "longDescription"
    Nav -> "nav"
    NavOrder -> "navOrder"
    Path -> "path"
    Priority -> "priority"
    ShareDescription -> "shareDescription"
    ShareTitle -> "shareTitle"
    Author -> "author"
    SchemaType -> "schemaType"
    ShortDescription -> "shortDescription"
    Show -> "_show"
    Sitemap -> "sitemap"
    StartDate -> "startDate"
    Status -> "status"
    Team -> "team"
    Templated -> "templated"
    TOC -> "TOC"
    RubyControl -> "rubyControl"
    RubyUnknown -> "rubyUnknown"
    RubySkip -> "rubySkip"
    RubyAllow -> "rubyAllow"
    RubyCheck -> "rubyCheck"
    ImagesToggle -> "imagesToggle"
    Username -> "username"

-- | Looks up a key's value as a string
lookupKey :: Key -> Metadata -> Maybe String
lookupKey = lookupString . keyName

-- | Looks up a key's value as a list of strings, falling back to a single string
lookupKeyList :: Key -> Metadata -> Maybe [String]
lookupKeyList key metadata = case lookupStringList (keyName key) metadata of
    Just values -> Just values
    Nothing -> pure <$> lookupKey key metadata
