-- | Small pure formatting helpers
module Cozyll.Format (yearRange) where

-- | A year range: a single year when equal, else @first–last@ (en dash)
yearRange :: Int -> Int -> String
yearRange first last
    | first == last = show first
    | otherwise = show first ++ "–" ++ show last
