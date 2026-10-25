-- | Tests for the aside context: control gating and label rendering
module Cozyll.AsideSpec (tests) where

import Cozyll.Context.Aside (hasAnyControl, hasAside, renderInlineMarkdown)
import Cozyll.Yaml (decodeYaml)
import Hakyll (Metadata)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

-- | Parses a front-matter YAML fragment into the 'Metadata' the contexts read
metadata :: String -> Metadata
metadata yaml = case (decodeYaml yaml :: Either [String] Metadata) of
    Right m -> m
    Left problems -> error (unlines problems)

tests :: TestTree
tests =
    testGroup
        "Aside"
        [ testGroup
            "renderInlineMarkdown"
            [ testCase "leaves plain text as-is" $
                renderInlineMarkdown "Images" @?= "Images"
            , testCase "renders a bracketed span with its attributes" $
                renderInlineMarkdown "[ふりがな]{lang=ja}" @?= "<span lang=\"ja\">ふりがな</span>"
            , testCase "renders emphasis" $
                renderInlineMarkdown "**bold**" @?= "<strong>bold</strong>"
            ]
        , testGroup
            "hasAnyControl"
            [ testCase "detects a ruby toggle" $
                hasAnyControl (metadata "rubyToggle: ふりがな") @?= True
            , testCase "detects an images toggle" $
                hasAnyControl (metadata "imagesToggle: Images") @?= True
            , testCase "ignores TOC" $
                hasAnyControl (metadata "TOC: Contents") @?= False
            , testCase "is false without toggles" $
                hasAnyControl (metadata "title: Hello") @?= False
            ]
        , testGroup
            "hasAside"
            [ testCase "true with a toggle" $
                hasAside (metadata "rubyToggle: ふりがな") @?= True
            , testCase "true with a TOC" $
                hasAside (metadata "TOC: Contents") @?= True
            , testCase "false without either" $
                hasAside (metadata "title: Hello") @?= False
            ]
        ]
