-- | Tests for the front-matter keys
module Cozyll.MetadataSpec (tests) where

import Cozyll.Metadata (Key (..), keyName)
import Data.List (nub)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))

-- | The metadata-key tests
tests :: TestTree
tests =
    testGroup
        "Metadata"
        [ testGroup
            "keyName"
            [ testCase "spells keys as they appear in front matter" $
                map keyName [Title, StartDate, ShortDescription, TOC, RubyToggle, RubyControl, ImagesToggle]
                    @?= ["title", "startDate", "shortDescription", "TOC", "rubyToggle", "rubyControl", "imagesToggle"]
            , testCase "no longer knows the removed unknown-ruby key"
                $ assertBool "rubyUnknown still has a spelling"
                $ "rubyUnknown" `notElem` map keyName [minBound .. maxBound]
            , testCase "gives every key a different spelling" $
                let spellings = map keyName [minBound .. maxBound]
                 in length (nub spellings) @?= length spellings
            ]
        ]
