{-# LANGUAGE Trustworthy #-}

-- | Clean URLs: routing and the stripping of the @index.html@ suffix
module Cozyll.CleanURL (outputPath, pathRoute, cleanIndex, cleanIndexUrls, cleanIndexHtmls) where

import Cozyll.Metadata (Key (Path), lookupKey)
import Cozyll.Paths (stripLeadingSlashes)
import Data.List (isSuffixOf)
import Hakyll (Compiler, Item, Metadata, Routes, customRoute, replaceAll, toFilePath, withUrls)
import System.FilePath.Posix (takeExtension, (</>))

{- | The output file for a public path: `/contact` becomes `contact/index.html`,
while a path with an extension (like `/404.html`) is kept as is.
-}
outputPath :: FilePath -> FilePath
outputPath path
    | null (takeExtension path) = withoutSlash </> "index.html"
    | otherwise = withoutSlash
  where
    withoutSlash = stripLeadingSlashes path

-- | Route from the `path:` front matter, laid out by 'outputPath'
pathRoute :: Metadata -> Routes
pathRoute metadata = case lookupKey Path metadata of
    Nothing -> customRoute $ \ident -> error $ "Missing `path` in " ++ toFilePath ident
    Just path -> customRoute $ const $ outputPath path

-- | Cleans all URLs
cleanIndexUrls :: Item String -> Compiler (Item String)
cleanIndexUrls = return . fmap (withUrls cleanIndex)

-- | Cleans all instances of /index, that might not be a recognized as a URL
cleanIndexHtmls :: Item String -> Compiler (Item String)
cleanIndexHtmls = return . fmap (replaceAll indexPattern replacement)
  where
    indexPattern = "/index.html"
    replacement = const ""

-- | Strips a URL of its index.html suffix
cleanIndex :: String -> String
cleanIndex url
    | idx == url = "/"
    | idx `isSuffixOf` url = take (length url - length idx) url
    | otherwise = url
  where
    idx = "/index.html"
