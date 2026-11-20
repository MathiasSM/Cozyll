-- | Reporting for the rule-set checks that collect every problem before failing
module Cozyll.Rules.Common (failIfAny) where

import Control.Monad (unless)
import Hakyll (Rules, preprocess)

-- | Fails the build with a header and one indented line per problem; no-op on []
failIfAny :: String -> [String] -> Rules ()
failIfAny header problems =
    unless
        (null problems)
        $ preprocess
        $ ioError
        $ userError
        $ header ++ ":\n" ++ unlines (map ("  " ++) problems)
