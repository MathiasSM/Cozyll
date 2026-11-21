{- | Golden (snapshot) test entrypoint. Unit tests live in @SpecMain.hs@ and
are run as a separate test suite.
-}
module Main (main) where

import Control.Exception (bracket)
import Cozyll.Fixture (walkFiles)
import Golden (buildSiteSnapshot, goldenTests)
import System.Directory (getCurrentDirectory, removePathForcibly)
import Test.Tasty (defaultIngredients, defaultMainWithIngredients)
import Test.Tasty.Runners.AntXML (antXMLRunner)

-- | Builds the fixture site snapshot, then runs the golden tests
main :: IO ()
main = do
    root <- getCurrentDirectory
    bracket (buildSiteSnapshot root) (removePathForcibly . fst) $ \(_, snapshotDir) -> do
        files <- walkFiles snapshotDir
        defaultMainWithIngredients (antXMLRunner : defaultIngredients) (goldenTests root snapshotDir files)
