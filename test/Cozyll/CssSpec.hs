-- | Tests for the stylesheet assembly: development keeps it readable, production minifies it
module Cozyll.CssSpec (tests) where

import Control.Exception (bracket)
import Cozyll.Config (Env (..))
import Cozyll.Fixture (buildFixtureFor, copyTree)
import Data.List (isInfixOf)
import System.Directory (getCurrentDirectory, removePathForcibly)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase)

-- | The stylesheet-compression tests
tests :: TestTree
tests =
    testGroup
        "Css"
        [ testCase "dev keeps CSS comments, example strips them" $ do
            root <- getCurrentDirectory
            withSystemTempDirectory "cozyll-css" $ \content -> do
                copyTree (root </> "example-content") content
                writeFile (content </> "css" </> "probe.css") $ "/* " ++ marker ++ " */\n"
                bracket (buildFixtureFor Dev root content) (removePathForcibly . fst) $ \(_, site) -> do
                    styles <- readFile (site </> "styles.css")
                    assertBool "the dev stylesheet keeps the comment" (marker `isInfixOf` styles)
                bracket (buildFixtureFor Example root content) (removePathForcibly . fst) $ \(_, site) -> do
                    styles <- readFile (site </> "styles.css")
                    assertBool "the example stylesheet is minified" (not (marker `isInfixOf` styles))
        ]

-- | A comment body that CSS minification removes, along with its delimiters
marker :: String
marker = "cozyll-css-env-probe"
