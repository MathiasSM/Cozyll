-- | Tests for the pure JSON-LD building blocks
module Cozyll.JsonLdSpec (tests) where

import Cozyll.JsonLd (articleId, authorId, context, graph, idRef, organizationId, render, websiteId)
import Data.Aeson (Value (Object, String), (.=))
import Data.Aeson.Key qualified as AesonKey
import Data.Aeson.KeyMap qualified as KeyMap
import Data.List (isInfixOf)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

tests :: TestTree
tests =
    testGroup
        "JsonLd"
        [ identifierTests
        , idRefTests
        , contextTests
        , graphTests
        , renderTests
        ]

identifierTests :: TestTree
identifierTests =
    testGroup
        "identifiers"
        [ testCase "websiteId appends the website fragment" $
            websiteId "https://example.com/" @?= "https://example.com/#website"
        , testCase "organizationId appends the organization fragment" $
            organizationId "https://example.com/" @?= "https://example.com/#organization"
        , testCase "authorId points at the author's person node" $
            authorId "https://example.com/" "mathias" @?= "https://example.com/authors/mathias/#person"
        , testCase "articleId appends the article fragment" $
            articleId "https://example.com/prose/tour/" @?= "https://example.com/prose/tour/#article"
        ]

idRefTests :: TestTree
idRefTests =
    testGroup
        "idRef"
        [ testCase "is an object holding only an @id" $
            idRef "https://example.com/#website"
                @?= Object (KeyMap.singleton (AesonKey.fromText "@id") (String "https://example.com/#website"))
        ]

contextTests :: TestTree
contextTests =
    testGroup
        "context"
        [ testCase "is the schema.org context" $
            render context @?= "{\"@context\":\"https://schema.org\"}"
        ]

graphTests :: TestTree
graphTests =
    testGroup
        "graph"
        [ testCase "wraps nodes in a @graph document" $
            render (graph []) @?= "{\"@context\":\"https://schema.org\",\"@graph\":[]}"
        , testCase "keeps the context before the graph" $
            render (graph ["@type" .= ("Thing" :: String)])
                @?= "{\"@context\":\"https://schema.org\",\"@graph\":[{\"@type\":\"Thing\"}]}"
        ]

renderTests :: TestTree
renderTests =
    testGroup
        "render"
        [ testCase "escapes the characters that would close a script element" $
            "\\u003c" `isInfixOf` render ("x" .= ("<" :: String)) @?= True
        , testCase "escapes a whole tag" $
            "\\u003c\\u0026\\u003e" `isInfixOf` render ("x" .= ("<&>" :: String)) @?= True
        , testCase "leaves ordinary characters alone" $
            render ("x" .= ("plain" :: String)) @?= "{\"x\":\"plain\"}"
        ]
