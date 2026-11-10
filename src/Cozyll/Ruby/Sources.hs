{-# LANGUAGE TemplateHaskell #-}

{- | Where the ruby index comes from: the default source table, user overrides,
GitHub resolution, and download/digest verification.

The default is @schema/example.ruby-sources.yaml@, embedded into the binary so
it works from any content repo. A content repo may copy it to
@<content>\/ruby-data\/sources.yaml@ and edit it; that file wins when present.

__Licensing and attribution.__ The released library and CLI ship no dictionary
data; @cozyll data fetch@ derives @ruby-data\/index.json@ in the consumer's
content repo. That derived index is distributed under CC BY-SA 4.0 because it is
derived from the following sources:

* KANJIDIC (EDRDG) — kanji grades. CC BY-SA 4.0.
  <https://www.edrdg.org/wiki/index.php/KANJIDIC_Project>
* JMdict and JMnedict (EDRDG) — readings. CC BY-SA 4.0.
  <https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project>
  <https://www.edrdg.org/enamdict/enamdict_doc.html>
* JmdictFurigana and JmnedictFurigana (Doublevil) — kanji/reading alignments.
  CC BY-SA 4.0. <https://github.com/Doublevil/JmdictFurigana>
* yomitan-jlpt-vocab — JLPT vocabulary. CC BY-SA 4.0.
  <https://github.com/stephenmk/yomitan-jlpt-vocab>
* Jonathan Waller's JLPT Resources — JLPT levels. CC BY.
  <http://www.tanos.co.uk/jlpt/>
* kanji-data — JSON conversion and JLPT data. MIT (scripts).
  <https://github.com/davidluzgouveia/kanji-data>

@cozyll data sources@ prints the effective table and its @license@ fields; the
shipped default is 'defaultSourcesYaml'.

__If you enable the feature__ (the content repo has @ruby-data\/index.json@),
your site displays and redistributes adapted portions of that data. You must:

* credit the sources above, link their licence pages, and state what changed
  (e.g. "converted to a reduced JSON index");
* link <https://creativecommons.org/licenses/by-sa/4.0/> and the EDRDG
  <https://www.edrdg.org/edrdg/licence.html> from your site; for mixed content
  such as articles, a single "Sources & licences" page linked from the footer
  satisfies EDRDG's general-acknowledgement rule;
* not claim copyright over the dictionary-derived data, and keep your own
  licence notice for prose and images separate;
* keep the data reasonably current: EDRDG's licence expects an update procedure,
  so refresh @sources.yaml@/@index.json@ periodically instead of pinning forever.

Copy @schema\/example.ruby-data.NOTICE@ to @ruby-data\/NOTICE@ (adjust it when
@sources.yaml@ changes). If @ruby-data\/@ is a submodule, commit the index and
the NOTICE there and bump the parent pointer; the generated site should still
carry the acknowledgement itself. If the content repo never provides an index,
no dictionary data is used and none of this applies.
-}
module Cozyll.Ruby.Sources (
    Source (..),
    SourceFile (..),
    SourceKind (..),
    sourceKindName,
    defaultSourcesYaml,
    sourcesFileName,
    sourcesPath,
    readSourcesFile,
    loadSources,
    resolveSources,
    ResolvedSource (..),
    downloadSources,
    DownloadedSource (..),
    substituteRef,
    githubRepo,
) where

import Codec.Archive.Zip qualified as Zip
import Control.Monad (forM, unless, when)
import Cozyll.Yaml (enumFromJSON)
import Crypto.Hash (Digest, SHA256, hash)
import Data.Aeson (FromJSON (parseJSON), Value (..), eitherDecodeStrict', withObject, (.:), (.:?))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap (KeyMap)
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Bifunctor (first)
import Data.ByteString (ByteString)
import Data.ByteString qualified as BS
import Data.ByteString.Lazy qualified as BL
import Data.Either (partitionEithers)
import Data.FileEmbed (embedFile)
import Data.Foldable (toList)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Yaml (decodeEither', prettyPrintParseException)
import Language.Haskell.TH.Syntax (makeRelativeToProject)
import System.Directory (doesFileExist)
import System.FilePath.Posix ((</>))

-- | What a source points at
data SourceKind = Repo | Release
    deriving (Eq, Show, Enum, Bounded)

-- | The YAML spelling
sourceKindName :: SourceKind -> String
sourceKindName Repo = "repo"
sourceKindName Release = "release"

instance FromJSON SourceKind where
    parseJSON = enumFromJSON "source kind" sourceKindName

{- | One file to download. @url@ contains a @{ref}@ placeholder; @entry@ names
the file inside an archive (release assets only).
-}
data SourceFile = SourceFile
    { sourceFileName :: Text
    , sourceFileUrl :: Text
    , sourceFileEntry :: Maybe Text
    }
    deriving (Eq, Show)

instance FromJSON SourceFile where
    parseJSON = withObject "source file" $ \o ->
        SourceFile
            <$> o .: "name"
            <*> o .: "url"
            <*> o .:? "entry"

-- | One upstream source
data Source = Source
    { sourceId :: Text
    , sourceKind :: SourceKind
    , sourceRef :: Text
    , sourceLicense :: Text
    , sourceFiles :: [SourceFile]
    }
    deriving (Eq, Show)

instance FromJSON Source where
    parseJSON = withObject "source" $ \o ->
        Source
            <$> o .: "id"
            <*> o .: "kind"
            <*> o .: "ref"
            <*> o .: "license"
            <*> o .: "files"

newtype SourcesFile = SourcesFile [Source]

instance FromJSON SourcesFile where
    parseJSON = withObject "ruby sources" $ \o -> SourcesFile <$> o .: "sources"

-- | The file name inside @ruby-data/@
sourcesFileName :: FilePath
sourcesFileName = "sources.yaml"

-- | The user override path for a content root
sourcesPath :: FilePath -> FilePath
sourcesPath contentDir = contentDir </> "ruby-data" </> sourcesFileName

{- | The vendored default, embedded at compile time so the executable works from
any content repo (and so @data sources --write@ preserves the comments).
-}
defaultSourcesYaml :: ByteString
defaultSourcesYaml =
    $( makeRelativeToProject "schema/example.ruby-sources.yaml"
        >>= embedFile
     )

-- | Reads the user override if present, else the embedded default
readSourcesFile :: FilePath -> IO ByteString
readSourcesFile path = do
    exists <- doesFileExist path
    if exists then BS.readFile path else pure defaultSourcesYaml

-- | Parses and validates a sources file
loadSources :: FilePath -> IO (Either String [Source])
loadSources path = do
    bytes <- readSourcesFile path
    pure $ do
        parsed <- first prettyPrintParseException (decodeEither' bytes)
        case parsed of
            SourcesFile sources -> validateSources sources
  where
    validateSources sources = do
        when (null sources) (Left "sources: at least one source is required")
        checkUnique "source id" sourceId sources
        mapM_ validateSource sources
        pure sources

    validateSource source = do
        when (null (sourceFiles source)) (Left ("source " ++ T.unpack (sourceId source) ++ ": no files"))
        checkUnique "file name" sourceFileName (sourceFiles source)
        mapM_ (validateFile (sourceId source)) (sourceFiles source)

    validateFile sourceId' file =
        unless ("{ref}" `T.isInfixOf` sourceFileUrl file) $
            Left
                ( "source "
                    ++ T.unpack sourceId'
                    ++ "/"
                    ++ T.unpack (sourceFileName file)
                    ++ ": url must contain {ref}"
                )

checkUnique :: (Ord a) => String -> (b -> a) -> [b] -> Either String ()
checkUnique label key values =
    unless (length values == length (Map.keys (Map.fromList [(key v, ()) | v <- values]))) $
        Left (label ++ " values must be unique")

-- Resolution ------------------------------------------------------------------

{- | A source with @latest@ replaced by a concrete commit/tag, plus any release
asset digests provided by the GitHub API (keyed by asset name).
-}
data ResolvedSource = ResolvedSource
    { resolvedSource :: Source
    , resolvedDigests :: Map Text Text
    }
    deriving (Eq, Show)

-- | A downloaded source: logical file name to bytes
data DownloadedSource = DownloadedSource
    { downloadedSource :: Source
    , downloadedFiles :: [(Text, ByteString)]
    }
    deriving (Eq, Show)

-- | A downloader; injectable so the resolver/downloader can be tested offline
type Fetch = String -> IO (Either String ByteString)

{- | Resolves @latest@ for every source. Errors are aggregated so the caller can
report them all. Non-GitHub URLs must pin a concrete ref.
-}
resolveSources :: Fetch -> [Source] -> IO (Either [String] [ResolvedSource])
resolveSources fetch sources = do
    results <- forM sources (resolveOne fetch)
    pure $ case partitionEithers results of
        ([], resolved) -> Right resolved
        (errors, _) -> Left errors

resolveOne :: Fetch -> Source -> IO (Either String ResolvedSource)
resolveOne _ source
    | sourceRef source /= "latest" =
        pure (Right (ResolvedSource source Map.empty))
resolveOne fetch source = case sourceFiles source of
    [] -> pure (Left (sourceLabel source ++ ": no files"))
    (file : _) -> case githubRepo (sourceFileUrl file) of
        Nothing ->
            pure
                ( Left
                    ( sourceLabel source
                        ++ ": ref \"latest\" needs a GitHub URL; pin a commit/tag for other hosts"
                    )
                )
        Just (owner, repo) -> case sourceKind source of
            Repo -> do
                response <- fetch (commitUrl owner repo)
                pure $ do
                    bytes <- response
                    ref <- parseCommitSha bytes
                    pure (ResolvedSource source{sourceRef = ref} Map.empty)
            Release -> do
                response <- fetch (releaseUrl owner repo)
                pure $ do
                    bytes <- response
                    (tag, digests) <- parseRelease bytes
                    pure (ResolvedSource source{sourceRef = tag} digests)

sourceLabel :: Source -> String
sourceLabel source = "source " ++ T.unpack (sourceId source)

commitUrl :: Text -> Text -> String
commitUrl owner repo =
    "https://api.github.com/repos/" ++ T.unpack owner ++ "/" ++ T.unpack repo ++ "/commits?per_page=1"

releaseUrl :: Text -> Text -> String
releaseUrl owner repo =
    "https://api.github.com/repos/" ++ T.unpack owner ++ "/" ++ T.unpack repo ++ "/releases/latest"

-- | Extracts @owner/repo@ from a GitHub or raw GitHub URL
githubRepo :: Text -> Maybe (Text, Text)
githubRepo url = case T.stripPrefix "https://raw.githubusercontent.com/" url of
    Just rest -> two (T.splitOn "/" rest)
    Nothing -> case T.stripPrefix "https://github.com/" url of
        Just rest -> two (T.splitOn "/" rest)
        Nothing -> Nothing
  where
    two (owner : repo : _) = Just (owner, repo)
    two _ = Nothing

parseCommitSha :: ByteString -> Either String Text
parseCommitSha bytes = do
    value <- decodeJson bytes
    case value of
        Array commits -> case toList commits of
            (Object commit : _) -> field "sha" commit >>= asText "sha"
            _ -> Left "GitHub commits response is empty"
        _ -> Left "GitHub commits response is not an array"

parseRelease :: ByteString -> Either String (Text, Map Text Text)
parseRelease bytes = do
    value <- decodeJson bytes
    obj <- asObject "GitHub release" value
    tag <- field "tag_name" obj >>= asText "tag_name"
    assets <- maybe (Right []) (asArray "assets") (KeyMap.lookup "assets" obj)
    digests <- (fmap (Map.fromList . concat) . forM assets) $ \asset -> do
        assetObject <- asObject "release asset" asset
        name <- field "name" assetObject >>= asText "name"
        case KeyMap.lookup "digest" assetObject of
            Just (String digest) -> pure [(name, stripDigest digest)]
            _ -> pure []
    pure (tag, digests)

stripDigest :: Text -> Text
stripDigest digest = fromMaybe digest (T.stripPrefix "sha256:" digest)

-- Downloading -----------------------------------------------------------------

{- | Downloads every file of every resolved source, extracts archive entries, and
checks release-asset digests when GitHub provided one.
-}
downloadSources :: Fetch -> [ResolvedSource] -> IO (Either [String] [DownloadedSource])
downloadSources fetch resolved = do
    results <- forM resolved (downloadOne fetch)
    pure $ case partitionEithers results of
        ([], downloaded) -> Right downloaded
        (errors, _) -> Left errors

downloadOne :: Fetch -> ResolvedSource -> IO (Either String DownloadedSource)
downloadOne fetch (ResolvedSource source digests) = do
    results <- forM (sourceFiles source) (downloadFile fetch source digests)
    pure $ case partitionEithers results of
        ([], files) -> Right (DownloadedSource source files)
        (errors, _) -> Left (unlines errors)

downloadFile :: Fetch -> Source -> Map Text Text -> SourceFile -> IO (Either String (Text, ByteString))
downloadFile fetch source digests file = do
    let url = substituteRef (sourceRef source) (sourceFileUrl file)
        label = sourceLabel source ++ "/" ++ T.unpack (sourceFileName file)
    response <- fetch (T.unpack url)
    case response of
        Left problem -> pure (Left (label ++ ": " ++ problem))
        Right bytes -> case checkDigest url digests bytes of
            Left problem -> pure (Left (label ++ ": " ++ problem))
            Right () -> case extract file bytes of
                Left problem -> pure (Left (label ++ ": " ++ problem))
                Right content -> pure (Right (sourceFileName file, content))
  where
    extract file' bytes = case sourceFileEntry file' of
        Nothing -> Right bytes
        Just entry -> extractEntry bytes (T.unpack entry)

    checkDigest url digests' content = case Map.lookup (assetName url) digests' of
        Nothing -> Right ()
        Just expected
            | sha256Hex content == expected -> Right ()
            | otherwise -> Left ("digest mismatch (expected " ++ T.unpack expected ++ ")")

{- | Replaces the @{ref}@ placeholder
| Replaces the @{ref}@ placeholder in a URL
-}
substituteRef :: Text -> Text -> Text
substituteRef = T.replace "{ref}"

assetName :: Text -> Text
assetName url = case reverse (T.splitOn "/" url) of
    (name : _) -> name
    [] -> url

extractEntry :: ByteString -> String -> Either String ByteString
extractEntry bytes name =
    case Zip.findEntryByPath name (Zip.toArchive (BL.fromStrict bytes)) of
        Nothing -> Left ("archive has no " ++ name)
        Just entry -> Right (BL.toStrict (Zip.fromEntry entry))

sha256Hex :: ByteString -> Text
sha256Hex bytes = T.pack (show (hash bytes :: Digest SHA256))

-- JSON helpers ----------------------------------------------------------------

decodeJson :: ByteString -> Either String Value
decodeJson = first show . eitherDecodeStrict'

asObject :: String -> Value -> Either String (KeyMap Value)
asObject _ (Object o) = Right o
asObject label _ = Left (label ++ " must be an object")

asArray :: String -> Value -> Either String [Value]
asArray _ (Array a) = Right (toList a)
asArray label _ = Left (label ++ " must be an array")

field :: String -> KeyMap Value -> Either String Value
field name obj = maybe (Left ("missing field " ++ name)) Right (KeyMap.lookup (Key.fromText (T.pack name)) obj)

asText :: String -> Value -> Either String Text
asText _ (String t) = Right t
asText label _ = Left (label ++ " must be a string")
