-- | Tests for the front-matter queries and aliases
module Cozyll.ContentSpec (tests) where

import Cozyll.Config (Env (..))
import Cozyll.Content (isHidden, parseAliasesYaml, tocLabelOf)
import Cozyll.TestUtils (assertFails, metadata, metadataJson)
import Data.Aeson (Value (Bool))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

tests :: TestTree
tests =
    testGroup
        "Content"
        [ isHiddenTests
        , aliasTests
        , tocLabelOfTests
        ]

-- Draft visibility -----------------------------------------------------------

isHiddenTests :: TestTree
isHiddenTests =
    testGroup
        "isHidden"
        [ testCase "hides a draft in prod" $
            isHidden Prod draftMetadata @?= True
        , testCase "hides a draft in example" $
            isHidden Example draftMetadata @?= True
        , testCase "shows a draft in dev" $
            isHidden Dev draftMetadata @?= False
        , testCase "shows a non-draft in prod" $
            isHidden Prod nonDraftMetadata @?= False
        ]
  where
    draftMetadata = metadataJson [("draft", Bool True)]
    nonDraftMetadata = metadataJson [("title", Bool False)]

-- Aliases --------------------------------------------------------------------

aliasTests :: TestTree
aliasTests =
    testGroup
        "parseAliasesYaml"
        [ testCase "reads a list" $
            parseAliasesYaml "aliases: [/old, /older/place]" @?= Right ["/old", "/older/place"]
        , testCase "reads a single string" $
            parseAliasesYaml "aliases: /old" @?= Right ["/old"]
        , testCase "is empty when there are none" $
            parseAliasesYaml "title: x" @?= Right []
        , testCase "rejects an alias without a leading slash" $
            parseAliasesYaml "aliases: [old]" @?= Left ["aliases: \"old\" must start with / (like /old-name)"]
        , testCase "rejects the home page" $
            parseAliasesYaml "aliases: [/]" @?= Left ["aliases: / is the home page, it can't be an alias"]
        , testCase "rejects something that isn't text" $
            assertFails (parseAliasesYaml "aliases: 3")
        ]

-- Table of contents label ----------------------------------------------------

tocLabelOfTests :: TestTree
tocLabelOfTests =
    testGroup
        "tocLabelOf"
        [ testCase "reads the label" $
            tocLabelOf (metadata [("TOC", "Contents")]) @?= Just "Contents"
        , testCase "reads a custom label" $
            tocLabelOf (metadata [("TOC", "Table of contents")]) @?= Just "Table of contents"
        , testCase "is nothing for an empty label" $
            tocLabelOf (metadata [("TOC", "")]) @?= Nothing
        , testCase "is nothing without a TOC" $
            tocLabelOf (metadata [("title", "x")]) @?= Nothing
        ]
