-- | Small pure formatting helpers
module Cozyll.Format (postSlug, yearRange, yearOf, parseDay) where

import Cozyll.Paths (stripLeadingSlashes)
import Data.Time (Day, defaultTimeLocale)
import Data.Time.Format (parseTimeM)
import Text.Read (readMaybe)

{- | Turn a post `path:` (a URL path like @/blog/el-garson@) into an HTML-`id`-safe
slug: leading/trailing slashes removed, inner slashes replaced by hyphens.
-}
postSlug :: String -> String
postSlug path = map slashToDash (trim path)
  where
    trim = reverse . dropWhile (== '/') . reverse . stripLeadingSlashes
    slashToDash '/' = '-'
    slashToDash c = c

-- | A year range: a single year when equal, else @first–last@ (en dash)
yearRange :: Int -> Int -> String
yearRange firstYear lastYear
    | firstYear == lastYear = show firstYear
    | otherwise = show firstYear ++ "–" ++ show lastYear

-- | The year of a @YYYY-MM-DD@ value
yearOf :: String -> Maybe Int
yearOf = readMaybe . take 4

-- | A @YYYY-MM-DD@ value
parseDay :: String -> Maybe Day
parseDay = parseTimeM True defaultTimeLocale "%Y-%m-%d"
