-- | The @cozyll data@ subcommands: fetch/verify/fmt/manifest
module Main (main) where

import Cozyll.Cli (cli)
import DataCommand (runDataCommand)
import System.Environment (getArgs)

main :: IO ()
main = do
    args <- getArgs
    case args of
        ("data" : rest) -> runDataCommand rest
        _ -> cli
