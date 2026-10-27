-- | Tests for the social-meta helpers: main-image detection, page metadata, URLs, dates, locales, and titles
module Cozyll.SocialMetaSpec (tests) where

import Cozyll.Config (Env (Dev), SiteConfig (..))
import Cozyll.Context.SocialMeta (
    MainImage (..),
    PageMeta (..),
    SocialKind (..),
    absoluteImageUrl,
    absoluteUrl,
    descriptionOf,
    isoDate,
    localeOf,
    mainImageOf,
    ogType,
    pageMetaOf,
    titleOf,
 )
import Cozyll.Domain.Website (HighlightStyle (Pygments))
import Data.Aeson (Value (String))
import Data.Aeson.Key qualified as AesonKey
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Text (Text)
import Hakyll (Metadata, defaultHakyllReaderOptions)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Text.Pandoc (Pandoc, readMarkdown, runPure)

-- | Front matter with string values, as Hakyll stores it
metadataOf :: [(Text, Text)] -> Metadata
metadataOf = KeyMap.fromList . map (\(key, value) -> (AesonKey.fromText key, String value))

-- | A 'SiteConfig' with only the fields the URL helpers read; the rest are dummies
mkConfig :: SiteConfig
mkConfig =
    SiteConfig
        { siteName = "site"
        , siteDescription = ""
        , siteAuthor = ""
        , siteCopyrightYear = 0
        , siteDomain = "example.com"
        , mathjaxVersion = ""
        , highlightStyle = Pygments
        , contentDir = "content"
        , assetsDir = "assets"
        , templatesDir = "templates"
        , contentTemplatesDir = "content/templates"
        , contentCssDir = "content/css"
        , contentTemplateNames = []
        , siteEnv = Dev
        }

-- | Parses Markdown the way the site does
markdown :: Text -> Pandoc
markdown source =
    either (error . show) id $
        runPure (readMarkdown defaultHakyllReaderOptions source)

tests :: TestTree
tests =
    testGroup
        "SocialMeta"
        [ mainImageOfTests
        , pageMetaOfTests
        , absoluteUrlTests
        , absoluteImageUrlTests
        , isoDateTests
        , localeOfTests
        , ogTypeTests
        , titleOfTests
        , descriptionOfTests
        ]

mainImageOfTests :: TestTree
mainImageOfTests =
    testGroup
        "mainImageOf"
        [ testCase "finds an inline image marked #main-image" $
            mainImageOf (markdown "text ![alt](img.png){#main-image} text")
                @?= Just (MainImage "img.png" "alt")
        , testCase "finds a standalone image marked #main-image" $
            mainImageOf (markdown "![alt](img.png){#main-image}")
                @?= Just (MainImage "img.png" "alt")
        , testCase "returns Nothing without a #main-image" $
            mainImageOf (markdown "![alt](img.png)") @?= Nothing
        , testCase "takes the first of several #main-image images" $
            mainImageOf (markdown "![a](a.png){#main-image}\n\n![b](b.png){#main-image}")
                @?= Just (MainImage "a.png" "a")
        , testCase "skips an image with an empty source" $
            mainImageOf (markdown "![alt](){#main-image}") @?= Nothing
        , testCase "uses the title as alt when there is no alt text" $
            mainImageOf (markdown "![](img.png 'Title'){#main-image}")
                @?= Just (MainImage "img.png" "Title")
        ]

pageMetaOfTests :: TestTree
pageMetaOfTests =
    testGroup
        "pageMetaOf"
        [ testCase "collects the title, description, URL, language, and dates" $
            pageMetaOf
                mkConfig
                ( metadataOf
                    [ ("title", "T")
                    , ("description", "D")
                    , ("path", "prose/tour/")
                    , ("language", "es")
                    , ("date", "2024-02-10")
                    , ("lastModifiedAt", "2024-03-01")
                    ]
                )
                @?= PageMeta
                    { pageMetaTitle = "T"
                    , pageMetaDescription = Just "D"
                    , pageMetaUrl = "https://example.com/prose/tour/"
                    , pageMetaLanguage = "es"
                    , pageMetaPublished = Just "2024-02-10"
                    , pageMetaModified = Just "2024-03-01"
                    }
        , testCase "falls back to the site root, English, and no dates" $
            pageMetaOf mkConfig (metadataOf [("title", "T")])
                @?= PageMeta
                    { pageMetaTitle = "T"
                    , pageMetaDescription = Nothing
                    , pageMetaUrl = "https://example.com/"
                    , pageMetaLanguage = "en"
                    , pageMetaPublished = Nothing
                    , pageMetaModified = Nothing
                    }
        ]

absoluteUrlTests :: TestTree
absoluteUrlTests =
    testGroup
        "absoluteUrl"
        [ testCase "keeps a root path" $
            absoluteUrl mkConfig "/" @?= "https://example.com/"
        , testCase "adds a slash to a relative path" $
            absoluteUrl mkConfig "foo" @?= "https://example.com/foo"
        , testCase "does not double a leading slash" $
            absoluteUrl mkConfig "/foo" @?= "https://example.com/foo"
        , testCase "maps an empty path to the site root" $
            absoluteUrl mkConfig "" @?= "https://example.com/"
        , testCase "collapses leading double slashes" $
            absoluteUrl mkConfig "//foo" @?= "https://example.com/foo"
        ]

absoluteImageUrlTests :: TestTree
absoluteImageUrlTests =
    testGroup
        "absoluteImageUrl"
        [ testCase "makes a relative image path absolute" $
            absoluteImageUrl mkConfig "images/a.png" @?= "https://example.com/images/a.png"
        , testCase "keeps an http URL" $
            absoluteImageUrl mkConfig "http://x/y.png" @?= "http://x/y.png"
        , testCase "keeps an https URL" $
            absoluteImageUrl mkConfig "https://x/y.png" @?= "https://x/y.png"
        , testCase "keeps an uppercase HTTPS URL" $
            absoluteImageUrl mkConfig "HTTPS://x/y.png" @?= "HTTPS://x/y.png"
        , testCase "keeps a protocol-relative URL" $
            absoluteImageUrl mkConfig "//cdn/x.png" @?= "//cdn/x.png"
        , testCase "keeps a data URI" $
            absoluteImageUrl mkConfig "data:image/png;base64,AAAA" @?= "data:image/png;base64,AAAA"
        ]

isoDateTests :: TestTree
isoDateTests =
    testGroup
        "isoDate"
        [ testCase "appends midnight to a date-only value" $
            isoDate "2024-02-10" @?= "2024-02-10T00:00:00"
        , testCase "keeps a value that already has a time" $
            isoDate "2024-02-10T12:34:56" @?= "2024-02-10T12:34:56"
        ]

localeOfTests :: TestTree
localeOfTests =
    testGroup
        "localeOf"
        [ testCase "maps en to en_US" $ localeOf "en" @?= "en_US"
        , testCase "maps es to es_ES" $ localeOf "es" @?= "es_ES"
        , testCase "maps ja to ja_JP" $ localeOf "ja" @?= "ja_JP"
        , testCase "defaults an unknown language to en_US" $ localeOf "fr" @?= "en_US"
        ]

ogTypeTests :: TestTree
ogTypeTests =
    testGroup
        "ogType"
        [ testCase "articles are article" $ ogType Article @?= "article"
        , testCase "sites are website" $ ogType WebSite @?= "website"
        , testCase "pages are website" $ ogType WebPage @?= "website"
        ]

titleOfTests :: TestTree
titleOfTests =
    testGroup
        "titleOf"
        [ testCase "uses the title" $
            titleOf (metadataOf [("title", "T")]) @?= "T"
        , testCase "prefers shareTitle" $
            titleOf (metadataOf [("shareTitle", "S"), ("title", "T")]) @?= "S"
        , testCase "falls back to the title when shareTitle is empty" $
            titleOf (metadataOf [("shareTitle", ""), ("title", "T")]) @?= "T"
        ]

descriptionOfTests :: TestTree
descriptionOfTests =
    testGroup
        "descriptionOf"
        [ testCase "uses the description" $
            descriptionOf (metadataOf [("description", "D")]) @?= Just "D"
        , testCase "prefers shareDescription" $
            descriptionOf (metadataOf [("shareDescription", "SD"), ("description", "D")]) @?= Just "SD"
        , testCase "is Nothing without a description" $
            descriptionOf (metadataOf []) @?= Nothing
        , testCase "falls back to the description when shareDescription is empty" $
            descriptionOf (metadataOf [("shareDescription", ""), ("description", "D")]) @?= Just "D"
        , testCase "treats an empty description as absent" $
            descriptionOf (metadataOf [("description", "")]) @?= Nothing
        ]
