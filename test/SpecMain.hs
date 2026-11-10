{- | Unit test entrypoint: the spec modules only. The golden (snapshot) tests
live in @GoldenMain.hs@ and are run as a separate test suite.
-}
module Main (main) where

import Cozyll.AccessibilitySpec qualified as Accessibility
import Cozyll.AsideSpec qualified as Aside
import Cozyll.AuthorSpec qualified as Author
import Cozyll.BuildStateSpec qualified as BuildState
import Cozyll.CacheSpec qualified as Cache
import Cozyll.CleanURLSpec qualified as CleanURL
import Cozyll.CliDataSpec qualified as CliData
import Cozyll.CliSpec qualified as Cli
import Cozyll.ContentSpec qualified as Content
import Cozyll.DataSpec qualified as Data
import Cozyll.FeedSpec qualified as Feed
import Cozyll.FormatSpec qualified as Format
import Cozyll.HtmlSpec qualified as Html
import Cozyll.JsonLdSpec qualified as JsonLd
import Cozyll.LanguageSpec qualified as Language
import Cozyll.MediaSpec qualified as Media
import Cozyll.MetadataSpec qualified as Metadata
import Cozyll.NavSpec qualified as Nav
import Cozyll.PostSpec qualified as Post
import Cozyll.ProjectSpec qualified as Project
import Cozyll.RedirectsSpec qualified as Redirects
import Cozyll.RubyDeriveSpec qualified as RubyDerive
import Cozyll.RubyFilterSpec qualified as RubyFilter
import Cozyll.RubyIndexSpec qualified as RubyIndex
import Cozyll.RubySourcesSpec qualified as RubySources
import Cozyll.RubySpec qualified as Ruby
import Cozyll.RubyVerifySpec qualified as RubyVerify
import Cozyll.SocialMetaSpec qualified as SocialMeta
import Cozyll.SocialSpec qualified as Social
import Cozyll.ThemeSpec qualified as Theme
import System.Environment (setEnv)
import Test.Tasty (defaultIngredients, defaultMainWithIngredients, testGroup)
import Test.Tasty.Runners.AntXML (antXMLRunner)

main :: IO ()
main = do
    -- Fixture builds change the process working directory, so tests that read
    -- repository files must not run concurrently with them.
    setEnv "TASTY_NUM_THREADS" "1"
    defaultMainWithIngredients
        (antXMLRunner : defaultIngredients)
        ( testGroup
            "unit"
            [ Accessibility.tests
            , Aside.tests
            , Author.tests
            , Cache.tests
            , BuildState.tests
            , CleanURL.tests
            , CliData.tests
            , Cli.tests
            , Content.tests
            , Data.tests
            , Feed.tests
            , Format.tests
            , Html.tests
            , JsonLd.tests
            , Language.tests
            , Media.tests
            , Metadata.tests
            , Nav.tests
            , Post.tests
            , Project.tests
            , Redirects.tests
            , Ruby.tests
            , RubyIndex.tests
            , RubyDerive.tests
            , RubyFilter.tests
            , RubySources.tests
            , RubyVerify.tests
            , SocialMeta.tests
            , Social.tests
            , Theme.tests
            ]
        )
