-- | Tests for the language code normalization
module Cozyll.LanguageSpec (tests) where

import Cozyll.Domain.Language (Language (..), languageOfWith, normalizeLanguage)
import Cozyll.Domain.Website (Site (..))
import Cozyll.Yaml (Check (runCheck), decodeYaml)
import Data.Aeson (Value (String))
import Data.Aeson.Key (fromString)
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Either (isLeft)
import Data.List (isPrefixOf)
import Data.Text qualified as T
import Hakyll (Metadata)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))

tests :: TestTree
tests =
    testGroup
        "Language"
        [ testCase "accepts a bare 2-letter code" $
            normalizeLanguage "es" @?= Right (Language "es")
        , testCase "lowercases the primary tag" $
            normalizeLanguage "EN" @?= Right (Language "en")
        , testCase "normalizes a region to -UPPER" $
            normalizeLanguage "pt_BR" @?= Right (Language "pt-BR")
        , testCase "uppercases the region subtag" $
            normalizeLanguage "es-mx" @?= Right (Language "es-MX")
        , testCase "rejects a code that isn't 2 letters" $
            normalizeLanguage "xyz" @?= Left "expected a 2-letter ISO 639-1 code with an optional region, got \"xyz\""
        , testCase "rejects an empty code" $
            normalizeLanguage "" @?= Left "expected a 2-letter ISO 639-1 code with an optional region, got \"\""
        , testCase "rejects extra segments" $
            normalizeLanguage "pt-BR-suffix" @?= Left "expected a 2-letter ISO 639-1 code with an optional region, got \"pt-BR-suffix\""
        , testGroup
            "site.language"
            [ testCase "reads site.language" $
                (siteLanguage <$> decodeYaml site) @?= Right (Just (Language "ja"))
            , testCase "defaults to Nothing (English) when unset" $
                (siteLanguage <$> decodeYaml (withoutLanguage site)) @?= Right Nothing
            , testCase "rejects an invalid language" $
                assertBool "expected parsing to fail" (isLeft (decodeYaml (setLanguage "english" site) :: Either [String] Site))
            ]
        , testGroup
            "languageOfWith"
            [ testCase "falls back to the site's language" $
                runCheck (languageOfWith (Language "ja") emptyMetadata) @?= Right (Language "ja")
            , testCase "lets the page override the site's language" $
                runCheck (languageOfWith (Language "ja") (languageMetadata "es")) @?= Right (Language "es")
            ]
        ]

site :: String
site = "title: Site\ndescription: Description\ncopyrightYear: 2020\ndomain: example.com\nlanguage: ja\n"

withoutLanguage :: String -> String
withoutLanguage = unlines . filter (not . ("language:" `isPrefixOf`)) . lines

setLanguage :: String -> String -> String
setLanguage language =
    unlines
        . map (\line -> if "language:" `isPrefixOf` line then "language: " ++ language else line)
        . lines

languageMetadata :: String -> Metadata
languageMetadata language = KeyMap.singleton (fromString "language") (String (T.pack language))

emptyMetadata :: Metadata
emptyMetadata = KeyMap.empty
