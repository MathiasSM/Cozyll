-- | Tests for reading verification against the segment index
module Cozyll.RubyVerifySpec (tests) where

import Cozyll.Ruby (checkJaReadings)
import Cozyll.Ruby.Index (Index (..), Level (..), RubyData, SegmentRow (..), WordRow (..), toRubyData)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

tests :: TestTree
tests =
    testGroup
        "Ruby verification"
        [ testCase "accepts a whole-word hit" $ checkJaReadings "ja" [] rubyData (ruby "日本語" "にほんご") @?= []
        , testCase "accepts an exact segment" $ checkJaReadings "ja" [] rubyData (ruby "大人" "おとな") @?= []
        , testCase "accepts a multi-segment word" $ checkJaReadings "ja" [] rubyData (ruby "大人買い" "おとながい") @?= []
        , testCase "accepts sokuon" $ checkJaReadings "ja" [] rubyData (ruby "学校" "がっこう") @?= []
        , testCase "accepts rendaku" $ checkJaReadings "ja" [] rubyData (ruby "手紙" "てがみ") @?= []
        , testCase "accepts an iteration mark" $ checkJaReadings "ja" [] rubyData (ruby "下々" "げげ") @?= []
        , testCase "accepts a mixed run" $ checkJaReadings "ja" [] rubyData (ruby "真っ青" "まっさお") @?= []
        , testCase "rejects a mismatched reading" $
            checkJaReadings "ja" [] rubyData (ruby "漢字" "にほんご")
                @?= ["ruby [漢字](-にほんご): reading “にほんご” not attested for “漢字”"]
        , testCase "skips kana-only ruby" $ checkJaReadings "ja" [] rubyData (ruby "カナ" "かな") @?= []
        , testCase "accepts an allowed surface" $ checkJaReadings "ja" ["漢字"] rubyData (ruby "漢字" "にほんご") @?= []
        , testCase "accepts an allowed surface/reading pair" $ checkJaReadings "ja" ["漢字:にほんご"] rubyData (ruby "漢字" "にほんご") @?= []
        , testCase "does not accept a different pair" $
            checkJaReadings "ja" ["漢字:かんじ"] rubyData (ruby "漢字" "にほんご")
                @?= ["ruby [漢字](-にほんご): reading “にほんご” not attested for “漢字”"]
        , testCase "skips ruby in non-Japanese subtrees" $
            checkJaReadings "ja" [] rubyData "<p><span lang=\"zh-Hant\"><ruby>中文<rt>zhōngwén</rt></ruby></span></p>" @?= []
        , testCase "skips ruby on non-Japanese pages" $
            checkJaReadings "en" [] rubyData (ruby "日本語" "にほんご") @?= []
        , testCase "checks a Japanese span on a non-Japanese page" $
            checkJaReadings "en" [] rubyData "<p><span lang=\"ja\"><ruby>漢字<rt>にほんご</rt></ruby></span></p>"
                @?= ["ruby [漢字](-にほんご): reading “にほんご” not attested for “漢字”"]
        ]

ruby :: String -> String -> String
ruby base reading =
    "<p><ruby>" ++ base ++ "<rp>(</rp><rt>" ++ reading ++ "</rt><rp>)</rp></ruby></p>"

rubyData :: RubyData
rubyData =
    toRubyData $
        Index
            []
            [WordRow "日本語" "にほんご" N5]
            [ SegmentRow "大人" "おとな"
            , SegmentRow "買" "が"
            , SegmentRow "学" "がっ"
            , SegmentRow "校" "こう"
            , SegmentRow "手" "て"
            , SegmentRow "紙" "がみ"
            , SegmentRow "下々" "げげ"
            , SegmentRow "時々" "ときどき"
            , SegmentRow "真っ" "まっ"
            , SegmentRow "青" "さお"
            , SegmentRow "薔薇" "ばら"
            ]
