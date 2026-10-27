-- | Small helpers that keep the specs short and readable
module Cozyll.TestUtils (
    Fields,
    render,
    one,
    set,
    without,
    day,
    mkAuthor,
)
where

import Cozyll.Domain.Author (Author (..), AuthorType (..))
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Time (Day, fromGregorian)

{- | Key/value pairs for building YAML (project files, post front matter).

Start from a valid fixture and change one thing per test with 'set' and 'without'.
-}
type Fields = [(String, String)]

-- | The fields as YAML text, one @key: value@ per line
render :: Fields -> String
render fields = unlines [key ++ ": " ++ value | (key, value) <- fields]

-- | The fields as a single-element YAML list (for the list parsers)
one :: Fields -> String
one [] = "- {}"
one ((key, value) : rest) =
    "- " ++ key ++ ": " ++ value ++ concat ["\n  " ++ k ++ ": " ++ v | (k, v) <- rest]

-- | Replaces a field's value, or adds the field
set :: String -> String -> Fields -> Fields
set key value fields
    | key `elem` map fst fields = [(k, if k == key then value else v) | (k, v) <- fields]
    | otherwise = fields ++ [(key, value)]

-- | Drops fields by name
without :: [String] -> Fields -> Fields
without keys = filter ((`notElem` keys) . fst)

-- | A date from year, month and day
day :: Integer -> Int -> Int -> Day
day = fromGregorian

-- | A minimal site-default author for fixtures
mkAuthor :: String -> Author
mkAuthor name =
    Author
        { authorId = "example"
        , authorName = name
        , authorType = Person
        , authorSiteDefault = True
        , authorDisplayName = Nothing
        , authorDescription = Nothing
        , authorProfileImage = Nothing
        , authorLinks = []
        , authorAddCopyrightNotice = False
        , authorExtra = []
        , authorRaw = KeyMap.empty
        }
