-- | Tests for the jōyō coverage check
module Cozyll.RubySpec (tests) where

import Cozyll.Domain.Website (CheckMode (..), parseCheckMode)
import Cozyll.Ruby (checkKanjiCoverage)
import Cozyll.Ruby.Index (Index (..), KanjiRow (..), RubyData, toRubyData)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

tests :: TestTree
tests =
    testGroup
        "Ruby coverage"
        [ testCase "passes when every kanji is jōyō" $ checkKanjiCoverage "ja" [] rubyData "<p>日本語</p>" @?= []
        , testCase "reports bare non-jōyō kanji" $
            checkKanjiCoverage "ja" [] rubyData "<p>薔薇</p>"
                @?= [ "non-jōyō kanji “薔” in “薔薇” has no ruby"
                    , "non-jōyō kanji “薇” in “薔薇” has no ruby"
                    ]
        , testCase "passes when the kanji is inside a ruby base" $
            checkKanjiCoverage "ja" [] rubyData "<p><ruby>薔薇<rt>ばら</rt></ruby></p>" @?= []
        , testCase "ignores non-Japanese pages" $
            checkKanjiCoverage "en" [] rubyData "<p>薔薇</p>" @?= []
        , testCase "checks Japanese spans inside other languages" $
            checkKanjiCoverage "en" [] rubyData "<p><span lang=\"ja\">薔薇</span></p>"
                @?= [ "non-jōyō kanji “薔” in “薔薇” has no ruby"
                    , "non-jōyō kanji “薇” in “薔薇” has no ruby"
                    ]
        , testCase "ignores other CJK languages" $
            checkKanjiCoverage "en" [] rubyData "<p lang=\"zh-Hant\">薔薇</p>" @?= []
        , testCase "ignores code" $ checkKanjiCoverage "ja" [] rubyData "<p><code>薔薇</code></p>" @?= []
        , testCase "ignores rt" $
            checkKanjiCoverage "ja" [] rubyData "<p><ruby>日本<rt>にほん</rt></ruby>薔薇</p>"
                @?= [ "non-jōyō kanji “薔” in “薔薇” has no ruby"
                    , "non-jōyō kanji “薇” in “薔薇” has no ruby"
                    ]
        , testCase "honours jaRubySkip" $ checkKanjiCoverage "ja" ["薔薇"] rubyData "<p>薔薇</p>" @?= []
        , testCase "treats the iteration mark as non-Han" $
            checkKanjiCoverage "ja" [] rubyData "<p>下々</p>" @?= []
        , testCase "parses the check modes" $
            map parseCheckMode ["off", "warn", "error", "x"] @?= [Just CheckOff, Just CheckWarn, Just CheckError, Nothing]
        , testCase "flags JLPT-tagged non-jōyō kanji (jōyō-only policy)" $
            checkKanjiCoverage "ja" [] (toRubyData (Index [KanjiRow '綺' (Just 9) Nothing] [] [])) "<p>綺麗</p>"
                @?= [ "non-jōyō kanji “綺” in “綺麗” has no ruby"
                    , "non-jōyō kanji “麗” in “綺麗” has no ruby"
                    ]
        ]
  where
    rubyData :: RubyData
    rubyData = toRubyData (Index [KanjiRow c (Just 8) Nothing | c <- "日本語下"] [] [])
