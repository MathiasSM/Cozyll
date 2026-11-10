-- | Tests for the default sources file, overrides, resolution, and downloads
module Cozyll.RubySourcesSpec (tests) where

import Cozyll.Ruby.Sources (
    ResolvedSource (..),
    Source (..),
    SourceFile (..),
    SourceKind (..),
    downloadSources,
    githubRepo,
    loadSources,
    resolveSources,
    substituteRef,
 )
import Data.ByteString qualified as BS
import Data.List (isInfixOf)
import Data.Map.Strict qualified as Map
import Data.Text qualified as T
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))

tests :: TestTree
tests =
    testGroup
        "Ruby sources"
        [ testCase "loads the embedded default when the file is absent" $ do
            loaded <- loadSources "/definitely/not/a/sources.yaml"
            case loaded of
                Left problem -> assertBool problem False
                Right sources -> do
                    map sourceId sources @?= ["kanji-data", "yomitan-jlpt-vocab", "jmdict-furigana", "jmnedict-furigana"]
                    assertBool "urls use {ref}" (all (all (T.isInfixOf "{ref}" . sourceFileUrl) . sourceFiles) sources)
        , testCase "substitutes the ref placeholder" $
            substituteRef "deadbeef" "https://x/{ref}/file" @?= "https://x/deadbeef/file"
        , testCase "parses owner/repo from raw GitHub URLs" $
            githubRepo "https://raw.githubusercontent.com/davidluzgouveia/kanji-data/abc/kanji.json"
                @?= Just ("davidluzgouveia", "kanji-data")
        , testCase "parses owner/repo from release URLs" $
            githubRepo "https://github.com/Doublevil/JmdictFurigana/releases/download/v1/x.zip"
                @?= Just ("Doublevil", "JmdictFurigana")
        , testCase "rejects latest for non-GitHub sources" $ do
            let source =
                    Source
                        "mirror"
                        Repo
                        "latest"
                        "MIT"
                        [SourceFile "kanji.json" "https://gitlab.example/kanji.json" Nothing]
            result <- resolveSources (\_ -> pure (Left "unexpected")) [source]
            assertBool (show result) (isLeft result)
        , testCase "resolves latest refs and release digests" $ do
            result <- resolveSources fakeFetch [repoSource, releaseSource]
            case result of
                Left problems -> assertBool (show problems) False
                Right resolved -> do
                    map (sourceRef . resolvedSource) resolved @?= ["deadbeef", "v1"]
                    Map.lookup "JmdictFurigana.json.zip" (resolvedDigests (resolved !! 1)) @?= Just "abc"
        , testCase "reports a digest mismatch" $ do
            let resolved = ResolvedSource releaseSource (Map.singleton "JmdictFurigana.json.zip" "wrong")
            result <- downloadSources (\_ -> pure (Right "bytes")) [resolved]
            assertBool (show result) (isLeft result)
        ]

repoSource :: Source
repoSource =
    Source
        "kanji-data"
        Repo
        "latest"
        "MIT"
        [SourceFile "kanji.json" "https://raw.githubusercontent.com/o/r/{ref}/kanji.json" Nothing]

releaseSource :: Source
releaseSource =
    Source
        "jmdict-furigana"
        Release
        "latest"
        "CC-BY-SA-4.0"
        [ SourceFile
            "JmdictFurigana.json"
            "https://github.com/Doublevil/JmdictFurigana/releases/download/{ref}/JmdictFurigana.json.zip"
            (Just "JmdictFurigana.json")
        ]

fakeFetch :: String -> IO (Either String BS.ByteString)
fakeFetch url
    | "commits" `isInfixOf` url = pure (Right "[{\"sha\": \"deadbeef\"}]")
    | "releases/latest" `isInfixOf` url =
        pure
            ( Right
                "{\"tag_name\": \"v1\", \"assets\": [{\"name\": \"JmdictFurigana.json.zip\", \"digest\": \"sha256:abc\"}]}"
            )
    | otherwise = pure (Left ("unexpected URL: " ++ url))

isLeft :: Either a b -> Bool
isLeft = \case
    Left _ -> True
    Right _ -> False
