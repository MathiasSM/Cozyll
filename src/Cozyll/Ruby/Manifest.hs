-- | Provenance for a derived ruby index. The build never reads this file; @data verify@ does.
module Cozyll.Ruby.Manifest (
    Manifest (..),
    Source (..),
    emptyManifest,
    encodeManifest,
    decodeManifest,
    verifyManifest,
    manifestPath,
) where

import Control.Monad (when)
import Cozyll.Ruby.Data (sha256Hex)
import Data.Aeson (Value (..), eitherDecodeStrict')
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap (KeyMap)
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Text (encodeToLazyText)
import Data.Bifunctor (first)
import Data.ByteString (ByteString)
import Data.ByteString qualified as BS
import Data.Foldable (toList)
import Data.List (sortOn)
import Data.Scientific (toBoundedInteger)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding (encodeUtf8)
import Data.Text.Lazy qualified as TL
import System.FilePath.Posix ((</>))

-- | One upstream source: id, pinned ref, licence, and hashes of the exact bytes used
data Source = Source
    { sourceId :: Text
    , sourceRef :: Text
    , sourceLicense :: Text
    , sourceFiles :: [(Text, Text, Int)]
    }
    deriving (Eq, Show)

-- | The manifest: sources plus the hash of the index they produced
data Manifest = Manifest
    { manifestSources :: [Source]
    , manifestIndexHash :: Text
    , manifestIndexBytes :: Int
    }
    deriving (Eq, Show)

emptyManifest :: Manifest
emptyManifest = Manifest [] "" 0

manifestPath :: FilePath -> FilePath
manifestPath contentDir = contentDir </> "ruby-data" </> "manifest.json"

-- Encoding --------------------------------------------------------------------

encodeManifest :: Manifest -> Text
encodeManifest manifest =
    T.concat
        [ "{\n"
        , "  \"schemaVersion\": 1,\n"
        , "  \"derivationVersion\": 1,\n"
        , "  \"sources\": "
        , renderArray (map renderSource (sortOn sourceId (manifestSources manifest)))
        , ",\n"
        , "  \"index\": "
        , renderIndex (manifestIndexHash manifest) (manifestIndexBytes manifest)
        , "\n"
        , "}\n"
        ]
  where
    renderArray [] = "[]"
    renderArray rows = "[\n" <> T.intercalate ",\n" (map ("    " <>) rows) <> "\n  ]"

    renderSource source =
        "["
            <> jsonText (sourceId source)
            <> ", "
            <> jsonText (sourceRef source)
            <> ", "
            <> jsonText (sourceLicense source)
            <> ", ["
            <> T.intercalate
                ", "
                [ "["
                    <> jsonText path
                    <> ", "
                    <> jsonText digest
                    <> ", "
                    <> T.pack (show bytes)
                    <> "]"
                | (path, digest, bytes) <- sortOn (\(p, _, _) -> p) (sourceFiles source)
                ]
            <> "]]"

    renderIndex digest bytes = "[" <> jsonText digest <> ", " <> T.pack (show bytes) <> "]"

    jsonText = TL.toStrict . encodeToLazyText . String

-- Decoding --------------------------------------------------------------------

decodeManifest :: Text -> Either String Manifest
decodeManifest text = do
    value <- first show (eitherDecodeStrict' (encodeUtf8 text))
    obj <- asObject "manifest" value
    schema <- required "schemaVersion" obj >>= asInt "schemaVersion"
    when (schema /= 1) $ Left ("unsupported manifest schemaVersion " ++ show schema)
    sourcesValue <- required "sources" obj
    sources <- asArray "sources" sourcesValue >>= traverse decodeSource
    indexValue <- required "index" obj
    (digest, bytes) <- case asArray "index" indexValue of
        Right [h, b] -> (,) <$> asText "index[0]" h <*> asInt "index[1]" b
        _ -> Left "index must be [sha256, bytes]"
    pure (Manifest (sortOn sourceId sources) digest bytes)

decodeSource :: Value -> Either String Source
decodeSource value = do
    xs <- asArray "source" value
    case xs of
        [i, r, l, files] ->
            Source
                <$> asText "source[0]" i
                <*> asText "source[1]" r
                <*> asText "source[2]" l
                <*> (asArray "source[3]" files >>= traverse decodeFile)
        _ -> Left "source must be [id, ref, license, files]"
  where
    decodeFile f = do
        fs <- asArray "source file" f
        case fs of
            [p, h, b] -> (,,) <$> asText "file[0]" p <*> asText "file[1]" h <*> asInt "file[2]" b
            _ -> Left "source file must be [path, sha256, bytes]"

-- Verification ----------------------------------------------------------------

-- | Checks that the manifest describes exactly these index bytes
verifyManifest :: Manifest -> ByteString -> Either String ()
verifyManifest manifest bytes
    | sha256Hex bytes /= manifestIndexHash manifest = Left "index hash does not match manifest.json (run `cozyll data manifest`)"
    | BS.length bytes /= manifestIndexBytes manifest = Left "index size does not match manifest.json (run `cozyll data manifest`)"
    | otherwise = Right ()

-- Helpers ---------------------------------------------------------------------

asObject :: String -> Value -> Either String (KeyMap Value)
asObject _ (Object o) = Right o
asObject label _ = Left (label ++ " must be an object")

asArray :: String -> Value -> Either String [Value]
asArray _ (Array a) = Right (toList a)
asArray label _ = Left (label ++ " must be an array")

required :: String -> KeyMap Value -> Either String Value
required name obj =
    maybe (Left ("missing field " ++ name)) Right (KeyMap.lookup (Key.fromText (T.pack name)) obj)

asText :: String -> Value -> Either String Text
asText _ (String t) = Right t
asText label _ = Left (label ++ " must be a string")

asInt :: String -> Value -> Either String Int
asInt _ (Number n) = maybe (Left "expected an integer") Right (toBoundedInteger n)
asInt label _ = Left (label ++ " must be an integer")
