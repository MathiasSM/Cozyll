{- | Regression test for F20: a template override added to
@content\/templates\/@ must take effect on the next build, with no clean.

Hakyll rebuilds from the previous run's dependency set, so the override alone
would be invisible. The render paths record a pattern dependency on the whole
template set, which is re-checked every run. This test reproduces the two
separate @cozyll build@ invocations against the same @_cache@.
-}
module Cozyll.CacheSpec (tests) where

import Control.Exception (bracket)
import Cozyll.Config (SiteConfig (..), siteConfiguration)
import Cozyll.Fixture (copyFixture, exampleSite)
import Cozyll.Rules (rules)
import Cozyll.Theme (discoverContentTemplateNames)
import Data.ByteString.Char8 qualified as BS
import Hakyll (Rules)
import Hakyll.Commands qualified as Commands
import Hakyll.Core.Logger qualified as Logger
import Hakyll.Core.Runtime (RunMode (RunModeNormal))
import System.Directory (
    createDirectoryIfMissing,
    getCurrentDirectory,
    removePathForcibly,
    withCurrentDirectory,
 )
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (createTempDirectory, getCanonicalTemporaryDirectory)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (Assertion, assertBool, assertFailure, testCase)

-- | The override marker the test looks for in the group index output
probe :: String
probe = "override-probe"

tests :: TestTree
tests =
    testGroup
        "Cache"
        [ testCase "a template override added after a build applies to the next build" $
            withFixture $ \root dir -> do
                (cfg, website) <- exampleSite root
                build (rules cfg website)
                assertAbsent (siteIndex dir)

                -- A new `cozyll build` re-discovers the overrides, but keeps the cache
                createDirectoryIfMissing True (dir </> "content" </> "templates")
                writeFile (dir </> "content" </> "templates" </> "post-list.html") $
                    "<span id=\"" ++ probe ++ "\"></span>\n"
                names <- discoverContentTemplateNames (dir </> "content" </> "templates")
                build (rules cfg{contentTemplateNames = names} website)

                assertPresent (siteIndex dir)
        ]

-- | The prose group index in the built site
siteIndex :: FilePath -> FilePath
siteIndex dir = dir </> "_site" </> "prose" </> "index.html"

{- | Runs the action in a fresh build directory holding the example site, and
removes it afterwards (the repo's own @_site@ and @_cache@ are never touched).
-}
withFixture :: (FilePath -> FilePath -> IO a) -> IO a
withFixture action = do
    root <- getCurrentDirectory
    bracket (newBuildDirectory root) removePathForcibly $ \dir ->
        withCurrentDirectory dir (action root dir)

-- | A temporary directory with the vendored theme and the example content in place
newBuildDirectory :: FilePath -> IO FilePath
newBuildDirectory root = do
    dir <- getCanonicalTemporaryDirectory >>= \tmp -> createTempDirectory tmp "cozyll-cache"
    copyFixture root dir
    pure dir

-- | Runs a build, failing the test when it fails
build :: Rules () -> IO ()
build siteRules = do
    logger <- Logger.new Logger.Error
    Commands.build RunModeNormal siteConfiguration logger siteRules >>= \case
        ExitSuccess -> pure ()
        ExitFailure code -> assertFailure ("build failed with exit code " ++ show code)

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
