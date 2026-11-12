{- | Regression tests: the build reads @website.yaml@, @authors.yaml@, the
socials\/localization files and the brand logo outside Hakyll's rules. Editing
one must take effect on the next @cozyll build@, with no clean.

Hakyll only propagates out-of-date state from identifiers in its universe, so
each case reproduces two separate builds against the same @_cache@.
-}
module Cozyll.ConfigCacheSpec (tests) where

import Control.Exception (bracket)
import Cozyll.Fixture (buildFixture, loadFixtureConfig, runBuild)
import Data.ByteString.Char8 qualified as BS
import Data.Text qualified as T
import Data.Text.Encoding (encodeUtf8)
import Data.Time (addUTCTime)
import System.Directory (getCurrentDirectory, getModificationTime, removeFile, removePathForcibly, setModificationTime)
import System.Exit (ExitCode (..))
import System.FilePath (takeDirectory, (</>))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (Assertion, assertBool, assertFailure, testCase)

tests :: TestTree
tests =
    testGroup
        "ConfigCache"
        [ testCase "a manifest value edited after a build applies to the next build" $
            withFixture $ \dir site -> do
                let manifest = site </> "manifest.webmanifest"
                assertContains manifest oldThemeColor
                editFile (content dir "website.yaml") oldThemeColor newThemeColor
                rebuild dir
                assertContains manifest newThemeColor
        , testCase "the site title edited after a build applies to the next build" $
            withFixture $ \dir site -> do
                let home = site </> "index.html"
                assertNotContains home newTitle
                editFile (content dir "website.yaml") "  title: Example\n" ("  title: " ++ newTitle ++ "\n")
                rebuild dir
                assertContains home newTitle
        , testCase "removing the logo drops the icons from the manifest and the head" $
            withFixture $ \dir site -> do
                let manifest = site </> "manifest.webmanifest"
                    home = site </> "index.html"
                assertContains manifest "\"icons\""
                assertContains home "rel=\"icon\""
                removeFile (content dir "media" </> "branding" </> "logo.svg")
                rebuild dir
                assertNotContains manifest "\"icons\""
                assertNotContains home "rel=\"icon\""
        , testCase "an author display name edited after a build applies to the next build" $
            withFixture $ \dir site -> do
                let tour = site </> "prose" </> "tour" </> "index.html"
                assertNotContains tour newDisplayName
                editFile (content dir "authors.yaml") "  displayName: Example\n" ("  displayName: " ++ newDisplayName ++ "\n")
                rebuild dir
                assertContains tour newDisplayName
        , testCase "the ruby index edited after a build applies to the next build" $
            withFixture $ \dir site -> do
                let page = site </> "languages" </> "japanese" </> "index.html"
                assertContains page "data-jlpt=\"n5\""
                editFile
                    (content dir ("ruby-data" </> "index.json"))
                    "[\"日本語\", \"にほんご\", \"n5\"]"
                    "[\"日本語\", \"にほんご\", \"n1\"]"
                rebuild dir
                assertContains page "data-jlpt=\"n1\""
        ]

-- | The manifest theme colour in the example content, and its replacement
oldThemeColor, newThemeColor :: String
oldThemeColor = "hsl(210, 75%, 50%)"
newThemeColor = "#123456"

-- | A site title the example content does not already use
newTitle :: String
newTitle = "Example Renamed"

-- | An author display name the example content does not already use
newDisplayName :: String
newDisplayName = "Example Renamed Author"

-- | Runs an action against a freshly built fixture, then removes its work directory
withFixture :: (FilePath -> FilePath -> IO ()) -> IO ()
withFixture action = do
    root <- getCurrentDirectory
    bracket
        (buildFixture root (root </> "example-content"))
        (removePathForcibly . fst)
        $ \(_, site) -> action (takeDirectory site) site

-- | The fixture's copied content directory
content :: FilePath -> FilePath -> FilePath
content dir path = dir </> "content" </> path

-- | Runs the build again from the same cache, reloading the config first
rebuild :: FilePath -> IO ()
rebuild dir = do
    (cfg, website) <- loadFixtureConfig dir
    runBuild dir cfg website >>= \case
        ExitSuccess -> pure ()
        ExitFailure code -> assertFailure ("build failed with exit code " ++ show code)

{- | Replaces the first occurrence of @needle@ in a file, then pushes its mtime
past the filesystem's resolution so the next build sees the edit.

The files are read and written as UTF-8, so non-ASCII values can be edited too.
-}
editFile :: FilePath -> String -> String -> IO ()
editFile path needle replacement = do
    let needle' = encodeUtf8 (T.pack needle)
        replacement' = encodeUtf8 (T.pack replacement)
    bytes <- BS.readFile path
    let (before, rest) = BS.breakSubstring needle' bytes
    if BS.null rest
        then assertFailure ("expected " ++ path ++ " to contain \"" ++ needle ++ "\"")
        else do
            BS.writeFile path (before <> replacement' <> BS.drop (BS.length needle') rest)
            modified <- getModificationTime path
            setModificationTime path (addUTCTime 2 modified)

-- | Asserts a file contains @needle@
assertContains :: FilePath -> String -> Assertion
assertContains path needle = do
    contents <- BS.readFile path
    assertBool
        ("expected " ++ path ++ " to contain \"" ++ needle ++ "\"")
        (encodeUtf8 (T.pack needle) `BS.isInfixOf` contents)

-- | Asserts a file does not contain @needle@
assertNotContains :: FilePath -> String -> Assertion
assertNotContains path needle = do
    contents <- BS.readFile path
    assertBool
        ("expected " ++ path ++ " not to contain \"" ++ needle ++ "\"")
        (not (encodeUtf8 (T.pack needle) `BS.isInfixOf` contents))
