-- | Tests for the ruby filter (conversion contract, escaping, level attributes)
module Cozyll.RubyFilterSpec (tests) where

import Cozyll.Filters (processRubyText, processRubyTextWith)
import Cozyll.Ruby.Index (Index (..), KanjiRow (..), Level (..), RubyData, WordRow (..), toRubyData)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Text.Pandoc (Inline (..), nullAttr)

tests :: TestTree
tests =
    testGroup
        "Ruby filter"
        [ testCase "rewrites the legacy syntax" $
            processRubyText (link "日本語" "-にほんご")
                @?= RawInline "html" "<ruby>日本語<rp>(</rp><rt>にほんご</rt><rp>)</rp></ruby>"
        , testCase "adds a word level" $
            processRubyTextWith (Just rubyData) (link "日本語" "-にほんご")
                @?= RawInline "html" "<ruby data-jlpt=\"n5\" data-jlpt-source=\"word\">日本語<rp>(</rp><rt>にほんご</rt><rp>)</rp></ruby>"
        , testCase "falls back to the hardest kanji" $
            processRubyTextWith (Just rubyData) (link "漢字" "-かんじ")
                @?= RawInline "html" "<ruby data-jlpt=\"n3\" data-jlpt-source=\"kanji\">漢字<rp>(</rp><rt>かんじ</rt><rp>)</rp></ruby>"
        , testCase "marks unknown levels" $
            processRubyTextWith (Just rubyData) (link "薔薇" "-ばら")
                @?= RawInline "html" "<ruby data-jlpt=\"unknown\" data-jlpt-source=\"unknown\">薔薇<rp>(</rp><rt>ばら</rt><rp>)</rp></ruby>"
        , testCase "converts any text/reading pair" $
            processRubyText (link "text" "-rubytext")
                @?= RawInline "html" "<ruby>text<rp>(</rp><rt>rubytext</rt><rp>)</rp></ruby>"
        , testCase "converts a path-like target" $
            processRubyText (link "text" "-relative/path")
                @?= RawInline "html" "<ruby>text<rp>(</rp><rt>relative/path</rt><rp>)</rp></ruby>"
        , testCase "converts a Japanese base with a Latin reading" $
            processRubyText (link "日本" "-abc")
                @?= RawInline "html" "<ruby>日本<rp>(</rp><rt>abc</rt><rp>)</rp></ruby>"
        , testCase "leaves links that do not start with a dash alone" $
            processRubyText (link "text" "relative/path") @?= link "text" "relative/path"
        , testCase "escapes the base" $
            processRubyTextWith (Just rubyData) (link "日&" "-にち")
                @?= RawInline "html" "<ruby data-jlpt=\"n5\" data-jlpt-source=\"kanji\">日&amp;<rp>(</rp><rt>にち</rt><rp>)</rp></ruby>"
        , testCase "accepts a compound reading" $
            processRubyText (link "大人買い" "-おとながい")
                @?= RawInline "html" "<ruby>大人買い<rp>(</rp><rt>おとながい</rt><rp>)</rp></ruby>"
        ]
  where
    link base target = Link nullAttr [Str base] (target, "")

rubyData :: RubyData
rubyData =
    toRubyData $
        Index
            [ KanjiRow '日' (Just 1) (Just N5)
            , KanjiRow '本' (Just 1) (Just N5)
            , KanjiRow '語' (Just 2) (Just N4)
            , KanjiRow '漢' (Just 3) (Just N3)
            , KanjiRow '字' (Just 1) (Just N5)
            ]
            [WordRow "日本語" "にほんご" N5]
            []
