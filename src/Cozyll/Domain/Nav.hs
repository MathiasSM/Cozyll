-- | A menu entry's front-matter model and parser
module Cozyll.Domain.Nav (
    NavEntry (..),
    parseNavEntry,
    parseNavYaml,
    resolveNavLabel,
) where

import Control.Monad ((>=>))
import Cozyll.Domain.Language (
    Language (..),
    baseLanguage,
    languageOfWith,
    normalizeLanguage,
 )
import Cozyll.Metadata qualified as K
import Cozyll.Yaml (Check (..), decodeYaml, required)
import Data.Aeson (Value (..))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KM
import Data.List (intercalate)
import Data.Text qualified as T
import Hakyll (Metadata)

{- | A page that appears in the site menu (`nav: <label>`, `navOrder: <n>` in its front matter)

The label is either a single string (@navLabel@), used for every language, or a
map of language to label (@navLabels@). @navLanguage@ is the language of the
page itself, used for the single-label form.
-}
data NavEntry = NavEntry
    { navLabel :: Maybe String
    , navLabels :: [(Language, String)]
    , navOrder :: Int
    , navHref :: FilePath
    , navLanguage :: Language
    }
    deriving (Eq, Show)

{- | The menu entry a page asks for, if it has a `nav:` label (it then also needs `navOrder`
and @path@)

@fallback@ is the language a page without an explicit @language:@ is assumed to
be written in (the site's own language).
-}
parseNavEntry :: Language -> Metadata -> Either [String] (Maybe NavEntry)
parseNavEntry fallback o = do
    labels <- runCheck (navSpec o)
    case labels of
        Nothing -> Right Nothing
        Just (label, perLanguage) ->
            runCheck $
                Just
                    <$> ( NavEntry label perLanguage
                            <$> required o K.NavOrder
                            <*> required o K.Path
                            <*> languageOfWith fallback o
                        )

-- | The raw @nav:@ value: a single label, or a map of language codes to labels
navSpec :: Metadata -> Check (Maybe (Maybe String, [(Language, String)]))
navSpec o = case KM.lookup (Key.fromString $ K.keyName K.Nav) o of
    Nothing -> pure Nothing
    Just Null -> pure Nothing
    Just (String text) -> pure $ Just (Just $ T.unpack text, [])
    Just (Object labels) -> parseNavLabels labels
    Just _ -> Check $ Left ["nav: expected a label or a map of language codes to labels"]

-- | Reads a @nav: {en: Guides, es: Guías}@ map, reporting every invalid key or value
parseNavLabels :: KM.KeyMap Value -> Check (Maybe (Maybe String, [(Language, String)]))
parseNavLabels labels
    | KM.null labels =
        Check $ Left ["nav: expected at least one language label (like nav: {en: Guides})"]
    | otherwise = fmap (Just . (Nothing,)) (traverse parseLabel (KM.toList labels))
  where
    parseLabel (key, value) = (,) <$> parseLanguage key <*> parseLabelValue key value
    parseLanguage key = case normalizeLanguage (Key.toString key) of
        Left _ ->
            Check $
                Left
                    [ "nav: invalid language \""
                        ++ Key.toString key
                        ++ "\" (expected a 2-letter ISO 639-1 code with an optional region)"
                    ]
        Right language -> pure language
    parseLabelValue key value = case value of
        String text
            | T.null text -> Check $ Left ["nav: empty label for language \"" ++ Key.toString key ++ "\""]
            | otherwise -> pure (T.unpack text)
        _ -> Check $ Left ["nav: the label for language \"" ++ Key.toString key ++ "\" must be text"]

-- | 'parseNavEntry' on YAML text (the same shape as front matter)
parseNavYaml :: Language -> String -> Either [String] (Maybe NavEntry)
parseNavYaml fallback = decodeYaml >=> parseNavEntry fallback

{- | The label to render on a page, and the language it is written in

A single-label entry is written in the page's own language. A language map is
looked up for the page's language, then its base language, then the site's
language (and its base); anything else is an error listing the available
languages.
-}
resolveNavLabel :: Language -> Language -> NavEntry -> Either String (String, Language)
resolveNavLabel pageLanguage siteLanguage' entry =
    case navLabel entry of
        Just label -> Right (label, navLanguage entry)
        Nothing -> case firstMatch candidates of
            Just (language, label) -> Right (label, language)
            Nothing ->
                Left $
                    "nav: no label for page language '"
                        ++ languageCode pageLanguage
                        ++ "' (available: "
                        ++ intercalate ", " (map (languageCode . fst) (navLabels entry))
                        ++ ")"
  where
    candidates = [pageLanguage, baseLanguage pageLanguage, siteLanguage', baseLanguage siteLanguage']
    firstMatch [] = Nothing
    firstMatch (candidate : rest) =
        case lookup candidate (navLabels entry) of
            Just label -> Just (candidate, label)
            Nothing -> firstMatch rest
