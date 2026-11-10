-- | Tests for the feed helpers
module Cozyll.FeedSpec (tests) where

import Cozyll.Domain.Feed (absoluteUrl, missingIndexPageMessage)
import Data.List (intercalate)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (testProperty)

-- | The feed tests
tests :: TestTree
tests =
    testGroup
        "Feeds"
        [ testGroup
            "absoluteUrl"
            [ testCase "makes a root-relative URL absolute" $
                absoluteUrl root "/contact" @?= "https://example.org/contact"
            , testCase "keeps an absolute URL" $
                absoluteUrl root "https://other.net/a" @?= "https://other.net/a"
            , testCase "keeps a protocol-relative URL" $
                absoluteUrl root "//cdn.net/a.js" @?= "//cdn.net/a.js"
            , testCase "keeps an anchor, a mailto link and a relative path" $
                map (absoluteUrl root) ["#top", "mailto:me@example.org", "images/a.png"]
                    @?= ["#top", "mailto:me@example.org", "images/a.png"]
            , testProperty "is idempotent" $ \url ->
                absoluteUrl root (absoluteUrl root url) == absoluteUrl root url
            ]
        , testGroup
            "missingIndexPageMessage"
            [ testCase "explains the group convention and the page to create" $
                missingIndexPageMessage "content" "curiosities"
                    @?= intercalate
                        "\n"
                        [ "no index page for the group \"curiosities\": create content/writings/curiosities.md with"
                        , "  index: true"
                        , "  group: curiosities"
                        , "  path: /curiosities"
                        , "(see the README, \"Groups\")"
                        ]
            ]
        ]
  where
    root = "https://example.org"
