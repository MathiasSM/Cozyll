-- | Small pure formatting helpers
module Cozyll.Format (postSlug, yearRange) where

{- | Turn a post `path:` (a URL path like @/blog/el-garson@) into an HTML-`id`-safe
slug: leading/trailing slashes removed, inner slashes replaced by hyphens.
-}
postSlug :: String -> String
postSlug path = map slashToDash (trim path)
  where
    trim = reverse . dropWhile (== '/') . reverse . dropWhile (== '/')
    slashToDash '/' = '-'
    slashToDash c = c

-- | A year range: a single year when equal, else @first–last@ (en dash)
yearRange :: Int -> Int -> String
yearRange firstYear lastYear
    | firstYear == lastYear = show firstYear
    | otherwise = show firstYear ++ "–" ++ show lastYear
