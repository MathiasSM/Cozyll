-- | Tests for the socials YAML list parser
module Cozyll.SocialSpec (tests) where

import Cozyll.Domain.Social (Social (..), parseSocialsYaml)
import Cozyll.TestUtils
import Data.Either (isLeft)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))

-- | A social account with every field except the optional _show flag
validSocial :: Fields
validSocial = [("icon", "twitter"), ("href", "https://x.com/example"), ("username", "example")]

tests :: TestTree
tests =
    testGroup
        "parseSocialsYaml"
        [ testCase "reads an account, shown by default" $
            parse validSocial
                @?= Right [Social "twitter" "https://x.com/example" "example" True]
        , testCase "hides when _show is false" $
            parse (set "_show" "false" validSocial)
                @?= Right [Social "twitter" "https://x.com/example" "example" False]
        , testCase "reads a list of accounts in order" $
            parseSocialsYaml
                ( unlines
                    [ "- icon: twitter"
                    , "  href: https://x.com/example"
                    , "  username: example"
                    , "- icon: github"
                    , "  href: https://github.com/example"
                    , "  username: example"
                    ]
                )
                @?= Right
                    [ Social "twitter" "https://x.com/example" "example" True
                    , Social "github" "https://github.com/example" "example" True
                    ]
        , testCase "ignores fields it doesn't model" $
            parse (set "cta" "x" validSocial) @?= parse validSocial
        , testGroup "requires" $
            [ testCase key $ parse (without [key] validSocial) @?= Left ["social #0: " ++ key ++ ": missing"]
            | key <- ["icon", "href", "username"]
            ]
        , testCase "reports every account's problems, prefixed by index" $
            parseSocialsYaml (unlines ["- href: /a", "- icon: b"])
                @?= Left
                    [ "social #0: icon: missing"
                    , "social #0: username: missing"
                    , "social #1: href: missing"
                    , "social #1: username: missing"
                    ]
        , testCase "rejects text that isn't a YAML list of objects" $
            assertBool "expected parsing to fail" (isLeft (parseSocialsYaml "icon: ["))
        ]
  where
    parse = parseSocialsYaml . one
