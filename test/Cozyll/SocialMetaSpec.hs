-- | Tests for the social-meta helpers: main-image detection, page metadata, URLs, dates, locales, and titles
module Cozyll.SocialMetaSpec (tests) where

import Cozyll.Context.SocialMeta (
    MainImage (..),
    PageItem (..),
    PageKind (..),
    PageMeta (..),
    absoluteImageUrl,
    absoluteUrl,
    descriptionOf,
    isoDate,
    jsonLD,
    mainImageOf,
    ogType,
    pageKindOf,
    pageMetaOf,
    titleOf,
 )
import Cozyll.Domain.Author (Author (..))
import Cozyll.Domain.Website qualified as Web
import Cozyll.TestUtils (assertContains, assertNotContains, metadata, mkAuthor, testConfig)
import Cozyll.Yaml (decodeYaml)
import Data.Text (Text)
import Hakyll (defaultHakyllReaderOptions)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertFailure, testCase, (@?=))
import Text.Pandoc (Pandoc, readMarkdown, runPure)

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
        , ogTypeTests
        , titleOfTests
        , descriptionOfTests
        , pageKindOfTests
        , jsonLdTests
        , siteParsingTests
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
                testConfig
                ( metadata
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
            pageMetaOf testConfig (metadata [("title", "T")])
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
            absoluteUrl testConfig "/" @?= "https://example.com/"
        , testCase "adds a slash to a relative path" $
            absoluteUrl testConfig "foo" @?= "https://example.com/foo"
        , testCase "does not double a leading slash" $
            absoluteUrl testConfig "/foo" @?= "https://example.com/foo"
        , testCase "maps an empty path to the site root" $
            absoluteUrl testConfig "" @?= "https://example.com/"
        , testCase "collapses leading double slashes" $
            absoluteUrl testConfig "//foo" @?= "https://example.com/foo"
        ]

absoluteImageUrlTests :: TestTree
absoluteImageUrlTests =
    testGroup
        "absoluteImageUrl"
        [ testCase "makes a relative image path absolute" $
            absoluteImageUrl testConfig "images/a.png" @?= "https://example.com/images/a.png"
        , testCase "keeps an http URL" $
            absoluteImageUrl testConfig "http://x/y.png" @?= "http://x/y.png"
        , testCase "keeps an https URL" $
            absoluteImageUrl testConfig "https://x/y.png" @?= "https://x/y.png"
        , testCase "keeps an uppercase HTTPS URL" $
            absoluteImageUrl testConfig "HTTPS://x/y.png" @?= "HTTPS://x/y.png"
        , testCase "keeps a protocol-relative URL" $
            absoluteImageUrl testConfig "//cdn/x.png" @?= "//cdn/x.png"
        , testCase "keeps a data URI" $
            absoluteImageUrl testConfig "data:image/png;base64,AAAA" @?= "data:image/png;base64,AAAA"
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

ogTypeTests :: TestTree
ogTypeTests =
    testGroup
        "ogType"
        [ testCase "articles are article" $ ogType Article @?= "article"
        , testCase "sites are website" $ ogType WebSite @?= "website"
        , testCase "pages are website" $ ogType WebPage @?= "website"
        , testCase "profile pages are website" $ ogType ProfilePage @?= "website"
        , testCase "collection pages are website" $ ogType CollectionPage @?= "website"
        ]

titleOfTests :: TestTree
titleOfTests =
    testGroup
        "titleOf"
        [ testCase "uses the title" $
            titleOf (metadata [("title", "T")]) @?= "T"
        , testCase "prefers shareTitle" $
            titleOf (metadata [("shareTitle", "S"), ("title", "T")]) @?= "S"
        , testCase "falls back to the title when shareTitle is empty" $
            titleOf (metadata [("shareTitle", ""), ("title", "T")]) @?= "T"
        ]

descriptionOfTests :: TestTree
descriptionOfTests =
    testGroup
        "descriptionOf"
        [ testCase "uses the description" $
            descriptionOf (metadata [("description", "D")]) @?= Just "D"
        , testCase "prefers shareDescription" $
            descriptionOf (metadata [("shareDescription", "SD"), ("description", "D")]) @?= Just "SD"
        , testCase "is Nothing without a description" $
            descriptionOf (metadata []) @?= Nothing
        , testCase "falls back to the description when shareDescription is empty" $
            descriptionOf (metadata [("shareDescription", ""), ("description", "D")]) @?= Just "D"
        , testCase "treats an empty description as absent" $
            descriptionOf (metadata [("description", "")]) @?= Nothing
        ]

siteParsingTests :: TestTree
siteParsingTests =
    testGroup
        "Site FromJSON"
        [ testCase "parses alternateName and logo" $
            case decodeYaml siteWithExtras of
                Left problems -> assertFailure (unlines problems)
                Right site -> do
                    Web.siteAlternateNames site @?= ["Ex", "example.com"]
                    Web.siteLogo site @?= Just "images/logo.png"
        , testCase "defaults alternateName and logo when absent" $
            case decodeYaml siteMinimal of
                Left problems -> assertFailure (unlines problems)
                Right site -> do
                    Web.siteAlternateNames site @?= []
                    Web.siteLogo site @?= Nothing
        ]
  where
    siteWithExtras =
        unlines
            [ "title: Example"
            , "description: An example site"
            , "copyrightYear: 2020"
            , "domain: example.com"
            , "alternateName: [Ex, example.com]"
            , "logo: images/logo.png"
            ]
    siteMinimal =
        unlines
            [ "title: Example"
            , "description: An example site"
            , "copyrightYear: 2020"
            , "domain: example.com"
            ]

pageKindOfTests :: TestTree
pageKindOfTests =
    testGroup
        "pageKindOf"
        [ testCase "defaults to WebPage" $ pageKindOf (metadata []) @?= Right WebPage
        , testCase "accepts a whitelisted schemaType" $
            pageKindOf (metadata [("schemaType", "AboutPage")]) @?= Right AboutPage
        , testCase "accepts ProfilePage" $
            pageKindOf (metadata [("schemaType", "ProfilePage")]) @?= Right ProfilePage
        , testCase "rejects an unknown schemaType" $
            pageKindOf (metadata [("schemaType", "Blog")]) @?= Left "Blog"
        ]

jsonLdTests :: TestTree
jsonLdTests =
    testGroup
        "jsonLD"
        [ testCase "wraps every page in a @context + @graph document" $
            assertContains "{\"@context\":\"https://schema.org\",\"@graph\":[" (jsonLD testConfig WebPage [] [] pageMeta Nothing)
        , testCase "home has WebSite, Organization, and the default author" $ do
            let json = jsonLD testConfig WebSite [] [] homeMeta Nothing
            assertContains "\"@type\":\"WebSite\",\"@id\":\"https://example.com/#website\"" json
            assertContains "\"publisher\":{\"@id\":\"https://example.com/#organization\"}" json
            assertContains "\"mainEntity\":{\"@id\":\"https://example.com/authors/example#person\"}" json
            assertContains "\"@type\":\"Organization\",\"@id\":\"https://example.com/#organization\"" json
            assertContains "\"@type\":\"Person\",\"@id\":\"https://example.com/authors/example#person\"" json
        , testCase "posts are BlogPosting with author, publisher, and url" $ do
            let json = jsonLD testConfig Article [exampleAuthor] [] postMeta (Just (MainImage "images/a.png" "alt"))
            assertContains "\"@type\":\"BlogPosting\",\"@id\":\"https://example.com/prose/tour#article\"" json
            assertContains "\"mainEntityOfPage\":{\"@id\":\"https://example.com/prose/tour\"" json
            assertContains "\"author\":[{\"@id\":\"https://example.com/authors/example#person\",\"@type\":\"Person\"" json
            assertContains "\"url\":\"https://example.com/authors/example\"" json
            assertContains "\"publisher\":{\"@id\":\"https://example.com/#organization\",\"@type\":\"Organization\",\"name\":\"site\"}" json
            assertContains "\"image\":\"https://example.com/images/a.png\"" json
        , testCase "posts carry the copyright only when an author opted in" $ do
            let optedIn = jsonLD testConfig Article [exampleAuthor] [] postMeta Nothing
                optedOut = jsonLD testConfig Article [exampleAuthor{authorAddCopyrightNotice = False}] [] postMeta Nothing
            assertContains "\"copyrightNotice\":\"© Example Author 2024–2026\"" optedIn
            assertContains "\"copyrightHolder\":[{\"@id\":\"https://example.com/authors/example#person\"" optedIn
            assertNotContains "copyrightNotice" optedOut
        , testCase "standalone pages are a WebPage inside the site" $ do
            let json = jsonLD testConfig AboutPage [] [] pageMeta Nothing
            assertContains "\"@type\":\"AboutPage\",\"@id\":\"https://example.com/about\"" json
            assertContains "\"isPartOf\":{\"@id\":\"https://example.com/#website\",\"@type\":\"WebSite\"" json
        , testCase "profile pages link their author and list their posts" $ do
            let items =
                    [ PageItem "https://example.com/prose/tour" "A tour" (Just "2024-02-20")
                    , PageItem "https://example.com/prose/lists" "Lists" (Just "2024-01-20")
                    ]
                json = jsonLD testConfig ProfilePage [exampleAuthor] items (pageMeta{pageMetaUrl = "https://example.com/authors/example"}) Nothing
            assertContains "\"@type\":\"ProfilePage\",\"@id\":\"https://example.com/authors/example\"" json
            assertContains "\"mainEntity\":{\"@id\":\"https://example.com/authors/example#person\"}" json
            assertContains "\"hasPart\":[{\"@id\":\"https://example.com/prose/tour#article\",\"@type\":\"BlogPosting\"" json
            assertContains "\"name\":\"A tour\",\"url\":\"https://example.com/prose/tour\"" json
            assertContains "\"datePublished\":\"2024-02-20T00:00:00\"" json
        , testCase "collection pages emit an ItemList in list order" $ do
            let items =
                    [ PageItem "https://example.com/prose/tour" "" Nothing
                    , PageItem "https://example.com/prose/lists" "" Nothing
                    ]
                json = jsonLD testConfig CollectionPage [] items (pageMeta{pageMetaUrl = "https://example.com/prose"}) Nothing
            assertContains "\"@type\":\"CollectionPage\"" json
            assertContains "\"@type\":\"ItemList\"" json
            assertContains "\"numberOfItems\":2" json
            assertContains "\"position\":1,\"url\":\"https://example.com/prose/tour\"" json
            assertContains "\"position\":2,\"url\":\"https://example.com/prose/lists\"" json
        , testCase "an empty collection has no ItemList" $ do
            let json = jsonLD testConfig CollectionPage [] [] (pageMeta{pageMetaUrl = "https://example.com/showcase"}) Nothing
            assertContains "\"@type\":\"CollectionPage\"" json
            assertNotContains "ItemList" json
        ]

-- | A page's metadata, as the tests build it
pageMeta :: PageMeta
pageMeta =
    PageMeta
        { pageMetaTitle = "T"
        , pageMetaDescription = Just "D"
        , pageMetaUrl = "https://example.com/about"
        , pageMetaLanguage = "en"
        , pageMetaPublished = Just "2024-02-20"
        , pageMetaModified = Just "2026-03-01"
        }

-- | A post's metadata
postMeta :: PageMeta
postMeta = pageMeta{pageMetaTitle = "A post", pageMetaUrl = "https://example.com/prose/tour"}

-- | The home page's metadata
homeMeta :: PageMeta
homeMeta = pageMeta{pageMetaTitle = "site", pageMetaUrl = "https://example.com/"}

-- | An author with every optional field set
exampleAuthor :: Author
exampleAuthor =
    (mkAuthor "Example Author")
        { authorDescription = Just "Bio"
        , authorProfileImage = Just "images/a.png"
        , authorLinks = ["https://example.com"]
        , authorAddCopyrightNotice = True
        }
