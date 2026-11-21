-- | Tests for the ruby index schema, normalisation, and canonical encoding
module Cozyll.RubyIndexSpec (tests) where

import Control.Exception (bracket)
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
    writeTextFileAtomic,
 )
import Cozyll.Ruby.Json (asArray, asInt, asMaybeInt, asObject, asText, decodeJson, required)
import Data.Aeson (Value (..))
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Bits ((.&.))
import Data.ByteString qualified as BS
import Data.Text (Text)
import Data.Text qualified as T
import System.FilePath ((</>))
import System.IO (hClose, hPutStr)
import System.IO.Temp (withSystemTempDirectory, withSystemTempFile)
import System.Posix.Files (fileMode, getFileStatus, groupReadMode, otherReadMode, setFileCreationMask)
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
            "json helpers"
            [ testCase "asObject accepts an object" $
                asObject "demo" (Object (KeyMap.singleton "k" Null)) @?= Right (KeyMap.singleton "k" Null)
            , testCase "asObject rejects a wrong shape" $ asObject "demo" (String "x") @?= Left "demo must be an object"
            , testCase "asArray accepts an array" $
                case decodeJson "[\"a\", \"b\"]" of
                    Right value -> asArray "demo" value @?= Right [String "a", String "b"]
                    Left problem -> assertFailure problem
            , testCase "asArray rejects a wrong shape" $ asArray "demo" Null @?= Left "demo must be an array"
            , testCase "asText accepts a string" $ asText "demo" (String "x") @?= Right "x"
            , testCase "asText rejects a wrong shape" $ asText "demo" (Bool True) @?= Left "demo must be a string"
            , testCase "asInt accepts a whole number" $ asInt "demo" (Number 42) @?= Right 42
            , testCase "asInt rejects a fraction" $ asInt "demo" (Number 1.5) @?= Left "demo must be an integer"
            , testCase "asInt rejects a wrong shape" $
                asInt "demo" (String "7") @?= Left "demo must be an integer"
            , testCase "asMaybeInt treats null as nothing" $ asMaybeInt "demo" Null @?= Right Nothing
            , testCase "asMaybeInt accepts a whole number" $ asMaybeInt "demo" (Number 3) @?= Right (Just 3)
            , testCase "required finds a present field" $
                required "name" (KeyMap.singleton "name" (String "x")) @?= Right (String "x")
            , testCase "required names a missing field" $ required "name" KeyMap.empty @?= Left "missing field name"
            , testCase "decodeJson accepts plain JSON" $
                decodeJson "{\"a\": \"x\"}" @?= Right (Object (KeyMap.singleton "a" (String "x")))
            , testCase "decodeJson tolerates a BOM" $
                decodeJson (BS.pack [0xEF, 0xBB, 0xBF] <> "{\"a\": \"x\"}")
                    @?= Right (Object (KeyMap.singleton "a" (String "x")))
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
        , testGroup
            "permissions"
            [ testCase "writeTextFileAtomic keeps default permissions" $
                withSystemTempDirectory "cozyll-perms" $ \dir -> do
                    let path = dir </> "index.json"
                    bracket (setFileCreationMask 0o022) setFileCreationMask $ \_ -> do
                        writeTextFileAtomic path "x"
                        status <- getFileStatus path
                        let mode = fileMode status
                        assertBool "group-readable" (mode .&. groupReadMode /= 0)
                        assertBool "other-readable" (mode .&. otherReadMode /= 0)
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
