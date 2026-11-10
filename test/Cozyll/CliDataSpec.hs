-- | Tests for the @cozyll data@ argument parser
module Cozyll.CliDataSpec (tests) where

import Cozyll.Cli.Data (Command (..), Options (..), parseCommand)
import Data.List (isInfixOf)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertFailure, testCase, (@?=))

tests :: TestTree
tests =
    testGroup
        "Data CLI"
        [ testCase "handles --help" $ parseCommand ["--help"] @?= Right Help
        , testCase "handles --version" $ parseCommand ["--version"] @?= Right Version
        , testCase "handles a subcommand's --help" $ parseCommand ["fetch", "--help"] @?= Right Help
        , testCase "parses fetch options" $
            case parseCommand ["fetch", "--from", "dir", "--check"] of
                Right (Fetch opts) -> do
                    optFrom opts @?= Just "dir"
                    optCheck opts @?= True
                other -> assertFailure ("unexpected: " ++ show other)
        , testCase "parses sources options" $
            case parseCommand ["sources", "--write", "--force", "--resolve"] of
                Right (Sources opts) -> do
                    optWrite opts @?= True
                    optForce opts @?= True
                    optResolve opts @?= True
                other -> assertFailure ("unexpected: " ++ show other)
        , testCase "rejects a flag on the wrong command" $
            case parseCommand ["verify", "--from", "dir"] of
                Left message -> if "is not valid" `isInfixOf` message then pure () else assertFailure message
                Right command -> assertFailure ("unexpected: " ++ show command)
        , testCase "rejects unknown commands" $
            case parseCommand ["bogus"] of
                Left message -> "unknown command: bogus" @?= message
                Right command -> assertFailure ("unexpected: " ++ show command)
        , testCase "rejects positional arguments" $
            case parseCommand ["fetch", "extra"] of
                Left message -> if "unexpected argument" `isInfixOf` message then pure () else assertFailure message
                Right command -> assertFailure ("unexpected: " ++ show command)
        ]
