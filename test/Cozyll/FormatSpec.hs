-- | Tests for the pure formatting helpers
module Cozyll.FormatSpec (tests) where

import Cozyll.Format (postSlug, yearRange)
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
        , testGroup
            "postSlug"
            [ testCase "trims a leading slash and joins segments" $
                postSlug "/blog/el-garson" @?= "blog-el-garson"
            , testCase "joins segments without a leading slash" $
                postSlug "blog/el-garson" @?= "blog-el-garson"
            , testCase "joins a multi-segment path" $
                postSlug "/es/escritos/luz-interrogante" @?= "es-escritos-luz-interrogante"
            , testCase "trims a trailing slash" $
                postSlug "/blog/" @?= "blog"
            , testCase "leaves a bare segment unchanged" $
                postSlug "blog" @?= "blog"
            ]
        ]
