-- | Tests for build provenance, the stale-output reset, and the check guard
module Cozyll.BuildStateSpec (tests) where

import Control.Monad ((>=>))
import Cozyll.BuildState (
    BuildStart (..),
    BuildState (..),
    applyBuildStartIn,
    buildStatePathIn,
    decideBuildStart,
    newestContentChange,
    readBuildStateIn,
    resetBuildOutputsIn,
    siteOutputExistsIn,
    writeBuildStateIn,
 )
import Cozyll.Config (Env (..), envFromText, envText)
import Data.Time (UTCTime (..), addUTCTime, fromGregorian, secondsToDiffTime)
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, setModificationTime)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))

-- | The build time used by the fixtures
builtAt :: UTCTime
builtAt = UTCTime (fromGregorian 2024 1 2) (secondsToDiffTime 3600)

-- | A state built by @env@ at 'builtAt'
state :: Env -> BuildState
state env =
    BuildState
        { buildStateVersion = "9.9.9.9"
        , buildStateEnv = env
        , buildStateBuiltAt = builtAt
        , buildStateContentDir = "content"
        }

-- | The build provenance tests
tests :: TestTree
tests =
    testGroup
        "BuildState"
        [ testGroup
            "decideBuildStart"
            [ testCase "proceeds on a fresh directory" $
                decideBuildStart Nothing Prod False @?= Proceed
            , testCase "resets output without provenance" $
                decideBuildStart Nothing Prod True
                    @?= Reset "no build state found; rebuilding from scratch"
            , testCase "resets when SITE_ENV changes" $
                decideBuildStart (Just (state Dev)) Prod True
                    @?= Reset "SITE_ENV changed dev -> prod; cleared _site and _cache"
            , testCase "proceeds when SITE_ENV is unchanged" $
                decideBuildStart (Just (state Prod)) Prod True @?= Proceed
            , testCase "proceeds when the state matches but the site is gone" $
                decideBuildStart (Just (state Prod)) Prod False @?= Proceed
            ]
        , testGroup
            "state file"
            [ testCase "round-trips through _cache/cozyll-build.json" $
                withStateRoot $ \root -> do
                    writeBuildStateIn root (state Dev)
                    readBuildStateIn root >>= (@?= Just (state Dev))
                    created <- doesFileExist (buildStatePathIn root)
                    assertBool "state file was created" created
            , testCase "is Nothing when the state file is missing" $
                withStateRoot (readBuildStateIn >=> (@?= Nothing))
            , testCase "is Nothing when the JSON is corrupt" $
                withStateRoot $ \root -> do
                    let file = buildStatePathIn root
                    createDirectoryIfMissing True (root </> "_cache")
                    writeFile file "{not json"
                    readBuildStateIn root >>= (@?= Nothing)
            ]
        , testGroup
            "reset"
            [ testCase "removes _site and _cache when SITE_ENV changes" $
                withStateRoot $ \root -> do
                    createDirectoryIfMissing True (root </> "_site" </> "prose")
                    writeFile (root </> "_site" </> "prose" </> "draft.html") "draft"
                    writeBuildStateIn root (state Dev)
                    applyBuildStartIn root (decideBuildStart (Just (state Dev)) Prod True)
                    site <- doesDirectoryExist (root </> "_site")
                    cache <- doesDirectoryExist (root </> "_cache")
                    assertBool "_site is gone" (not site)
                    assertBool "_cache is gone" (not cache)
            , testCase "removes a site with no build state" $
                withStateRoot $ \root -> do
                    createDirectoryIfMissing True (root </> "_site")
                    writeFile (root </> "_site" </> "index.html") "old"
                    applyBuildStartIn root (decideBuildStart Nothing Prod True)
                    site <- doesDirectoryExist (root </> "_site")
                    assertBool "_site is gone" (not site)
            , testCase "tolerates missing directories" $
                withStateRoot $ \root ->
                    resetBuildOutputsIn root
            ]
        , testGroup
            "siteOutputExists"
            [ testCase "is false without _site" $
                withStateRoot $ \root -> do
                    exists <- siteOutputExistsIn root
                    exists @?= False
            , testCase "is false for an empty _site" $
                withStateRoot $ \root -> do
                    createDirectoryIfMissing True (root </> "_site")
                    exists <- siteOutputExistsIn root
                    exists @?= False
            , testCase "is true for a non-empty _site" $
                withStateRoot $ \root -> do
                    createDirectoryIfMissing True (root </> "_site")
                    writeFile (root </> "_site" </> "index.html") "site"
                    exists <- siteOutputExistsIn root
                    exists @?= True
            ]
        , testGroup
            "newestContentChange"
            [ testCase "names the newest file changed after the build" $
                withStateRoot $ \root -> do
                    let content = root </> "content"
                    createDirectoryIfMissing True (content </> "writings")
                    writeFile (content </> "writings" </> "old.md") "old"
                    setModificationTime (content </> "writings" </> "old.md") builtAt
                    writeFile (content </> "writings" </> "new.md") "new"
                    setModificationTime (content </> "writings" </> "new.md") (addUTCTime 30 builtAt)
                    newestContentChange content builtAt
                        >>= (@?= Just (content </> "writings" </> "new.md"))
            , testCase "is Nothing when nothing changed after the build" $
                withStateRoot $ \root -> do
                    let content = root </> "content"
                    createDirectoryIfMissing True content
                    writeFile (content </> "page.md") "page"
                    setModificationTime (content </> "page.md") builtAt
                    newestContentChange content builtAt >>= (@?= Nothing)
            ]
        , testGroup
            "env codec"
            [ testCase "renders prod" $
                envText Prod @?= "prod"
            , testCase "renders dev" $
                envText Dev @?= "dev"
            , testCase "renders example" $
                envText Example @?= "example"
            , testCase "round-trips every environment through the state file spelling" $
                mapM_ (\env -> envFromText (envText env) @?= Just env) [Prod, Dev, Example]
            , testCase "rejects names outside the codec" $ do
                envFromText "bogus" @?= Nothing
                envFromText "" @?= Nothing
                envFromText "Prod" @?= Nothing
            ]
        ]

-- | Runs an action in a fresh build-state root
withStateRoot :: (FilePath -> IO a) -> IO a
withStateRoot = withSystemTempDirectory "cozyll-build-state"
