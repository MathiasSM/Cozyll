-- | Small pure formatting helpers
module Cozyll.Format (yearRange) where

-- | A year range: a single year when equal, else @first–last@ (en dash)
yearRange :: Int -> Int -> String
yearRange firstYear lastYear
    | firstYear == lastYear = show firstYear
    | otherwise = show firstYear ++ "–" ++ show lastYear
