-- | A page's language: an open, validated code (2-letter ISO 639-1, optional region)
module Cozyll.Domain.Language (
    Language (..),
    languageOf,
    languageOfWith,
    defaultLanguage,
    baseLanguage,
    normalizeLanguage,
) where

import Cozyll.Metadata qualified as K
import Cozyll.Yaml (Check, optional)
import Data.Aeson (FromJSON (parseJSON), withText)
import Data.Char (isAlpha, isAlphaNum, toLower, toUpper)
import Data.Maybe (fromMaybe)
import Data.Text qualified as T
import Hakyll (Metadata)

{- | A page's language, normalized: a lowercase 2-letter primary tag and an
optional @-UPPER@ region subtag (@en@, @es@, @ja@, @pt-BR@, …).
-}
newtype Language = Language {languageCode :: String}
    deriving (Eq, Show)

-- | The language pages fall back to when none is selected.
defaultLanguage :: Language
defaultLanguage = Language "en"

-- | The base language of a regional code: @pt-BR@ → @pt@.
baseLanguage :: Language -> Language
baseLanguage = Language . takeWhile (/= '-') . languageCode

-- | Normalizes a @language:@ value to a 'Language', or explains why it's invalid.
normalizeLanguage :: String -> Either String Language
normalizeLanguage raw =
    case break (\c -> c == '-' || c == '_') raw of
        (primary, "") ->
            if validPrimary primary
                then Right (Language (map toLower primary))
                else invalid
        (primary, sep : tag) ->
            if validPrimary primary && (sep == '-' || sep == '_') && validRegion tag
                then Right (Language (map toLower primary ++ "-" ++ map toUpper tag))
                else invalid
  where
    validPrimary s = length s == 2 && all isAlpha s
    validRegion t = length t >= 2 && length t <= 3 && all isAlphaNum t
    invalid = Left $ "expected a 2-letter ISO 639-1 code with an optional region, got " ++ show raw

instance FromJSON Language where
    parseJSON = withText "language" $ \t ->
        either fail pure (normalizeLanguage (T.unpack t))

-- | The language of an item, falling back to the site's own language when none is stated
languageOfWith :: Language -> Metadata -> Check Language
languageOfWith fallback o = fromMaybe fallback <$> optional o K.Language

-- | The language of an item (English unless stated)
languageOf :: Metadata -> Check Language
languageOf = languageOfWith defaultLanguage
