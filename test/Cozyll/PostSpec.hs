-- | Tests for the post front-matter parser
module Cozyll.PostSpec (tests) where

import Cozyll.Domain.Language (Language (..))
import Cozyll.Domain.Post (Post (..), parsePostYaml)
import Cozyll.TestUtils
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

-- | The least a post needs
validPost :: Fields
validPost = [("title", "A post"), ("date", "2026-10-06"), ("path", "/blog/a-post")]

tests :: TestTree
tests =
    testGroup
        "parsePostYaml"
        [ testCase "accepts a post with only title, date and path" $
            parse validPost
                @?= Right (Post "A post" (day 2026 10 6) "/blog/a-post" (Language "en") Nothing False)
        , testCase "reads language, last modification and draft" $
            parse (set "language" "es" $ set "lastModifiedAt" "2027-01-02" $ set "draft" "true" validPost)
                @?= Right (Post "A post" (day 2026 10 6) "/blog/a-post" (Language "es") (Just (day 2027 1 2)) True)
        , testCase "rejects a lastModifiedAt before the date" $
            parse (set "lastModifiedAt" "2026-09-01" validPost)
                @?= Left ["lastModifiedAt: is before date"]
        , testCase "allows a lastModifiedAt on the date" $
            parse (set "lastModifiedAt" "2026-10-06" validPost)
                @?= Right (Post "A post" (day 2026 10 6) "/blog/a-post" (Language "en") (Just (day 2026 10 6)) False)
        , testCase "ignores keys it doesn't model, even empty ones" $
            parse (set "description" "" $ set "TOC" "true" validPost)
                @?= parse validPost
        , testGroup "requires" $
            [ testCase key $ parse (without [key] validPost) @?= Left [key ++ ": missing"]
            | key <- ["title", "date", "path"]
            ]
        , testCase "rejects a date that doesn't exist" $
            parse (set "date" "2026-13-45" validPost)
                @?= Left ["date: could not parse date: invalid day:(2026,13,45)"]
        , testCase "rejects a malformed language" $
            parse (set "language" "xyz" validPost)
                @?= Left ["language: expected a 2-letter ISO 639-1 code with an optional region, got \"xyz\""]
        , testCase "reports every problem at once, in field order" $
            parse (set "language" "xyz" $ set "date" "2026-13-45" $ without ["title", "path"] validPost)
                @?= Left
                    [ "title: missing"
                    , "date: could not parse date: invalid day:(2026,13,45)"
                    , "path: missing"
                    , "language: expected a 2-letter ISO 639-1 code with an optional region, got \"xyz\""
                    ]
        ]
  where
    parse = parsePostYaml . render
