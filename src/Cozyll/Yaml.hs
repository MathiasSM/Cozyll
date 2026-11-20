-- | Shared helpers for decoding the site's YAML documents into typed values
module Cozyll.Yaml (
    decodeYaml,
    parseYamlList,
    readYamlFile,
    Check (..),
    required,
    optional,
    enumFromJSON,
    lookupEnum,
    typeOptions,
    scalarString,
) where

import Control.Monad (unless)
import Cozyll.Metadata (Key, keyName)
import Data.Aeson (FromJSON (parseJSON), Object, Options (fieldLabelModifier), Value (..), defaultOptions, withText)
import Data.Aeson.Key (fromString)
import Data.Aeson.KeyMap (lookup)
import Data.Aeson.Types (Parser, parseEither)
import Data.Bifunctor (first)
import Data.Char (toLower)
import Data.List (intercalate, stripPrefix)
import Data.List qualified as List
import Data.Maybe (fromMaybe)
import Data.Scientific (Scientific, floatingOrInteger)
import Data.Text qualified as T
import Data.Text.Encoding qualified as T
import Data.Yaml (decodeEither', decodeFileEither, prettyPrintParseException)
import System.Directory (doesFileExist)
import System.Exit (die)
import Prelude hiding (lookup)

-- | Decodes a YAML document, reporting the parse problems found
decodeYaml :: (FromJSON a) => String -> Either [String] a
decodeYaml = first (\e -> [prettyPrintParseException e]) . decodeEither' . T.encodeUtf8 . T.pack

-- | Decodes a top-level YAML list of objects, parsing each one and prefixing its problems by index
parseYamlList :: String -> (Object -> Either [String] a) -> String -> Either [String] [a]
parseYamlList what parseOne text = do
    objects <- decodeYaml text
    let numbered = zip [0 :: Int ..] (map parseOne objects)
        problems = concat [map (prefix index) ps | (index, Left ps) <- numbered]
        parsed = [x | (_, Right x) <- numbered]
    if null problems then Right parsed else Left problems
  where
    prefix index problem = what ++ " #" ++ show index ++ ": " ++ problem

-- | Reads and decodes a YAML file, dying with a clear message
readYamlFile :: (FromJSON a) => FilePath -> IO a
readYamlFile path = do
    exists <- doesFileExist path
    unless exists $ die $ path ++ " not found"
    result <- decodeFileEither path
    either (\e -> die $ "Invalid " ++ path ++ ":\n" ++ prettyPrintParseException e) pure result

-- | Accepts exactly the spellings @render@ produces
enumFromJSON :: (Enum a, Bounded a) => String -> (a -> String) -> Value -> Parser a
enumFromJSON what render = withText what $ \t ->
    case lookupEnum render (T.unpack t) of
        Just x -> pure x
        Nothing ->
            fail $
                "unknown "
                    ++ what
                    ++ " \""
                    ++ T.unpack t
                    ++ "\" (expected "
                    ++ intercalate ", " (map render [minBound .. maxBound])
                    ++ ")"

-- | Resolves a value from its rendered spelling
lookupEnum :: (Enum a, Bounded a) => (a -> String) -> String -> Maybe a
lookupEnum render name = List.lookup name [(render x, x) | x <- [minBound .. maxBound]]

-- | Options for records whose selectors are prefixed by their type name
typeOptions :: String -> Options
typeOptions prefix =
    defaultOptions
        { fieldLabelModifier = \field -> case drop (length prefix) field of
            (c : cs) -> toLower c : cs
            [] -> []
        }

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

-- | Like 'Either', but combining failures instead of stopping at the first
newtype Check a = Check {runCheck :: Either [String] a}

instance Functor Check where
    fmap f (Check r) = Check (fmap f r)

instance Applicative Check where
    pure = Check . Right
    Check (Left a) <*> Check (Left b) = Check (Left (a ++ b))
    Check (Left a) <*> Check _ = Check (Left a)
    Check (Right f) <*> Check r = Check (fmap f r)

required :: (FromJSON a) => Object -> Key -> Check a
required o key = case lookup (fromString $ keyName key) o of
    Nothing -> Check $ Left [keyName key ++ ": missing"]
    Just Null -> Check $ Left [keyName key ++ ": missing"]
    Just v -> Check $ decodeField key v

optional :: (FromJSON a) => Object -> Key -> Check (Maybe a)
optional o key = case lookup (fromString $ keyName key) o of
    Nothing -> pure Nothing
    Just Null -> pure Nothing
    Just v -> Check $ Just <$> decodeField key v

decodeField :: (FromJSON a) => Key -> Value -> Either [String] a
decodeField key = first (\e -> [keyName key ++ ": " ++ clean e]) . parseEither parseJSON
  where
    clean e = fromMaybe e (stripPrefix "Error in $: " e)
