-- | Tests for the shared Pandoc compilation helpers
module Cozyll.CompileSpec (tests) where

import Cozyll.Compile (withSourcePath)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

tests :: TestTree
tests =
    testGroup
        "Compile"
        [ testCase "prefixes each problem with the source path once" $
            withSourcePath "content/writings/x.md" ["a", "b"]
                @?= ["content/writings/x.md: a", "content/writings/x.md: b"]
        ]
