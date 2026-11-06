{- | Open Graph and JSON-LD metadata for posts, the home page, standalone pages,
group indexes, and author pages.

The keys themselves are documented in "Cozyll.Metadata"; this module defines how
they are emitted.

  [@shareTitle@ / @shareDescription@] override the social title and description,
      which otherwise fall back to @title@ and @description@.
  [@#main-image@] on an image (@![alt](src){#main-image}@) marks it as the Open
      Graph and JSON-LD image, and its URL is resolved to an absolute one. It is
      a Pandoc image attribute, not a @Cozyll.Metadata.Key@; 'mainImageOf'
      resolves it.
  [@schemaType@] selects a standalone page's schema.org type (see
      "Cozyll.Metadata" for the allowed values). It is ignored on posts (always
      @BlogPosting@) and overridden on pages marked @home: true@ (always
      @WebSite@) or @index: true@ (always @CollectionPage@).

The JSON-LD is a schema.org @\@graph@ with stable @\@id@s: the home page carries
the @WebSite@ entity (@#website@), the site's @Organization@ (@#organization@),
and the site-default author; posts are @BlogPosting@ nodes (@<page>#article@)
whose @author@ entries are the post's authors, credited by profile URL;
standalone pages are the page's @schemaType@, linked to the site via
@isPartOf@. Group index pages are @CollectionPage@ nodes whose @mainEntity@ is
an @ItemList@ mirroring the visible list (the showcase has no @ItemList@).
Author pages are @ProfilePage@ nodes with the author's entity as @mainEntity@
and @hasPart@ listing their posts (when the author has any). Author entities
live at @https://<domain>/authors/<id>#person@ (@#organization@ for
organizations). Articles also emit @article:author@ and their published and
modified timestamps, and an opted-in post carries @copyrightNotice@ and
@copyrightHolder@.
-}
module Cozyll.Context.SocialMeta (
    PageKind (..),
    MainImage (..),
    PageMeta (..),
    PageItem (..),
    pageMetaOf,
    pageItemOf,
    mainImageOf,
    socialMetaContext,
    jsonLD,
    pageUrl,
    absoluteUrl,
    absoluteImageUrl,
    isoDate,
    ogType,
    titleOf,
    descriptionOf,
    pageKindOf,
) where

import Control.Applicative ((<|>))
import Cozyll.Config (SiteConfig, baseUrl, siteAlternateNames, siteDefaultAuthor, siteDescription, siteLogo, siteTitle)
import Cozyll.Domain.Author (Author (..), AuthorType (..), authorName, authorSchemaType, authorUrlPath)
import Cozyll.Domain.Language qualified as L
import Cozyll.Format (yearRange)
import Cozyll.JsonLd qualified as JsonLd
import Cozyll.Metadata (Key (..), lookupKey)
import Cozyll.Yaml (Check (runCheck))
import Data.Aeson (ToJSON, object, (.=))
import Data.Aeson.Encoding (Series)
import Data.Aeson.Key qualified as AesonKey
import Data.Char (toLower)
import Data.List (intercalate, isPrefixOf)
import Data.Maybe (fromMaybe)
import Data.Text qualified as T
import Hakyll (Compiler, Context, Item (..), Metadata, constField, getMetadata, itemIdentifier)
import Text.Pandoc (Block (Figure), Inline (Image), Pandoc)
import Text.Pandoc.Shared (stringify)
import Text.Pandoc.Walk (query)
import Text.Read (readMaybe)

-- | What kind of page the social metadata describes
data PageKind = Article | WebSite | WebPage | ProfilePage | CollectionPage | AboutPage | ContactPage
    deriving (Eq, Show)

-- | The image a page designates as its main (social) image
data MainImage = MainImage
    { src :: FilePath
    , alt :: String
    }
    deriving (Eq, Show)

-- | The metadata the social tags and structured data are built from
data PageMeta = PageMeta
    { pageMetaTitle :: String
    , pageMetaDescription :: Maybe String
    , pageMetaUrl :: String
    -- ^ Absolute
    , pageMetaLanguage :: String
    -- ^ @en@, @es@, or @ja@
    , pageMetaPublished :: Maybe String
    -- ^ @YYYY-MM-DD@
    , pageMetaModified :: Maybe String
    -- ^ @YYYY-MM-DD@
    }
    deriving (Eq, Show)

-- | A page listed by a collection (its public URL, title, and publication date)
data PageItem = PageItem
    { pageItemUrl :: String
    -- ^ Absolute
    , pageItemName :: String
    , pageItemPublished :: Maybe String
    -- ^ @YYYY-MM-DD@
    }
    deriving (Eq, Show)

-- | The list fields of an item: its public URL, title, and publication date
pageItemOf :: SiteConfig -> Item String -> Compiler PageItem
pageItemOf cfg item = do
    metadata <- getMetadata (itemIdentifier item)
    pure
        PageItem
            { pageItemUrl = maybe "" (absoluteUrl cfg) (lookupKey Path metadata)
            , pageItemName = fromMaybe "" (lookupKey Title metadata)
            , pageItemPublished = lookupKey Date metadata
            }

-- | Reads everything the social metadata needs, once, from an item's metadata
pageMetaOf :: SiteConfig -> Metadata -> PageMeta
pageMetaOf cfg metadata =
    PageMeta
        { pageMetaTitle = titleOf metadata
        , pageMetaDescription = descriptionOf metadata
        , pageMetaUrl = pageUrl cfg metadata
        , pageMetaLanguage = languageOf metadata
        , pageMetaPublished = lookupKey Date metadata
        , pageMetaModified = lookupKey LastModifiedAt metadata
        }

{- | The first image whose identifier is @main-image@ (as in
@!\[alt\](src){#main-image}@), with its alt text (falling back to its title)

Standalone images are wrapped in a Pandoc 'Figure' (which carries the
attribute), so their figures are checked as well as inline images.
-}
mainImageOf :: Pandoc -> Maybe MainImage
mainImageOf doc =
    case query imageOf doc of
        (image : _) -> Just image
        [] -> Nothing
  where
    imageOf :: Block -> [MainImage]
    imageOf (Figure (identifier, _, _) _ blocks)
        | identifier == "main-image" = take 1 $ query anyImage blocks
    imageOf block = take 1 $ query mainImage block

    anyImage :: Inline -> [MainImage]
    anyImage (Image _ inlines target) = toMainImage inlines target
    anyImage _ = []

    mainImage :: Inline -> [MainImage]
    mainImage (Image (identifier, _, _) inlines target)
        | identifier == "main-image" = toMainImage inlines target
    mainImage _ = []

    toMainImage inlines (target, title)
        | T.null target = []
        | otherwise = [MainImage{src = T.unpack target, alt = altOf (stringify inlines) title}]

    altOf caption title
        | T.null caption = T.unpack title
        | otherwise = T.unpack caption

-- | Fields @opengraph@ and @jsonld@ describing a page, from metadata the caller has already read
socialMetaContext :: SiteConfig -> PageKind -> [Author] -> [PageItem] -> PageMeta -> Maybe MainImage -> String -> Context String
socialMetaContext cfg kind authors items pageMeta mainImage ogLocale =
    constField "opengraph" (openGraph cfg kind authors pageMeta mainImage ogLocale)
        <> constField "jsonld" (jsonLD cfg kind authors items pageMeta mainImage)

-- | The absolute URL of an item: its @path:@, or else the site root
pageUrl :: SiteConfig -> Metadata -> String
pageUrl cfg metadata = maybe (baseUrl cfg ++ "/") (absoluteUrl cfg) (lookupKey Path metadata)

-- | Joins the site origin and a path with exactly one slash
absoluteUrl :: SiteConfig -> String -> String
absoluteUrl cfg path
    | null path || all (== '/') path = baseUrl cfg ++ "/"
    | otherwise = baseUrl cfg ++ "/" ++ dropWhile (== '/') path

-- | Absolute URL for an image: external URLs and data URIs are kept as-is
absoluteImageUrl :: SiteConfig -> FilePath -> String
absoluteImageUrl cfg image
    | "//" `isPrefixOf` image = image
    | any (`isPrefixOf` lowered) ["http://", "https://", "data:"] = image
    | otherwise = absoluteUrl cfg image
  where
    lowered = map toLower image

-- | The Open Graph tags for a page, one per line
openGraph :: SiteConfig -> PageKind -> [Author] -> PageMeta -> Maybe MainImage -> String -> String
openGraph cfg kind authors pageMeta mainImage ogLocale =
    intercalate "\n" $
        [ meta "og:type" (ogType kind)
        , meta "og:url" (pageMetaUrl pageMeta)
        , meta "og:title" (pageMetaTitle pageMeta)
        ]
            <> maybe [] (\description -> [meta "og:description" description]) (pageMetaDescription pageMeta)
            <> [ meta "og:site_name" (siteTitle cfg)
               , meta "og:locale" ogLocale
               ]
            <> articleTags
            <> maybe [] imageTags mainImage
  where
    meta property content =
        "<meta property=\"" ++ property ++ "\" content=\"" ++ escapeAttr content ++ "\" />"

    -- \| Articles credit each of their authors by profile URL and carry their dates
    articleTags = case kind of
        Article ->
            [meta "article:author" (absoluteUrl cfg (authorUrlPath author)) | author <- authors]
                <> maybeList (fmap isoDate (pageMetaPublished pageMeta)) (meta "article:published_time")
                <> maybeList (fmap isoDate (pageMetaModified pageMeta <|> pageMetaPublished pageMeta)) (meta "article:modified_time")
        _ -> []

    maybeList (Just value) tag = [tag value]
    maybeList Nothing _ = []

    imageTags image =
        meta "og:image" (absoluteImageUrl cfg (src image))
            : [meta "og:image:alt" (alt image) | not (null (alt image))]

-- | Escapes text for use in an HTML attribute
escapeAttr :: String -> String
escapeAttr = concatMap escapeChar
  where
    escapeChar '&' = "&amp;"
    escapeChar '<' = "&lt;"
    escapeChar '>' = "&gt;"
    escapeChar '"' = "&quot;"
    escapeChar character = [character]

-- | The @og:type@ of a page: per ogp.me, @article@ for posts and @website@ for every other page
ogType :: PageKind -> String
ogType Article = "article"
ogType _ = "website"

-- | The page kind declared by @schemaType:@ (default @WebPage@), or the unknown value
pageKindOf :: Metadata -> Either String PageKind
pageKindOf metadata = case lookupKey SchemaType metadata of
    Nothing -> Right WebPage
    Just value -> maybe (Left value) Right (lookup value kinds)
  where
    kinds =
        [ ("WebPage", WebPage)
        , ("AboutPage", AboutPage)
        , ("ContactPage", ContactPage)
        , ("CollectionPage", CollectionPage)
        , ("ProfilePage", ProfilePage)
        ]

-- | The JSON-LD script tag for a page
jsonLD :: SiteConfig -> PageKind -> [Author] -> [PageItem] -> PageMeta -> Maybe MainImage -> String
jsonLD cfg kind authors items pageMeta mainImage =
    "<script type=\"application/ld+json\">" ++ JsonLd.render (JsonLd.graph (jsonNodes cfg kind authors items pageMeta mainImage)) ++ "</script>"

-- | The JSON-LD nodes of a page's @\@graph@
jsonNodes :: SiteConfig -> PageKind -> [Author] -> [PageItem] -> PageMeta -> Maybe MainImage -> [JsonLd.Node]
jsonNodes cfg kind authors items pageMeta mainImage = case kind of
    Article -> [articleNode]
    WebSite -> [websiteNode, organizationNode, defaultAuthorNode]
    WebPage -> [pageNode "WebPage"]
    ProfilePage -> pageNode "ProfilePage" <> profileData : map authorEntityNode authors
    CollectionPage -> [pageNode "CollectionPage" <> collectionData]
    AboutPage -> [pageNode "AboutPage"]
    ContactPage -> [pageNode "ContactPage"]
  where
    defaultAuthor = siteDefaultAuthor cfg

    articleNode =
        "@type" .= ("BlogPosting" :: String)
            <> "@id" .= JsonLd.articleId (pageMetaUrl pageMeta)
            <> "headline" .= pageMetaTitle pageMeta
            <> optionalField "description" (pageMetaDescription pageMeta)
            <> "url" .= pageMetaUrl pageMeta
            <> "mainEntityOfPage" .= object ["@type" .= ("WebPage" :: String), "@id" .= pageMetaUrl pageMeta]
            <> "datePublished" .= published
            <> "dateModified" .= modified
            <> "author" .= map authorNode authors
            <> "publisher" .= publisher
            <> imageSeries
            <> "inLanguage" .= pageMetaLanguage pageMeta
            <> copyrightSeries

    websiteNode =
        "@type" .= ("WebSite" :: String)
            <> "@id" .= JsonLd.websiteId (origin cfg)
            <> "url" .= origin cfg
            <> "name" .= siteTitle cfg
            <> optionalField "alternateName" (nonEmptyList (siteAlternateNames cfg))
            <> "description" .= siteDescription cfg
            <> "inLanguage" .= pageMetaLanguage pageMeta
            <> "publisher" .= JsonLd.idRef (JsonLd.organizationId (origin cfg))
            <> "mainEntity" .= JsonLd.idRef (entityId cfg defaultAuthor)

    organizationNode =
        "@type" .= ("Organization" :: String)
            <> "@id" .= JsonLd.organizationId (origin cfg)
            <> "name" .= siteTitle cfg
            <> "url" .= origin cfg
            <> optionalField "logo" (absoluteImageUrl cfg <$> siteLogo cfg)

    defaultAuthorNode = authorEntityNode defaultAuthor

    authorEntityNode author =
        "@type" .= authorSchemaType (authorType author)
            <> "@id" .= entityId cfg author
            <> "name" .= authorName author
            <> "url" .= absoluteUrl cfg (authorUrlPath author)
            <> optionalField "description" (authorDescription author)
            <> optionalField (entityImageField author) (absoluteImageUrl cfg <$> authorProfileImage author)
            <> optionalField "sameAs" (nonEmptyList (authorLinks author))

    pageNode name =
        "@type" .= (name :: String)
            <> "@id" .= pageMetaUrl pageMeta
            <> "url" .= pageMetaUrl pageMeta
            <> "name" .= pageMetaTitle pageMeta
            <> optionalField "description" (pageMetaDescription pageMeta)
            <> "inLanguage" .= pageMetaLanguage pageMeta
            <> "isPartOf" .= websiteStub
            <> imageSeries

    -- \| The @mainEntity@ of a profile page (its person/organization) and the posts it lists
    profileData = case authors of
        (author : _) -> "mainEntity" .= JsonLd.idRef (entityId cfg author) <> hasPartSeries
        [] -> mempty

    hasPartSeries
        | null items = mempty
        | otherwise = "hasPart" .= map hasPartNode items

    hasPartNode item =
        object $
            [ "@type" .= ("BlogPosting" :: String)
            , "@id" .= JsonLd.articleId (pageItemUrl item)
            , "url" .= pageItemUrl item
            , "name" .= pageItemName item
            ]
                ++ maybe [] ((\date -> ["datePublished" .= isoDate date])) (pageItemPublished item)

    -- \| The @mainEntity@ of a collection page: an @ItemList@ of its items, when it has any
    collectionData
        | null items = mempty
        | otherwise =
            "mainEntity"
                .= object
                    [ "@type" .= ("ItemList" :: String)
                    , "numberOfItems" .= length items
                    , "itemListElement" .= zipWith elementNode [1 :: Int ..] items
                    ]

    elementNode position item =
        object
            [ "@type" .= ("ListItem" :: String)
            , "position" .= position
            , "url" .= pageItemUrl item
            ]

    websiteStub =
        object
            [ "@type" .= ("WebSite" :: String)
            , "@id" .= JsonLd.websiteId (origin cfg)
            , "name" .= siteTitle cfg
            , "url" .= origin cfg
            ]

    authorNode author =
        object
            [ "@type" .= authorSchemaType (authorType author)
            , "@id" .= entityId cfg author
            , "name" .= authorName author
            , "url" .= absoluteUrl cfg (authorUrlPath author)
            ]

    publisher =
        object $
            [ "@type" .= ("Organization" :: String)
            , "@id" .= JsonLd.organizationId (origin cfg)
            , "name" .= siteTitle cfg
            ]
                ++ maybe [] ((\logo -> ["logo" .= logo]) . absoluteImageUrl cfg) (siteLogo cfg)

    -- \| The copyright fields, only when one of the post's authors opted in
    copyrightSeries
        | null holders = mempty
        | otherwise =
            optionalField "copyrightNotice" notice
                <> "copyrightHolder" .= map authorNode holders
      where
        holders = filter authorAddCopyrightNotice authors
        notice = case copyrightSpan of
            "" -> Nothing
            span' -> Just ("© " ++ intercalate ", " (map authorName holders) ++ " " ++ span')

    -- \| The years the notice covers: @date@ to @lastModifiedAt@, collapsing when equal
    copyrightSpan = case (yearOf =<< pageMetaPublished pageMeta, yearOf =<< pageMetaModified pageMeta) of
        (Just first, Just lastModified) -> yearRange first lastModified
        (Just first, Nothing) -> show first
        (Nothing, _) -> ""

    nonEmptyList [] = Nothing
    nonEmptyList values = Just values

    imageSeries = optionalField "image" (absoluteImageUrl cfg . src <$> mainImage)

    published = maybe "" isoDate (pageMetaPublished pageMeta)
    modified = maybe published isoDate (pageMetaModified pageMeta)

-- | The site origin with a trailing slash, as the JSON-LD identifiers expect
origin :: SiteConfig -> String
origin cfg = baseUrl cfg ++ "/"

-- | The @\@id@ of an author's entity, by their type
entityId :: SiteConfig -> Author -> String
entityId cfg author = origin cfg ++ "authors/" ++ authorId author ++ "#" ++ fragment
  where
    fragment = case authorType author of
        Person -> "person"
        Organization -> "organization"

-- | @image@ for a person, @logo@ for an organization
entityImageField :: Author -> AesonKey.Key
entityImageField author = case authorType author of
    Person -> "image"
    Organization -> "logo"

-- | The year of a @YYYY-MM-DD@ value
yearOf :: String -> Maybe Int
yearOf = readMaybe . take 4

-- | Appends a time to a date-only @YYYY-MM-DD@ value
isoDate :: String -> String
isoDate value
    | length value == 10 = value ++ "T00:00:00"
    | otherwise = value

-- | Adds a JSON object field only when it has a value
optionalField :: (ToJSON value) => AesonKey.Key -> Maybe value -> Series
optionalField _ Nothing = mempty
optionalField key (Just value) = key .= value

-- | The page's social title: @shareTitle@ if set, else its title
titleOf :: Metadata -> String
titleOf metadata =
    fromMaybe "" $
        firstJust [nonEmpty (lookupKey ShareTitle metadata), nonEmpty (lookupKey Title metadata)]

-- | The page's social description: @shareDescription@ if set, else its description
descriptionOf :: Metadata -> Maybe String
descriptionOf metadata =
    firstJust [nonEmpty (lookupKey ShareDescription metadata), nonEmpty (lookupKey Description metadata)]

-- | Treats an empty string as absent
nonEmpty :: Maybe String -> Maybe String
nonEmpty (Just "") = Nothing
nonEmpty value = value

-- | The item's normalized language code (English by default)
languageOf :: Metadata -> String
languageOf metadata = case runCheck (L.languageOf metadata) of
    Right lang -> L.languageCode lang
    Left _ -> "en"

-- | The first 'Just' value in a list
firstJust :: [Maybe a] -> Maybe a
firstJust values = case [value | Just value <- values] of
    (value : _) -> Just value
    [] -> Nothing
