-- | Tests for the missing-@path:@ preflight
module Cozyll.ValidateSpec (tests) where

import Cozyll.Config (Env (..))
import Cozyll.Rules.Validate (missingPaths)
import Cozyll.TestUtils (metadataJson)
import Data.Aeson (Value (Bool, String))
import Hakyll (Metadata)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

tests :: TestTree
tests =
    testGroup
        "Validate"
        [ testGroup
            "missingPaths"
            [ testCase "reports a page without a path, suggesting its output URL" $
                missingPaths Prod [("content/writings/foo.md", withoutPath)]
                    @?= ["content/writings/foo.md: add `path: /foo` (the output URL)"]
            , testCase "suggests a nested path from the file's folder" $
                missingPaths Prod [("content/writings/group/post.md", withoutPath)]
                    @?= ["content/writings/group/post.md: add `path: /group/post` (the output URL)"]
            , testCase "accepts an item that has a path" $
                missingPaths Prod [("content/writings/foo.md", withPath)] @?= []
            , testCase "skips a hidden draft in prod" $
                missingPaths Prod [("content/writings/foo.md", draftWithoutPath)] @?= []
            , testCase "reports a draft in dev, where it is built" $
                missingPaths Dev [("content/writings/foo.md", draftWithoutPath)]
                    @?= ["content/writings/foo.md: add `path: /foo` (the output URL)"]
            ]
        ]

withoutPath :: Metadata
withoutPath = metadataJson [("title", String "Foo")]

withPath :: Metadata
withPath = metadataJson [("title", String "Foo"), ("path", String "/foo")]

draftWithoutPath :: Metadata
draftWithoutPath = metadataJson [("title", String "Foo"), ("draft", Bool True)]
