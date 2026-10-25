{- | Golden (snapshot) test entrypoint. Unit tests live in @SpecMain.hs@ and
are run as a separate test suite.
-}
module Main (main) where

import Control.Exception (bracket)
import Golden (buildSiteSnapshot, goldenTests, relativeFiles)
import Mf2 (mf2Tests)
import System.Directory (getCurrentDirectory, removePathForcibly)
import Test.Tasty (defaultIngredients, defaultMainWithIngredients, testGroup)
import Test.Tasty.Runners.AntXML (antXMLRunner)

-- | Builds the fixture site snapshot, then runs the golden and microformats2 tests
main :: IO ()
main = do
    root <- getCurrentDirectory
    bracket (buildSiteSnapshot root) (removePathForcibly . fst) $ \(_, snapshotDir) -> do
        files <- relativeFiles snapshotDir
        defaultMainWithIngredients (antXMLRunner : defaultIngredients) $
            testGroup "golden" [goldenTests root snapshotDir files, mf2Tests snapshotDir]
