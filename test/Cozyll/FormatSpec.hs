-- | Tests for the pure formatting helpers
module Cozyll.FormatSpec (tests) where

import Cozyll.Format (yearRange)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

tests :: TestTree
tests =
    testGroup
        "Format"
        [ testGroup
            "yearRange"
            [ testCase "collapses equal years to one" $
                yearRange 2024 2024 @?= "2024"
            , testCase "renders an earlier-to-later range" $
                yearRange 2020 2026 @?= "2020–2026"
            , testCase "renders a later-to-earlier range as-is" $
                yearRange 2026 2020 @?= "2026–2020"
            ]
        ]
