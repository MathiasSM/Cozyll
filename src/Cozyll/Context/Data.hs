{- | Generic data files: any YAML under @content/data/@, exposed to templates.

Each file becomes a template context named after its path (directories joined
with @-@, extension dropped, so @content/data/team/members.yaml@ is available as
@team-members@). A file holding a top-level list is looped with @$for(name)$@; a
top-level map is read with @$name.key$@ (nested maps flatten to dotted keys).
Scalars render as strings (booleans as @true@/@false@, numbers without
scientific notation).

A list item with @_show: false@ is left out of the loop entirely.

Any scalar field whose name contains @icon@ also gets two derived fields:
@<field>Href@ (the icon URL) and @<field>Raw@ (the SVG markup, inlined). For
example, @icon: book@ provides @$icon$@, @$iconHref$@, and @$iconRaw$@.

A data file may ship a JSON Schema, co-located as @content/data/<name>.schema.json@
next to @content/data/<name>.yaml@; it is validated at build time, and the YAML's
@$schema@ key points at the local file for editor hints. @schema/*.json@ ships
with the release kit.

Avoid @-@ inside file and directory names themselves: it doubles as the
hierarchy separator.

Icons inlined via @<field>Raw@ are neutral SVG with no accessibility attributes,
so the template decides how each icon is exposed: wrap a decorative icon
(redundant with adjacent text) in @<span aria-hidden="true">...</span>@; expose a
meaningful standalone icon with @role="img"@ and an @aria-label@ (or give the SVG
a @<title>@); an icon that is the sole content of a link or button should instead
carry the accessible name on that control via its own @aria-label@. When using
@<field>Href@ as an @<img src>@ instead, set @alt=""@ for a decorative icon or a
descriptive @alt@.
-}
module Cozyll.Context.Data (
    dataContext,

    -- * Pure helpers (also used by the tests)
    renderScalar,
    scalarString,
    iconName,
    lookupLeaf,
    isShown,
    nameToRelPath,
    breakOnDot,
    iconVariant,
    IconVariant (..),
    checkAgainstSchema,
) where

import Control.Monad (when)
import Cozyll.Config (SiteConfig, dataDir, mediaDir)
import Cozyll.Yaml (decodeYaml)
import Data.Aeson (Value (..))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KM
import Data.Foldable (toList)
import Data.JSON.JSONSchema (ValidationError (..), validate)
import Data.List (intercalate, isInfixOf, stripPrefix)
import Data.Maybe (fromMaybe)
import Data.Scientific (Scientific, floatingOrInteger)
import Data.String (fromString)
import Data.Text qualified as T
import Hakyll (
    Compiler,
    Context (..),
    ContextField (..),
    Identifier,
    Item (..),
    fromFilePath,
    getMatches,
    load,
    noResult,
    toFilePath,
 )
import System.FilePath.Posix ((<.>), (</>))

-- | A dynamic context for every data file under 'dataDir'
dataContext :: SiteConfig -> Context a
dataContext cfg = Context $ \key _ _ -> do
    let (name, fieldPath) = breakOnDot key
        ident = fromFilePath $ dataDir cfg </> nameToRelPath name <.> "yaml"
    found <- not . null <$> getMatches (fromString $ toFilePath ident)
    if not found
        then noResult $ "Missing field '" ++ key ++ "' in context"
        else do
            body <- itemBody <$> load ident
            case decodeYaml body of
                Left problems ->
                    fail $ "Invalid data file " ++ toFilePath ident ++ ":\n" ++ intercalate "\n" problems
                Right value -> do
                    validateDataFile cfg name value
                    buildTopLevel cfg ident fieldPath value

-- | Fails the build if the data file has a co-located @<name>.schema.json@ it violates
validateDataFile :: SiteConfig -> String -> Value -> Compiler ()
validateDataFile cfg name value = do
    let relPath = nameToRelPath name
        schemaIdent = fromFilePath $ dataDir cfg </> relPath <.> "schema.json"
    hasSchema <- not . null <$> getMatches (fromString $ toFilePath schemaIdent)
    when hasSchema $ do
        schemaBody <- itemBody <$> load schemaIdent
        case decodeYaml schemaBody of
            Left problems ->
                fail $ "Invalid schema for data file '" ++ name ++ "':\n" ++ intercalate "\n" problems
            Right schema ->
                case checkAgainstSchema schema value of
                    Right () -> pure ()
                    Left errs ->
                        fail $
                            "Data file '"
                                ++ name
                                ++ "' failed schema validation:\n"
                                ++ intercalate "\n" errs

-- | Validates @value@ against @schema@, returning the rendered violations
checkAgainstSchema :: Value -> Value -> Either [String] ()
checkAgainstSchema schema value =
    case validate schema value of
        Right () -> Right ()
        Left errs -> Left (map renderValidationError errs)

-- | A schema validation error with its instance path
renderValidationError :: ValidationError -> String
renderValidationError (ValidationError path msg) =
    (if null path then "(root)" else intercalate "." (map T.unpack path)) ++ ": " ++ T.unpack msg

-- | The fields of one item in a list data file
itemContext :: SiteConfig -> Context Value
itemContext cfg = Context $ \key _ item -> valueField cfg (itemBody item) key

-- | A top-level data value: a list loops as a field, a map is read by dotted key
buildTopLevel :: SiteConfig -> Identifier -> String -> Value -> Compiler ContextField
buildTopLevel cfg ident fieldPath value = case value of
    Array items
        | null fieldPath ->
            return . ListField (itemContext cfg) $
                [Item (fromFilePath $ toFilePath ident ++ "#" ++ show n) item | (n, item) <- zip [0 :: Int ..] shown]
      where
        shown = filter isShown (toList items)
    _ -> valueField cfg value fieldPath

-- | Whether a list item should appear: only an explicit @_show: false@ hides it
isShown :: Value -> Bool
isShown (Object object) = KM.lookup (Key.fromString "_show") object /= Just (Bool False)
isShown _ = True

-- | Resolves one template key against a value: a scalar leaf, or a derived icon field
valueField :: SiteConfig -> Value -> String -> Compiler ContextField
valueField cfg value key =
    case lookupLeaf key value of
        Just leaf -> scalarField leaf
        Nothing -> case iconVariant key of
            Just (base, Href) -> iconHref (lookupLeaf base value)
            Just (base, Raw) -> iconRaw cfg (lookupLeaf base value)
            Nothing -> noResult $ "Field '" ++ key ++ "'"

-- | A scalar leaf as a string field (maps and lists cannot be rendered as a scalar)
scalarField :: Value -> Compiler ContextField
scalarField = maybe (noResult "not a scalar value") (return . StringField) . scalarString

-- | The text of a scalar value, if it is one
scalarString :: Value -> Maybe String
scalarString = \case
    String text -> Just $ T.unpack text
    Number n -> Just $ renderNumber n
    Bool b -> Just $ if b then "true" else "false"
    Null -> Just ""
    _ -> Nothing

-- | The URL of an icon (a bare name under @images/icons/@, @.svg@ appended)
iconHref :: Maybe Value -> Compiler ContextField
iconHref = maybe (noResult "icon href") (return . StringField . iconPath) . (>>= iconName)
  where
    iconPath name = "images/icons/" ++ name ++ ".svg"

-- | The SVG markup of an icon, inlined
iconRaw :: SiteConfig -> Maybe Value -> Compiler ContextField
iconRaw cfg = maybe (noResult "icon raw") loadSvg . (>>= iconName)
  where
    loadSvg name = do
        body <- itemBody <$> load (fromFilePath $ mediaDir cfg </> "icons" </> name <.> "svg")
        return $ StringField body

-- | The bare name of an icon value, if it is a string
iconName :: Value -> Maybe String
iconName = \case
    String name -> Just $ T.unpack name
    _ -> Nothing

-- | Whether a key names a derived icon field (@<base>Href@ / @<base>Raw@)
data IconVariant = Href | Raw
    deriving (Eq, Show)

{- | Classify a derived icon field name: @(base, Href)@ for @<base>Href@,
@(base, Raw)@ for @<base>Raw@, and 'Nothing' for anything else. The @base@
must itself contain @icon@.
-}
iconVariant :: String -> Maybe (String, IconVariant)
iconVariant key =
    case stripSuffix "Href" key of
        Just base | "icon" `isInfixOf` base -> Just (base, Href)
        _ -> case stripSuffix "Raw" key of
            Just base | "icon" `isInfixOf` base -> Just (base, Raw)
            _ -> Nothing

-- | The dotted path of a scalar leaf inside a value, if any
lookupLeaf :: String -> Value -> Maybe Value
lookupLeaf path = go (splitOnDot path)
  where
    go [] value = Just value
    go (part : rest) (Object object) = KM.lookup (Key.fromString part) object >>= go rest
    go _ _ = Nothing

-- | The file name (directories joined with @-@) is a path relative to 'dataDir'
nameToRelPath :: String -> FilePath
nameToRelPath = map (\c -> if c == '-' then '/' else c)

-- | The key up to the first dot, and the dotted path after it
breakOnDot :: String -> (String, String)
breakOnDot key = case break (== '.') key of
    (name, []) -> (name, "")
    (name, _ : rest) -> (name, rest)

splitOnDot :: String -> [String]
splitOnDot = go
  where
    go path = case break (== '.') path of
        (part, []) -> [part]
        (part, _ : rest) -> part : go rest

-- | 'Data.List.stripSuffix', absent from the 'base' this project targets
stripSuffix :: (Eq a) => [a] -> [a] -> Maybe [a]
stripSuffix suffix list = reverse <$> stripPrefix (reverse suffix) (reverse list)

-- | A JSON number rendered without scientific notation
renderNumber :: Scientific -> String
renderNumber n = case floatingOrInteger n of
    Right integer -> show (integer :: Integer)
    Left double -> show (double :: Double)

-- | A scalar as the string templates should see
renderScalar :: Value -> String
renderScalar = fromMaybe "" . scalarString
