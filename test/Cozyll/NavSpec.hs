-- | Tests for the menu-entry front-matter parser and its label resolution
module Cozyll.NavSpec (tests) where

import Cozyll.Domain.Language (Language (..), defaultLanguage)
import Cozyll.Domain.Nav (NavEntry (..), parseNavYaml, resolveNavLabel)
import Cozyll.TestUtils
import Data.Either (isLeft)
import Data.List (isInfixOf)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))

-- | A page that wants a menu entry
navPage :: Fields
navPage = [("title", "Blog"), ("path", "/blog"), ("nav", "Blog"), ("navOrder", "2")]

-- | A page whose menu label is translated
labelsPage :: Fields
labelsPage = set "nav" "{en: Guides, es: Guías}" navPage

tests :: TestTree
tests =
    testGroup
        "Nav"
        [ testGroup
            "parseNavYaml"
            [ testCase "reads a single label, order, path and language (the site's language unless stated)" $
                parse navPage
                    @?= Right (Just (NavEntry (Just "Blog") [] 2 "/blog" (Language "en")))
            , testCase "reads the site's language as the default entry language" $
                parseNavYaml (Language "ja") (render navPage)
                    @?= Right (Just (NavEntry (Just "Blog") [] 2 "/blog" (Language "ja")))
            , testCase "keeps HTML in the label and reads the language" $
                parse (set "nav" "'<i>Es</i>critos'" $ set "language" "es" navPage)
                    @?= Right (Just (NavEntry (Just "<i>Es</i>critos") [] 2 "/blog" (Language "es")))
            , testCase "reads a map of language labels" $
                parse labelsPage
                    @?= Right (Just (NavEntry Nothing [(Language "en", "Guides"), (Language "es", "Guías")] 2 "/blog" (Language "en")))
            , testCase "gives no entry to a page without a nav label" $
                parse (without ["nav", "navOrder"] navPage) @?= Right Nothing
            , testCase "needs an order when there is a label" $
                parse (without ["navOrder"] navPage) @?= Left ["navOrder: missing"]
            , testCase "needs a path when there is a label" $
                parse (without ["path"] navPage) @?= Left ["path: missing"]
            , testCase "rejects an order that isn't a number" $
                assertBool "expected parsing to fail" (isLeft (parse $ set "navOrder" "first" navPage))
            , testCase "rejects an empty language map" $
                parse (set "nav" "{}" navPage)
                    @?= Left ["nav: expected at least one language label (like nav: {en: Guides})"]
            , testCase "rejects an invalid language key" $
                assertBool "expected parsing to fail" (problem "invalid language" (parse $ set "nav" "{english: Blog}" navPage))
            , testCase "reports every invalid language key" $
                case parse $ set "nav" "{english: Blog, spanish: Blog}" navPage of
                    Left problems -> length problems @?= 2
                    Right _ -> assertBool "expected parsing to fail" False
            , testCase "rejects a map label that isn't text" $
                assertBool "expected parsing to fail" (problem "must be text" (parse $ set "nav" "{en: 3}" navPage))
            ]
        , testGroup
            "resolveNavLabel"
            [ testCase "a single label is written in the entry page's language" $
                resolveNavLabel (Language "ja") (Language "en") single
                    @?= Right ("Blog", Language "en")
            , testCase "uses the page's language" $
                resolveNavLabel (Language "es") (Language "en") translated
                    @?= Right ("Guías", Language "es")
            , testCase "falls back to the page's base language" $
                resolveNavLabel (Language "es-MX") (Language "en") translated
                    @?= Right ("Guías", Language "es")
            , testCase "falls back to the site's language" $
                resolveNavLabel (Language "de") (Language "en") translated
                    @?= Right ("Guides", Language "en")
            , testCase "falls back to the site's base language" $
                resolveNavLabel (Language "de") (Language "es-MX") translated
                    @?= Right ("Guías", Language "es")
            , testCase "fails, naming the page language and the available ones" $
                resolveNavLabel (Language "de") (Language "fr") translated
                    @?= Left "nav: no label for page language 'de' (available: en, es)"
            ]
        ]
  where
    parse = parseNavYaml defaultLanguage . render
    problem needle = \case
        Left problems -> any (needle `isInfixOf`) problems
        Right _ -> False
    single = NavEntry (Just "Blog") [] 2 "/blog" (Language "en")
    translated = NavEntry Nothing [(Language "en", "Guides"), (Language "es", "Guías")] 2 "/guides" (Language "en")
