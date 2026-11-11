{- | Regression test for F20: a template override added to
@content\/templates\/@ must take effect on the next build, with no clean.

Hakyll rebuilds from the previous run's dependency set, so the override alone
would be invisible. The render paths record a pattern dependency on the whole
template set, which is re-checked every run. This test reproduces the two
separate @cozyll build@ invocations against the same @_cache@.
-}
module Cozyll.CacheSpec (tests) where

import Control.Exception (bracket)
import Cozyll.Fixture (buildFixture, loadFixtureConfig, runBuild)
import Data.ByteString.Char8 qualified as BS
import System.Directory (createDirectoryIfMissing, getCurrentDirectory, removePathForcibly)
import System.Exit (ExitCode (..))
import System.FilePath (takeDirectory, (</>))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (Assertion, assertBool, assertFailure, testCase)

-- | The override marker the test looks for in the group index output
probe :: String
probe = "override-probe"

tests :: TestTree
tests =
    testGroup
        "Cache"
        [ testCase "a template override added after a build applies to the next build" $ do
            root <- getCurrentDirectory
            bracket (buildFixture root (root </> "example-content")) (removePathForcibly . fst) $ \(_, site) -> do
                let dir = takeDirectory site
                assertAbsent (siteIndex site)

                -- A new `cozyll build` re-discovers the overrides, but keeps the cache
                createDirectoryIfMissing True (dir </> "content" </> "templates")
                writeFile (dir </> "content" </> "templates" </> "post-list.html") $
                    "<span id=\"" ++ probe ++ "\"></span>\n"
                (cfg, website) <- loadFixtureConfig dir
                runBuild dir cfg website >>= \case
                    ExitSuccess -> pure ()
                    ExitFailure code -> assertFailure ("build failed with exit code " ++ show code)

                assertPresent (siteIndex site)
        ]

-- | The prose group index in the built site
siteIndex :: FilePath -> FilePath
siteIndex site = site </> "prose" </> "index.html"

-- | Asserts the override marker is in the prose group index
assertPresent :: FilePath -> Assertion
assertPresent = assertMarker "contain" BS.isInfixOf

-- | Asserts the override marker is not in the prose group index
assertAbsent :: FilePath -> Assertion
assertAbsent = assertMarker "not contain" (\needle haystack -> not (needle `BS.isInfixOf` haystack))

assertMarker :: String -> (BS.ByteString -> BS.ByteString -> Bool) -> FilePath -> Assertion
assertMarker expectation holds path = do
    contents <- BS.readFile path
    assertBool
        ("expected " ++ path ++ " to " ++ expectation ++ " \"" ++ probe ++ "\"")
        (holds (BS.pack probe) contents)
