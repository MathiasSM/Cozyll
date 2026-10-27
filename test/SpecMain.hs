{- | Unit test entrypoint: the spec modules only. The golden (snapshot) tests
live in @GoldenMain.hs@ and are run as a separate test suite.
-}
module Main (main) where

import Cozyll.AccessibilitySpec qualified as Accessibility
import Cozyll.AsideSpec qualified as Aside
import Cozyll.AuthorSpec qualified as Author
import Cozyll.CleanURLSpec qualified as CleanURL
import Cozyll.ContentSpec qualified as Content
import Cozyll.DataSpec qualified as Data
import Cozyll.FeedSpec qualified as Feed
import Cozyll.FormatSpec qualified as Format
import Cozyll.HtmlSpec qualified as Html
import Cozyll.JsonLdSpec qualified as JsonLd
import Cozyll.LanguageSpec qualified as Language
import Cozyll.MetadataSpec qualified as Metadata
import Cozyll.NavSpec qualified as Nav
import Cozyll.PostSpec qualified as Post
import Cozyll.ProjectSpec qualified as Project
import Cozyll.RedirectsSpec qualified as Redirects
import Cozyll.SocialMetaSpec qualified as SocialMeta
import Cozyll.SocialSpec qualified as Social
import Cozyll.ThemeSpec qualified as Theme
import Test.Tasty (defaultIngredients, defaultMainWithIngredients, testGroup)
import Test.Tasty.Runners.AntXML (antXMLRunner)

main :: IO ()
main =
    defaultMainWithIngredients
        (antXMLRunner : defaultIngredients)
        ( testGroup
            "unit"
            [ Accessibility.tests
            , Aside.tests
            , Author.tests
            , CleanURL.tests
            , Content.tests
            , Data.tests
            , Feed.tests
            , Format.tests
            , Html.tests
            , JsonLd.tests
            , Language.tests
            , Metadata.tests
            , Nav.tests
            , Post.tests
            , Project.tests
            , Redirects.tests
            , SocialMeta.tests
            , Social.tests
            , Theme.tests
            ]
        )
