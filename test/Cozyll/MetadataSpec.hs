-- | Tests for the front-matter keys
module Cozyll.MetadataSpec (tests) where

import Cozyll.Metadata (Key (..), keyName)
import Data.List (nub)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

-- | The metadata-key tests
tests :: TestTree
tests =
    testGroup
        "Metadata"
        [ testGroup
            "keyName"
            [ testCase "spells keys as they appear in front matter" $
                map keyName [Title, StartDate, ShortDescription, TOC, RubyToggle, ImagesToggle]
                    @?= ["title", "startDate", "shortDescription", "TOC", "rubyToggle", "imagesToggle"]
            , testCase "gives every key a different spelling" $
                let spellings = map keyName [minBound .. maxBound]
                 in length (nub spellings) @?= length spellings
            ]
        ]
