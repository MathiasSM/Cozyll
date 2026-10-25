-- | Tests for the front-matter queries and aliases
module Cozyll.ContentSpec (tests) where

import Cozyll.Config (Env (..))
import Cozyll.Content (isHidden, parseAliasesYaml, tocLabelOf)
import Data.Aeson (Value (Bool, String))
import Data.Aeson.Key (fromString)
import Data.Aeson.KeyMap qualified as KM
import Data.Either (isLeft)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))

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
    draftMetadata = KM.singleton (fromString "draft") (Bool True)
    nonDraftMetadata = KM.singleton (fromString "title") (Bool False)

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
            assertBool "expected parsing to fail" (isLeft (parseAliasesYaml "aliases: 3"))
        ]

-- Table of contents label ----------------------------------------------------

tocLabelOfTests :: TestTree
tocLabelOfTests =
    testGroup
        "tocLabelOf"
        [ testCase "reads the label" $
            tocLabelOf (KM.singleton (fromString "TOC") (String "Contents")) @?= Just "Contents"
        , testCase "reads a custom label" $
            tocLabelOf (KM.singleton (fromString "TOC") (String "Table of contents")) @?= Just "Table of contents"
        , testCase "is nothing for an empty label" $
            tocLabelOf (KM.singleton (fromString "TOC") (String "")) @?= Nothing
        , testCase "is nothing without a TOC" $
            tocLabelOf (KM.singleton (fromString "title") (String "x")) @?= Nothing
        ]
