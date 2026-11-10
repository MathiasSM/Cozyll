-- | Tests for the menu-entry front-matter parser and its page-language marking
module Cozyll.NavSpec (tests) where

import Cozyll.Context.Nav (navEntryLang)
import Cozyll.Domain.Language (Language (..))
import Cozyll.Domain.Nav (NavEntry (..), parseNavYaml)
import Cozyll.TestUtils
import Data.Either (isLeft)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))

-- | A page that wants a menu entry
navPage :: Fields
navPage = [("title", "Blog"), ("path", "/blog"), ("nav", "Blog"), ("navOrder", "2")]

tests :: TestTree
tests =
    testGroup
        "Nav"
        [ testGroup
            "parseNavYaml"
            [ testCase "reads label, order, path and language (English unless stated)" $
                parse navPage @?= Right (Just (NavEntry "Blog" 2 "/blog" (Language "en")))
            , testCase "keeps HTML in the label and reads the language" $
                parse (set "nav" "'<i>Es</i>critos'" $ set "language" "es" navPage)
                    @?= Right (Just (NavEntry "<i>Es</i>critos" 2 "/blog" (Language "es")))
            , testCase "gives no entry to a page without a nav label" $
                parse (without ["nav", "navOrder"] navPage) @?= Right Nothing
            , testCase "needs an order when there is a label" $
                parse (without ["navOrder"] navPage) @?= Left ["navOrder: missing"]
            , testCase "needs a path when there is a label" $
                parse (without ["path"] navPage) @?= Left ["path: missing"]
            , testCase "rejects an order that isn't a number" $
                assertBool "expected parsing to fail" (isLeft (parse $ set "navOrder" "first" navPage))
            ]
        , testGroup
            "navEntryLang"
            [ testCase "marks an English entry on a Japanese page" $
                navEntryLang "ja" (entry (Language "en")) @?= Just "en"
            , testCase "marks a Japanese entry on an English page" $
                navEntryLang "en" (entry (Language "ja")) @?= Just "ja"
            , testCase "leaves an entry in the page's own language unmarked" $
                navEntryLang "ja" (entry (Language "ja")) @?= Nothing
            ]
        ]
  where
    parse = parseNavYaml . render
    entry = NavEntry "Blog" 2 "/blog"
