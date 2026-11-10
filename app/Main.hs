{- | Executable entry point.

Pins the process encoding to UTF-8 before touching any site file, so Hakyll's
own reads and writes (and the build's output) do not depend on the ambient
locale, e.g. @LC_ALL=C@.
-}
module Main (main) where

import Cozyll.Cli (cli)
import GHC.IO.Encoding (setLocaleEncoding, utf8)
import System.IO (hSetEncoding, stderr, stdout)

main :: IO ()
main = do
    setLocaleEncoding utf8
    hSetEncoding stdout utf8
    hSetEncoding stderr utf8
    cli
