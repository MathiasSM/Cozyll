{-# LANGUAGE OverloadedStrings #-}

-- | Authors, as read from @authors.yaml@ in the content repo
module Cozyll.Domain.Author (
    Author (..),
    AuthorType (..),
    parseAuthorsYaml,
    loadAuthors,
    defaultAuthor,
    authorUrlPath,
) where

import Control.Monad (unless)
import Cozyll.Yaml (Check (..), decodeYaml)
import Data.Aeson (Object, Value (..))
import Data.Aeson.Key (Key, fromString, toString)
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Char (isAsciiLower, isDigit)
import Data.Foldable (toList)
import Data.Scientific (Scientific, floatingOrInteger)
import Data.Text qualified as T
import System.Directory (doesFileExist)
import System.Exit (die)
import System.FilePath.Posix ((</>))

-- | Whether an author is a person or an organization
data AuthorType = Person | Organization
    deriving (Eq, Show, Enum, Bounded)

-- | An author, keyed by its id in @authors.yaml@
data Author = Author
    { authorId :: String
    , authorName :: String
    , authorType :: AuthorType
    , authorSiteDefault :: Bool
    , authorDisplayName :: Maybe String
    , authorDescription :: Maybe String
    , authorProfileImage :: Maybe String
    , authorLinks :: [String]
    , authorAddCopyrightNotice :: Bool
    , authorExtra :: [(String, String)]
    -- ^ Scalar extra fields, for the DOM
    , authorRaw :: Object
    -- ^ The whole object, for JSON-LD passthrough
    }
    deriving (Eq, Show)

-- | Parses @authors.yaml@, reporting every problem (not just the first)
parseAuthorsYaml :: String -> Either [String] [Author]
parseAuthorsYaml text = do
    value <- decodeYaml text
    case value of
        Object object
            | KeyMap.null object -> Left ["authors.yaml: expected a non-empty map keyed by author id"]
            | otherwise -> do
                authors <- traverse (uncurry parseAuthor) (KeyMap.toList object)
                _ <- defaultAuthor authors
                pure authors
        _ -> Left ["authors.yaml: expected a map keyed by author id"]

-- | Reads and parses @<contentDir>/authors.yaml@, failing with a clear message
loadAuthors :: FilePath -> IO [Author]
loadAuthors contentDir = do
    let path = contentDir </> "authors.yaml"
    exists <- doesFileExist path
    unless exists $ die $ path ++ " not found"
    result <- readFile path
    either (\problems -> die $ "Invalid " ++ path ++ ":\n" ++ unlines problems) pure (parseAuthorsYaml result)

-- | The author marked @siteDefault: true@ (exactly one is required)
defaultAuthor :: [Author] -> Either [String] Author
defaultAuthor authors = case [author | author <- authors, authorSiteDefault author] of
    [author] -> Right author
    [] -> Left ["authors.yaml: exactly one author must set siteDefault: true (found none)"]
    defaults -> Left ["authors.yaml: exactly one author must set siteDefault: true (found " ++ show (length defaults) ++ ")"]

-- | The canonical URL path of an author's page
authorUrlPath :: Author -> FilePath
authorUrlPath author = "/authors/" ++ authorId author ++ "/"

-- | Parses one author object, prefixed by its id
parseAuthor :: Key -> Value -> Either [String] Author
parseAuthor key value = case value of
    Object object ->
        let slug = toString key
         in runCheck $
                Author slug
                    <$> requiredString slug "name" object
                    <*> optionalType slug object
                    <*> optionalBool slug "siteDefault" object
                    <*> optionalString slug "displayName" object
                    <*> optionalString slug "description" object
                    <*> optionalNonEmptyString slug "profileImage" object
                    <*> optionalStringList slug "links" object
                    <*> optionalBool slug "addCopyrightNotice" object
                    <*> pure (scalarExtras object)
                    <*> pure object
                    <* checkId slug
    _ -> Left [prefix (toString key) "expected an object"]

-- | A required non-empty string field
requiredString :: String -> String -> Object -> Check String
requiredString slug field object = Check $ case KeyMap.lookup (fromString field) object of
    Just (String text)
        | not (T.null text) -> Right (T.unpack text)
        | otherwise -> Left [prefix slug (field ++ ": empty")]
    Just _ -> Left [prefix slug (field ++ ": expected a string")]
    Nothing -> Left [prefix slug (field ++ ": missing")]

-- | An optional string field (absent or null means Nothing)
optionalString :: String -> String -> Object -> Check (Maybe String)
optionalString slug field object = Check $ case KeyMap.lookup (fromString field) object of
    Nothing -> Right Nothing
    Just Null -> Right Nothing
    Just (String text) -> Right (Just (T.unpack text))
    Just _ -> Left [prefix slug (field ++ ": expected a string")]

-- | An optional non-empty string field
optionalNonEmptyString :: String -> String -> Object -> Check (Maybe String)
optionalNonEmptyString slug field object = Check $ case KeyMap.lookup (fromString field) object of
    Nothing -> Right Nothing
    Just Null -> Right Nothing
    Just (String text)
        | T.null text -> Left [prefix slug (field ++ ": empty")]
        | otherwise -> Right (Just (T.unpack text))
    Just _ -> Left [prefix slug (field ++ ": expected a string")]

-- | An optional boolean field (absent or null means False)
optionalBool :: String -> String -> Object -> Check Bool
optionalBool slug field object = Check $ case KeyMap.lookup (fromString field) object of
    Nothing -> Right False
    Just Null -> Right False
    Just (Bool b) -> Right b
    Just _ -> Left [prefix slug (field ++ ": expected a boolean")]

-- | An optional list of non-empty strings
optionalStringList :: String -> String -> Object -> Check [String]
optionalStringList slug field object = Check $ case KeyMap.lookup (fromString field) object of
    Nothing -> Right []
    Just Null -> Right []
    Just (Array items) ->
        let numbered = zip [0 :: Int ..] (toList items)
            problems =
                concat
                    [ [prefix slug (field ++ "[" ++ show index ++ "]: expected a non-empty string") | not (isNonEmptyString item)]
                    | (index, item) <- numbered
                    ]
            values = [T.unpack text | String text <- map snd numbered, not (T.null text)]
         in if null problems then Right values else Left problems
    Just _ -> Left [prefix slug (field ++ ": expected a list")]

-- | The author type (defaults to Person)
optionalType :: String -> Object -> Check AuthorType
optionalType slug object = Check $ case KeyMap.lookup (fromString "type") object of
    Nothing -> Right Person
    Just Null -> Right Person
    Just (String text) -> case T.unpack text of
        "person" -> Right Person
        "organization" -> Right Organization
        other -> Left [prefix slug ("type: unknown \"" ++ other ++ "\" (expected person or organization)")]
    Just _ -> Left [prefix slug "type: expected a string"]

-- | Fails when the id is not a valid slug
checkId :: String -> Check ()
checkId slug = Check $ if validId slug then Right () else Left [prefix slug "invalid id (expected lowercase letters, digits, and hyphens, starting with a letter or digit)"]

-- | The scalar extra fields (everything not modelled), as strings
scalarExtras :: Object -> [(String, String)]
scalarExtras object =
    [ (toString key, rendered)
    | (key, value) <- KeyMap.toList object
    , toString key `notElem` knownFields
    , Just rendered <- [scalarString value]
    ]
  where
    knownFields = ["name", "type", "siteDefault", "displayName", "description", "profileImage", "links", "addCopyrightNotice"]

-- | The text of a scalar value, if it is one
scalarString :: Value -> Maybe String
scalarString = \case
    String text -> Just $ T.unpack text
    Number n -> Just $ renderNumber n
    Bool b -> Just $ if b then "true" else "false"
    Null -> Just ""
    _ -> Nothing

-- | A JSON number rendered without scientific notation
renderNumber :: Scientific -> String
renderNumber n = case floatingOrInteger n of
    Right integer -> show (integer :: Integer)
    Left double -> show (double :: Double)

-- | Whether a value is a non-empty string
isNonEmptyString :: Value -> Bool
isNonEmptyString (String text) = not (T.null text)
isNonEmptyString _ = False

-- | Whether an id is a valid slug (@^[a-z0-9][a-z0-9-]*$@)
validId :: String -> Bool
validId [] = False
validId (c : cs) = isLowerAlphaNum c && all isIdChar cs
  where
    isLowerAlphaNum c = isAsciiLower c || isDigit c
    isIdChar c = isLowerAlphaNum c || c == '-'

-- | Prefixes a problem with the author id
prefix :: String -> String -> String
prefix slug message = "authors.yaml: " ++ slug ++ ": " ++ message
