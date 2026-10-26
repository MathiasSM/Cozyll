{-# LANGUAGE OverloadedStrings #-}

-- | Open Graph and JSON-LD metadata for posts, the home page, and standalone pages
module Cozyll.Context.SocialMeta (
    SocialKind (..),
    MainImage (..),
    mainImageOf,
    socialMetaContext,
    absoluteUrl,
    absoluteImageUrl,
    isoDate,
    localeOf,
    ogType,
    titleOf,
    descriptionOf,
) where

import Cozyll.Config (SiteConfig, baseUrl, siteAuthor, siteDescription, siteName)
import Cozyll.Metadata (Key (..), lookupKey)
import Data.Aeson (ToJSON, object, pairs, (.=))
import Data.Aeson.Encoding (Series, encodingToLazyByteString)
import Data.Aeson.Key qualified as AesonKey
import Data.Char (toLower)
import Data.List (intercalate, isPrefixOf)
import Data.Maybe (fromMaybe)
import Data.Text qualified as T
import Data.Text.Lazy qualified as LT
import Data.Text.Lazy.Encoding qualified as LTE
import Hakyll (
    Context,
    Item (itemIdentifier),
    Metadata,
    field,
    getMetadata,
 )
import Text.Pandoc (Block (Figure), Inline (Image), Pandoc)
import Text.Pandoc.Shared (stringify)
import Text.Pandoc.Walk (query)

-- | What kind of page the social metadata describes
data SocialKind = Article | WebSite | WebPage

-- | The image a page designates as its main (social) image
data MainImage = MainImage
    { src :: FilePath
    , alt :: String
    }
    deriving (Eq, Show)

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

{- | Fields @opengraph@ and @jsonld@ describing a page, reading its metadata
on its own (so composition order does not matter)
-}
socialMetaContext :: SiteConfig -> SocialKind -> Maybe MainImage -> Context String
socialMetaContext cfg kind mainImage =
    field "opengraph" (render (openGraph cfg kind mainImage))
        <> field "jsonld" (render (jsonLD cfg kind mainImage))
  where
    render make item = do
        metadata <- getMetadata (itemIdentifier item)
        pure $ make metadata (pageUrl cfg metadata)

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
openGraph :: SiteConfig -> SocialKind -> Maybe MainImage -> Metadata -> String -> String
openGraph cfg kind mainImage metadata url =
    intercalate "\n" $
        [ meta "og:type" (ogType kind)
        , meta "og:url" url
        , meta "og:title" (titleOf metadata)
        ]
            <> maybe [] (\description -> [meta "og:description" description]) (descriptionOf metadata)
            <> [ meta "og:site_name" (siteName cfg)
               , meta "og:locale" (localeOf (languageOf metadata))
               ]
            <> maybe [] imageTags mainImage
  where
    meta property content =
        "<meta property=\"" ++ property ++ "\" content=\"" ++ escapeAttr content ++ "\" />"

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

-- | The @og:type@ of a page: per ogp.me, @article@ for posts and @website@ for home and standalone pages
ogType :: SocialKind -> String
ogType Article = "article"
ogType WebSite = "website"
ogType WebPage = "website"

-- | The JSON-LD script tag for a page
jsonLD :: SiteConfig -> SocialKind -> Maybe MainImage -> Metadata -> String -> String
jsonLD cfg kind mainImage metadata url =
    "<script type=\"application/ld+json\">" ++ escapeJson (encode (jsonObject cfg kind mainImage metadata url)) ++ "</script>"
  where
    encode = LT.unpack . LTE.decodeUtf8 . encodingToLazyByteString . pairs

    escapeJson = concatMap escapeJsonChar

    escapeJsonChar '<' = "\\u003c"
    escapeJsonChar '>' = "\\u003e"
    escapeJsonChar '&' = "\\u0026"
    escapeJsonChar character = [character]

-- | The JSON-LD object for a page
jsonObject :: SiteConfig -> SocialKind -> Maybe MainImage -> Metadata -> String -> Series
jsonObject cfg kind mainImage metadata url = case kind of
    Article ->
        context
            <> "@type" .= ("Article" :: String)
            <> "headline" .= titleOf metadata
            <> optionalField "description" (descriptionOf metadata)
            <> "mainEntityOfPage" .= object ["@type" .= ("WebPage" :: String), "@id" .= url]
            <> "datePublished" .= published
            <> "dateModified" .= modified
            <> "author" .= person
            <> "publisher" .= organization
            <> "inLanguage" .= languageOf metadata
            <> imageSeries
    WebSite ->
        context
            <> "@type" .= ("WebSite" :: String)
            <> "name" .= siteName cfg
            <> "description" .= siteDescription cfg
            <> "url" .= (baseUrl cfg ++ "/")
            <> "author" .= person
            <> "inLanguage" .= languageOf metadata
            <> imageSeries
    WebPage ->
        context
            <> "@type" .= ("WebPage" :: String)
            <> "name" .= titleOf metadata
            <> optionalField "description" (descriptionOf metadata)
            <> "url" .= url
            <> "inLanguage" .= languageOf metadata
            <> imageSeries
  where
    context = "@context" .= ("https://schema.org" :: String)
    person = object ["@type" .= ("Person" :: String), "name" .= siteAuthor cfg]
    organization = object ["@type" .= ("Organization" :: String), "name" .= siteName cfg]

    imageSeries = optionalField "image" (absoluteImageUrl cfg . src <$> mainImage)

    published = maybe "" isoDate (lookupKey Date metadata)
    modified = maybe published isoDate (lookupKey LastModifiedAt metadata)

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

-- | The item's language code (English by default)
languageOf :: Metadata -> String
languageOf metadata = fromMaybe "en" (lookupKey Language metadata)

-- | The Open Graph locale for a language code
localeOf :: String -> String
localeOf "es" = "es_ES"
localeOf "ja" = "ja_JP"
localeOf _ = "en_US"

-- | The first 'Just' value in a list
firstJust :: [Maybe a] -> Maybe a
firstJust values = case [value | Just value <- values] of
    (value : _) -> Just value
    [] -> Nothing
