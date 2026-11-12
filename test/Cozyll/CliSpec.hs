-- | Tests for the command-line argument classification
module Cozyll.CliSpec (tests) where

import Cozyll.Cli (Invocation (..), invocationFor, parseEnvValue, unsupportedCommand, usageText, versionString)
import Cozyll.Config (Env (..))
import Data.Char (isDigit)
import Data.List (isInfixOf)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, assertFailure, testCase, (@?=))

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
            , testCase "recognises init as its own command, with its arguments" $
                invocationFor ["init", "--dir", "site"] @?= Init ["--dir", "site"]
            , testCase "keeps init --help for the init parser" $
                invocationFor ["init", "--help"] @?= Init ["--help"]
            , testCase "runs the command otherwise" $
                invocationFor ["build"] @?= RunCommand
            , testCase "does not treat a later init as the init command" $
                invocationFor ["build", "init"] @?= RunCommand
            , testCase "recognises the global --help" $
                invocationFor ["--help"] @?= ShowHelp
            , testCase "recognises the global -h" $
                invocationFor ["-h"] @?= ShowHelp
            , testCase "keeps build --help for Hakyll's per-command help" $
                invocationFor ["build", "--help"] @?= RunCommand
            , testCase "keeps data --help for its own parser" $
                invocationFor ["data", "--help"] @?= RunDataArgs ["--help"]
            , testCase "rejects preview with a pointer to watch" $
                invocationFor ["preview"] @?= Reject (unsupportedCommand "preview" "use 'cozyll watch'")
            ]
        , testGroup
            "usageText"
            [ testCase "lists cozyll's own commands" $ do
                assertBool "init" ("init" `isInfixOf` usageText)
                assertBool "data" ("data" `isInfixOf` usageText)
            , testCase "does not list Hakyll's removed commands" $ do
                assertBool "no deploy" (not ("deploy" `isInfixOf` usageText))
                assertBool "no preview" (not ("preview" `isInfixOf` usageText))
            ]
        , testGroup
            "unsupportedCommand"
            [ testCase "deploy names the replacement" $
                unsupportedCommand "deploy" "publish _site/ with your own tooling"
                    @?= "error: cozyll has no deploy command; publish _site/ with your own tooling"
            , testCase "preview points at watch" $
                unsupportedCommand "preview" "use 'cozyll watch'"
                    @?= "error: cozyll has no preview command; use 'cozyll watch'"
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
        , testGroup
            "parseEnvValue"
            [ testCase "defaults an unset SITE_ENV to prod" $
                parseEnvValue Nothing @?= Right Prod
            , testCase "parses prod" $
                parseEnvValue (Just "prod") @?= Right Prod
            , testCase "parses dev" $
                parseEnvValue (Just "dev") @?= Right Dev
            , testCase "parses example" $
                parseEnvValue (Just "example") @?= Right Example
            , testCase "reports unknown values" $
                case parseEnvValue (Just "bogus") of
                    Left message -> assertBool "names the variable" ("SITE_ENV" `isInfixOf` message)
                    Right _ -> assertFailure "bogus SITE_ENV should be rejected"
            ]
        ]
