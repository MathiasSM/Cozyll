-- | Tests for the ruby index schema, normalisation, and canonical encoding
module Cozyll.RubyIndexSpec (tests) where

import Cozyll.Ruby.Index (
    Index (..),
    KanjiRow (..),
    Level (..),
    SegmentRow (..),
    WordRow (..),
    decodeIndex,
    defaultMaxIndexBytes,
    encodeIndex,
    isHan,
    isKana,
    levelRank,
    levelText,
    loadIndexFile,
    normalizeKey,
    parseLevel,
    readIndexFile,
 )
import Data.Text (Text)
import Data.Text qualified as T
import System.IO (hClose, hPutStr)
import System.IO.Temp (withSystemTempFile)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, assertFailure, testCase, (@?=))

tests :: TestTree
tests =
    testGroup
        "Ruby data"
        [ testGroup
            "normalisation"
            [ testCase "folds half-width katakana" $ normalizeKey "ｶﾀｶﾅ" @?= "かたかな"
            , testCase "folds full-width katakana" $ normalizeKey "カタカナ" @?= "かたかな"
            , testCase "folds full-width Latin and digits" $ normalizeKey "Ａ１" @?= "a1"
            , testCase "composes NFD dakuten" $ normalizeKey "か\x3099" @?= "が"
            , testCase "maps small ke to ka" $ normalizeKey "ヶ" @?= "か"
            , testCase "strips whitespace" $ normalizeKey " 日 本 " @?= "日本"
            , testCase "keeps compatibility ideographs" $ normalizeKey "﨑" @?= "﨑"
            , testCase "does not fold voiced kana" $ assertBool "ぢ ≠ じ" (normalizeKey "ぢ" /= "じ")
            , testCase "is idempotent" $ normalizeKey (normalizeKey "ｶﾞｯｺｳ") @?= normalizeKey "ｶﾞｯｺｳ"
            ]
        , testGroup
            "character classes"
            [ testCase "recognises Han" $ assertBool "日" (isHan '日')
            , testCase "does not treat the iteration mark as Han" $ assertBool "々" (not (isHan '々'))
            , testCase "recognises kana" $ assertBool "か" (isKana 'か')
            ]
        , testGroup
            "levels"
            [ testCase "renders levels" $ map levelText [N1, N2, N3, N4, N5] @?= ["n1", "n2", "n3", "n4", "n5"]
            , testCase "parses levels" $ map parseLevel ["n1", "n5", "x"] @?= [Just N1, Just N5, Nothing]
            , testCase "ranks N5 as easiest" $ map levelRank [N5, N4, N3, N2, N1] @?= [1, 2, 3, 4, 5]
            ]
        , testGroup
            "encoding"
            [ testCase "round-trips an index" $ do
                let idx =
                        Index
                            [KanjiRow '一' (Just 1) (Just N5), KanjiRow '丈' (Just 8) Nothing]
                            [WordRow "日本語" "にほんご" N5]
                            [SegmentRow "大人" "おとな"]
                decodeIndex (encodeIndex idx) @?= Right idx
            , testCase "writes one tuple per line" $
                encodeIndex (Index [KanjiRow '一' (Just 1) (Just N5), KanjiRow '丈' (Just 8) Nothing] [] [])
                    @?= "{\n  \"schemaVersion\": 1,\n  \"derivationVersion\": 1,\n  \"kanji\": [\n    [\"一\", 1, \"n5\"],\n    [\"丈\", 8, null]\n  ],\n  \"words\": [],\n  \"segments\": []\n}\n"
            , testCase "rejects unsorted rows" $
                decodeIndex (indexJson "[[\"丈\", 8, null], [\"一\", 1, \"n5\"]]" "[]")
                    @?= Left "kanji must be sorted"
            , testCase "rejects duplicate rows" $
                decodeIndex (indexJson "[[\"一\", 1, \"n5\"], [\"一\", 1, \"n5\"]]" "[]")
                    @?= Left "kanji contains duplicates"
            , testCase "rejects non-normalised keys" $
                decodeIndex (indexJson "[]" "[[\"カ\", \"か\", \"n5\"]]")
                    @?= Left "words.surface is not normalised (run `cozyll data fmt`)"
            , testCase "rejects newer schema versions" $
                case decodeIndex (T.replace "\"schemaVersion\": 1" "\"schemaVersion\": 2" (encodeIndex (Index [] [] []))) of
                    Left message -> assertBool message ("schemaVersion" `T.isInfixOf` T.pack message)
                    Right _ -> assertBool "expected a failure" False
            ]
        , testGroup
            "file diagnostics"
            [ testCase "names the root object as index" $
                decodeIndex "[]" @?= (Left "index must be an object" :: Either String Index)
            , testCase "readIndexFile prefixes the path" $
                withSystemTempFile "index.json" $ \path handle -> do
                    hPutStr handle "[]"
                    hClose handle
                    result <- readIndexFile path
                    result @?= (Left (path ++ ": index must be an object") :: Either String Index)
            , testCase "loadIndexFile names the path once" $
                withSystemTempFile "index.json" $ \path handle -> do
                    hPutStr handle "[]"
                    hClose handle
                    loaded <- loadIndexFile defaultMaxIndexBytes path
                    case loaded of
                        Left message -> message @?= path ++ ": index must be an object"
                        Right _ -> assertFailure "expected a decode failure"
            ]
        ]

indexJson :: String -> String -> Text
indexJson kanjiRows wordRows =
    T.pack $
        "{ \"schemaVersion\": 1, \"derivationVersion\": 1, \"kanji\": "
            ++ kanjiRows
            ++ ", \"words\": "
            ++ wordRows
            ++ ", \"segments\": [] }"
