-- | Site paths shared by the publication rules and brand resolution
module Cozyll.Paths (mediaTarget) where

import Data.List (stripPrefix)
import Data.Maybe (fromMaybe)
import System.FilePath.Posix (addTrailingPathSeparator, (</>))

{- | The site path a media identifier is published at:

| source | published |
|---|---|
| @media\/photos\/x.png@ | @images\/photos\/x.png@ |
| @media\/icons\/x.svg@ | @images\/icons\/x.svg@ |
| @media\/branding\/x@ | @images\/x@ |
| @media\/<any>\/x@ | @images\/<any>\/x@ |
| @media\/x@ | @images\/x@ |

@branding\/@ is the one flattening special case, so the logo stays at
@images\/logo.svg@.
-}
mediaTarget :: FilePath -> FilePath -> FilePath
mediaTarget mediaDir' path =
    let rest = fromMaybe path (stripPrefix (addTrailingPathSeparator mediaDir') path)
     in "images" </> fromMaybe rest (stripPrefix "branding/" rest)
