-- | Tests for the aside context: control gating and label rendering
module Cozyll.AsideSpec (tests) where

import Cozyll.Context.Aside (hasAnyControl, hasAside, renderInlineMarkdown)
import Cozyll.TestUtils (metadataFromYaml)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

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
            [ testCase "detects the legacy ruby toggle" $
                hasAnyControl (metadataFromYaml "rubyToggle: ふりがな") @?= True
            , testCase "detects a ruby level control" $
                hasAnyControl (metadataFromYaml "rubyControl: ふりがな") @?= True
            , testCase "ignores the removed unknown-ruby key" $
                hasAnyControl (metadataFromYaml "rubyUnknown: unknown") @?= False
            , testCase "detects an images toggle" $
                hasAnyControl (metadataFromYaml "imagesToggle: Images") @?= True
            , testCase "ignores TOC" $
                hasAnyControl (metadataFromYaml "TOC: Contents") @?= False
            , testCase "is false without toggles" $
                hasAnyControl (metadataFromYaml "title: Hello") @?= False
            ]
        , testGroup
            "hasAside"
            [ testCase "true with a toggle" $
                hasAside (metadataFromYaml "rubyControl: ふりがな") @?= True
            , testCase "true with a TOC" $
                hasAside (metadataFromYaml "TOC: Contents") @?= True
            , testCase "false without either" $
                hasAside (metadataFromYaml "title: Hello") @?= False
            ]
        ]
