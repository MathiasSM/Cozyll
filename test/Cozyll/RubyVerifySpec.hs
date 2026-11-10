-- | Tests for reading verification against the segment index
module Cozyll.RubyVerifySpec (tests) where

import Cozyll.Ruby (checkReadings)
import Cozyll.Ruby.Index (Index (..), Level (..), RubyData, SegmentRow (..), WordRow (..), toRubyData)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

tests :: TestTree
tests =
    testGroup
        "Ruby verification"
        [ testCase "accepts a whole-word hit" $ checkReadings [] rubyData (ruby "日本語" "にほんご") @?= []
        , testCase "accepts an exact segment" $ checkReadings [] rubyData (ruby "大人" "おとな") @?= []
        , testCase "accepts a multi-segment word" $ checkReadings [] rubyData (ruby "大人買い" "おとながい") @?= []
        , testCase "accepts sokuon" $ checkReadings [] rubyData (ruby "学校" "がっこう") @?= []
        , testCase "accepts rendaku" $ checkReadings [] rubyData (ruby "手紙" "てがみ") @?= []
        , testCase "accepts an iteration mark" $ checkReadings [] rubyData (ruby "下々" "げげ") @?= []
        , testCase "accepts a mixed run" $ checkReadings [] rubyData (ruby "真っ青" "まっさお") @?= []
        , testCase "rejects a mismatched reading" $
            checkReadings [] rubyData (ruby "漢字" "にほんご")
                @?= ["ruby [漢字](-にほんご): reading “にほんご” not attested for “漢字”"]
        , testCase "skips kana-only ruby" $ checkReadings [] rubyData (ruby "カナ" "かな") @?= []
        , testCase "accepts an allowed surface" $ checkReadings ["漢字"] rubyData (ruby "漢字" "にほんご") @?= []
        , testCase "accepts an allowed surface/reading pair" $ checkReadings ["漢字:にほんご"] rubyData (ruby "漢字" "にほんご") @?= []
        , testCase "does not accept a different pair" $
            checkReadings ["漢字:かんじ"] rubyData (ruby "漢字" "にほんご")
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
