-- | Tests for deriving the index from upstream files
module Cozyll.RubyDeriveSpec (tests) where

import Cozyll.Ruby.Data (Index (..), Level (..), SegmentRow (..), WordRow (..), encodeIndex)
import Cozyll.Ruby.Derive (Issue (..), Upstream (..), deriveIndex, readUpstreamFrom)
import Data.ByteString qualified as BS
import Data.List (find)
import Data.Text qualified as T
import Data.Text.Encoding (encodeUtf8)
import Data.Text.IO qualified as TIO
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, assertFailure, testCase, (@?=))

tests :: TestTree
tests =
    testGroup
        "Ruby derive"
        [ testCase "matches the committed fixture index" $ do
            idx <- fixtureIndex
            expected <- TIO.readFile "test/fixtures/ruby/expected-index.json"
            encodeIndex idx @?= expected
        , testCase "resolves cross-level conflicts to the easiest level" $ do
            idx <- fixtureIndex
            case find ((== ("三日月", "みかづき")) . key) (idxWords idx) of
                Nothing -> assertFailure "三日月 is missing"
                Just row -> wrLevel row @?= N4
        , testCase "drops kana-only word rows" $ do
            idx <- fixtureIndex
            assertBool "empty surfaces" (not (any (T.null . wrSurface) (idxWords idx)))
        , testCase "deduplicates segment pairs" $ do
            idx <- fixtureIndex
            length (filter (== SegmentRow "大人" "おとな") (idxSegments idx)) @?= 1
        , testCase "normalises segment keys" $ do
            idx <- fixtureIndex
            assertBool "t → てぃー" (SegmentRow "t" "てぃー" `elem` idxSegments idx)
        , testCase "strips a UTF-8 BOM" $ do
            up <- fixtureUpstream
            let withBom = up{upJmdict = BS.pack [0xEF, 0xBB, 0xBF] <> upJmdict up}
            either (assertFailure . show) (pure . encodeIndex) (deriveIndex withBom) >>= \encoded -> do
                idx <- fixtureIndex
                encoded @?= encodeIndex idx
        , testCase "rejects invalid kanji JSON" $ do
            up <- fixtureUpstream
            case deriveIndex up{upKanji = "not json"} of
                Left (Issue source _ : _) -> source @?= "kanji-data"
                other -> assertFailure ("expected a kanji-data issue, got " ++ show other)
        , testCase "rejects furigana parts that do not concatenate" $ do
            up <- fixtureUpstream
            let bad = encodeUtf8 "[{\"text\": \"大人\", \"reading\": \"おとな\", \"furigana\": [{\"ruby\": \"大\", \"rt\": \"お\"}]}]"
            case deriveIndex up{upJmdict = bad} of
                Left (Issue source message : _) -> do
                    source @?= "jmdict-furigana"
                    assertBool message ("concatenate" `T.isInfixOf` T.pack message)
                other -> assertFailure ("expected a furigana issue, got " ++ show other)
        ]
  where
    key row = (wrSurface row, wrReading row)

fixtureUpstream :: IO Upstream
fixtureUpstream = do
    loaded <- readUpstreamFrom "test/fixtures/ruby/upstream"
    either (assertFailure . show) pure loaded

fixtureIndex :: IO Index
fixtureIndex = do
    up <- fixtureUpstream
    either (assertFailure . show) pure (deriveIndex up)
