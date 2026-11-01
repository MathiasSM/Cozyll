-- | Tests for the language code normalization
module Cozyll.LanguageSpec (tests) where

import Cozyll.Domain.Language (Language (..), normalizeLanguage)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

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
        ]
