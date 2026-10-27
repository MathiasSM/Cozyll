-- | Tests for content-theme resolution: template overrides and partial rewriting
module Cozyll.ThemeSpec (tests) where

import Cozyll.Config (Env (Dev), SiteConfig (..), resolveTemplate)
import Cozyll.Domain.Website (HighlightStyle (Pygments))
import Cozyll.TestUtils (mkAuthor)
import Cozyll.Theme (rewritePartials)
import Hakyll (toFilePath)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

-- | A 'SiteConfig' with only the fields theme resolution reads; the rest are dummies
mkConfig :: [FilePath] -> SiteConfig
mkConfig names =
    SiteConfig
        { siteTitle = "site"
        , siteDescription = ""
        , siteCopyrightYear = 0
        , siteDomain = "example.com"
        , siteAlternateNames = []
        , siteLogo = Nothing
        , siteAuthors = [mkAuthor ""]
        , siteDefaultAuthor = mkAuthor ""
        , mathjaxVersion = ""
        , highlightStyle = Pygments
        , contentDir = "content"
        , assetsDir = "assets"
        , templatesDir = "templates"
        , contentTemplatesDir = "content/templates"
        , contentCssDir = "content/css"
        , contentTemplateNames = names
        , siteEnv = Dev
        }

tests :: TestTree
tests =
    testGroup
        "Theme"
        [ resolveTemplateTests
        , rewritePartialsTests
        ]

resolveTemplateTests :: TestTree
resolveTemplateTests =
    testGroup
        "resolveTemplate"
        [ testCase "uses the vendored template when the content provides no override" $
            toFilePath (resolveTemplate (mkConfig []) "site.html") @?= "templates/site.html"
        , testCase "prefers the content template when one exists" $
            toFilePath (resolveTemplate (mkConfig ["site.html"]) "site.html") @?= "content/templates/site.html"
        , testCase "resolves each name independently" $
            toFilePath (resolveTemplate (mkConfig ["as-page.html"]) "as-post.html") @?= "templates/as-post.html"
        ]

rewritePartialsTests :: TestTree
rewritePartialsTests =
    testGroup
        "rewritePartials"
        [ testCase "rewrites an overridden partial" $
            rewritePartials (mkConfig ["site-head.html"]) "$partial(\"templates/site-head.html\")$"
                @?= "$partial(\"content/templates/site-head.html\")$"
        , testCase "leaves a non-overridden partial alone" $
            rewritePartials (mkConfig []) "$partial(\"templates/site-head.html\")$"
                @?= "$partial(\"templates/site-head.html\")$"
        , testCase "leaves content partials untouched" $
            rewritePartials (mkConfig []) "$partial(\"content/media/branding/logo.svg\")$"
                @?= "$partial(\"content/media/branding/logo.svg\")$"
        , testCase "rewrites only templates/ partials among other text" $
            rewritePartials
                (mkConfig ["site-menu.html"])
                "a$partial(\"templates/site-menu.html\")$b$partial(\"templates/site-head.html\")$c"
                @?= "a$partial(\"content/templates/site-menu.html\")$b$partial(\"templates/site-head.html\")$c"
        ]
