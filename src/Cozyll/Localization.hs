{- | Localization: the template @t("id")@ lookup and the @og:locale@ value, both
sourced from @localization.yaml@.
-}
module Cozyll.Localization (
    translationsContext,
    requireTranslation,
    ogLocaleFor,
) where

import Control.Applicative ((<|>))
import Cozyll.Config (SiteConfig, localizationFile)
import Cozyll.Content (requireLanguage)
import Cozyll.Domain.Language (languageCode)
import Cozyll.Yaml (decodeYaml)
import Data.Aeson (Value (Object, String))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KM
import Data.List (intercalate)
import Data.Text qualified as T
import Hakyll (
    Compiler,
    Context,
    Item (itemIdentifier),
    functionField,
    itemBody,
    load,
 )

-- | The reserved key holding each language's full @xx_YY@ locale for @og:locale@.
ogLocaleKey :: String
ogLocaleKey = "_ogLocaleDefaultRegion"

{- | The @t("id")@ template function: resolves @id@ for the item's language,
falling back @xx-YY@ → @xx@, failing the build otherwise.
-}
translationsContext :: SiteConfig -> Context a
translationsContext cfg = functionField "t" $ \args item -> do
    textId <- case args of
        [x] -> pure x
        _ -> fail "t() expects exactly one id"
    lang <- languageCode <$> requireLanguage (itemIdentifier item)
    requireTranslation cfg lang textId

-- | Looks up a string for a language, falling back to the base language (@xx-YY@ → @xx@).
requireTranslation :: SiteConfig -> String -> String -> Compiler String
requireTranslation cfg lang textId = do
    translations <- loadTranslations cfg
    case lookupText translations textId lang <|> lookupText translations textId (baseOf lang) of
        Just s -> pure s
        Nothing -> fail $ "localization.yaml: no '" ++ textId ++ "' translation for language '" ++ lang ++ "'"

-- | The full @xx_YY@ locale for @og:locale@; fails the build when missing.
ogLocaleFor :: SiteConfig -> String -> Compiler String
ogLocaleFor cfg lang = requireTranslation cfg lang ogLocaleKey

-- | The base language of a code: @pt-BR@ → @pt@.
baseOf :: String -> String
baseOf = takeWhile (/= '-')

-- | Loads and decodes @localization.yaml@ (a map of id → {locale → string}).
loadTranslations :: SiteConfig -> Compiler Value
loadTranslations cfg = do
    body <- itemBody <$> load (localizationFile cfg)
    case decodeYaml body of
        Left problems -> fail $ "Invalid localization.yaml:\n" ++ intercalate "\n" problems
        Right value -> pure value

-- | A string under @textId@ for @lang@.
lookupText :: Value -> String -> String -> Maybe String
lookupText (Object top) textId lang = do
    locales <- KM.lookup (Key.fromString textId) top
    case locales of
        Object localeMap -> maybeString =<< KM.lookup (Key.fromString lang) localeMap
        _ -> Nothing
  where
    maybeString (String s) = Just (T.unpack s)
    maybeString _ = Nothing
lookupText _ _ _ = Nothing
