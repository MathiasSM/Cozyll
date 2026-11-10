-- | Tests for the command-line argument classification
module Cozyll.CliSpec (tests) where

import Cozyll.Cli (Invocation (..), invocationFor, versionString)
import Data.Char (isDigit)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))

-- | The CLI tests
tests :: TestTree
tests =
    testGroup
        "Cli"
        [ testGroup
            "invocationFor"
            [ testCase "prints the help when there are no arguments" $
                invocationFor [] @?= ShowHelp
            , testCase "recognises --version as the only argument" $
                invocationFor ["--version"] @?= ShowVersion
            , testCase "recognises -V as the only argument" $
                invocationFor ["-V"] @?= ShowVersion
            , testCase "leaves the data command for its own handler" $
                invocationFor ["data", "fetch"] @?= RunDataArgs ["fetch"]
            , testCase "does not treat --version followed by a command as a version request" $
                invocationFor ["--version", "build"] @?= RunCommand
            , testCase "runs the command otherwise" $
                invocationFor ["build"] @?= RunCommand
            ]
        , testGroup
            "versionString"
            [ testCase "starts with the program name" $
                take 7 versionString @?= "cozyll "
            , testCase "ends with a dotted version number" $ do
                let v = drop 7 versionString
                assertBool "version is not empty" (not (null v))
                assertBool "version only has digits and dots" (all (\c -> isDigit c || c == '.') v)
            ]
        ]
