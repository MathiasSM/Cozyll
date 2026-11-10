{- | Provenance for the generated site: which environment built @_site@, when,
and from which content directory.

The state lives in @_cache/cozyll-build.json@, next to Hakyll's own cache.
@_cache@ is never deployed and @cozyll clean@ removes it, so the two always
disappear together. That pairing matters: Hakyll treats cached items as
already written, so dropping only @_site@ would silently leave output
missing.
-}
module Cozyll.BuildState (
    BuildState (..),
    BuildStart (..),
    buildStatePath,
    buildStatePathIn,
    readBuildState,
    readBuildStateIn,
    writeBuildState,
    writeBuildStateIn,
    decideBuildStart,
    applyBuildStart,
    applyBuildStartIn,
    resetBuildOutputs,
    resetBuildOutputsIn,
    siteOutputExists,
    siteOutputExistsIn,
    newestContentChange,
    envText,
    envFromText,
) where

import Control.Exception (IOException, try)
import Control.Monad (forM, when)
import Cozyll.Config (Env (..))
import Data.Aeson (FromJSON (parseJSON), ToJSON (toJSON), eitherDecodeStrict', encode, object, withObject, (.:), (.=))
import Data.ByteString qualified as BS
import Data.ByteString.Lazy qualified as BL
import Data.List (sortOn)
import Data.Maybe (isNothing)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Time (UTCTime)
import Data.Time.Format.ISO8601 (iso8601ParseM, iso8601Show)
import System.Directory (
    createDirectoryIfMissing,
    doesDirectoryExist,
    doesFileExist,
    doesPathExist,
    getModificationTime,
    listDirectory,
    removePathForcibly,
 )
import System.FilePath ((</>))
import System.IO (hPutStrLn, stderr)

-- | The recorded state of the last successful build
data BuildState = BuildState
    { buildStateVersion :: String
    -- ^ The @cozyll@ version that produced @_site@
    , buildStateEnv :: Env
    -- ^ The @SITE_ENV@ of that build
    , buildStateBuiltAt :: UTCTime
    -- ^ When the build finished (UTC)
    , buildStateContentDir :: FilePath
    -- ^ The content directory that was compiled
    }
    deriving (Eq, Show)

instance ToJSON BuildState where
    toJSON state =
        object
            [ "version" .= buildStateVersion state
            , "env" .= envText (buildStateEnv state)
            , "builtAt" .= iso8601Show (buildStateBuiltAt state)
            , "contentDir" .= buildStateContentDir state
            ]

instance FromJSON BuildState where
    parseJSON = withObject "BuildState" $ \o -> do
        stateVersion <- o .: "version"
        envValue <- o .: "env"
        env <- maybe (fail $ "unknown env \"" ++ envValue ++ "\"") pure (envFromText envValue)
        builtAtValue <- o .: "builtAt"
        builtAt <- maybe (fail $ "invalid builtAt \"" ++ builtAtValue ++ "\"") pure (iso8601ParseM builtAtValue)
        contentDir <- o .: "contentDir"
        pure
            BuildState
                { buildStateVersion = stateVersion
                , buildStateEnv = env
                , buildStateBuiltAt = builtAt
                , buildStateContentDir = contentDir
                }

-- | Where the build state is stored, relative to the working directory
buildStatePath :: FilePath
buildStatePath = buildStatePathIn "."

-- | The state path inside a given working directory
buildStatePathIn :: FilePath -> FilePath
buildStatePathIn root = root </> "_cache" </> "cozyll-build.json"

{- | Reads the last build state. A missing file, unreadable file or invalid
JSON is reported as 'Nothing' instead of crashing.
-}
readBuildState :: IO (Maybe BuildState)
readBuildState = readBuildStateIn "."

-- | 'readBuildState' inside a given working directory
readBuildStateIn :: FilePath -> IO (Maybe BuildState)
readBuildStateIn root = do
    let path = buildStatePathIn root
    exists <- doesFileExist path
    if not exists
        then pure Nothing
        else do
            result <- try (BS.readFile path) :: IO (Either IOException BS.ByteString)
            pure $ either (const Nothing) decodeState result
  where
    decodeState bytes = either (const Nothing) Just (eitherDecodeStrict' bytes)

-- | Records a successful build, creating @_cache@ as needed
writeBuildState :: BuildState -> IO ()
writeBuildState = writeBuildStateIn "."

-- | 'writeBuildState' inside a given working directory
writeBuildStateIn :: FilePath -> BuildState -> IO ()
writeBuildStateIn root state = do
    createDirectoryIfMissing True (root </> "_cache")
    BL.writeFile (buildStatePathIn root) (encode state)

-- | What a build should do with the output left by an earlier one
data BuildStart
    = -- | Remove @_site@ and @_cache@; the message is shown to the user
      Reset Text
    | Proceed
    deriving (Eq, Show)

{- | Decides whether a build may reuse the existing output.

A build resets when the environment changed (a @dev@ build may have published
drafts that a @prod@ build would leave behind) or when there is output without
provenance (it may come from any environment or version).
-}
decideBuildStart :: Maybe BuildState -> Env -> Bool -> BuildStart
decideBuildStart state env siteExists =
    case state of
        Just previous
            | buildStateEnv previous /= env ->
                Reset $
                    "SITE_ENV changed "
                        <> T.pack (envText (buildStateEnv previous))
                        <> " -> "
                        <> T.pack (envText env)
                        <> "; cleared _site and _cache"
        _ | siteExists && isNothing state -> Reset "no build state found; rebuilding from scratch"
        _ -> Proceed

-- | Applies a 'BuildStart' decision, printing the reset reason on stderr
applyBuildStart :: BuildStart -> IO ()
applyBuildStart = applyBuildStartIn "."

-- | 'applyBuildStart' inside a given working directory
applyBuildStartIn :: FilePath -> BuildStart -> IO ()
applyBuildStartIn _ Proceed = pure ()
applyBuildStartIn root (Reset message) = do
    hPutStrLn stderr (T.unpack message)
    resetBuildOutputsIn root

-- | Removes @_site@ and @_cache@ together, tolerating paths that are absent
resetBuildOutputs :: IO ()
resetBuildOutputs = resetBuildOutputsIn "."

-- | 'resetBuildOutputs' inside a given working directory
resetBuildOutputsIn :: FilePath -> IO ()
resetBuildOutputsIn root = mapM_ (removeIfPresent root) ["_site", "_cache"]
  where
    removeIfPresent root' name = do
        let path = root' </> name
        exists <- doesPathExist path
        when exists $ removePathForcibly path

-- | Whether @_site@ exists and has at least one entry
siteOutputExists :: IO Bool
siteOutputExists = siteOutputExistsIn "."

-- | 'siteOutputExists' inside a given working directory
siteOutputExistsIn :: FilePath -> IO Bool
siteOutputExistsIn root = do
    let path = root </> "_site"
    exists <- doesDirectoryExist path
    if not exists
        then pure False
        else not . null <$> listDirectory path

{- | The content file changed most recently after @builtAt@, as a path relative
to the working directory (e.g. @content\/writings\/kanji\/x.md@).

Returns 'Nothing' when the content directory does not exist or nothing changed
since the build.
-}
newestContentChange :: FilePath -> UTCTime -> IO (Maybe FilePath)
newestContentChange contentDir builtAt = do
    exists <- doesDirectoryExist contentDir
    if not exists
        then pure Nothing
        else do
            files <- filesUnder ""
            stamps <- forM files $ \relative -> do
                let path = contentDir </> relative
                modified <- getModificationTime path
                pure (modified, path)
            let newer = sortOn id [(modified, path) | (modified, path) <- stamps, modified > builtAt]
            pure $ if null newer then Nothing else Just (snd (last newer))
  where
    filesUnder relative = do
        entries <- listDirectory (contentDir </> relative)
        fmap concat . forM entries $ \entry -> do
            let child = if null relative then entry else relative </> entry
            isDir <- doesDirectoryExist (contentDir </> child)
            if isDir then filesUnder child else pure [child]

-- | The @SITE_ENV@ spelling used in messages and in the state file
envText :: Env -> String
envText Prod = "prod"
envText Dev = "dev"
envText Example = "example"

-- | Parses an @SITE_ENV@ spelling (inverse of 'envText')
envFromText :: String -> Maybe Env
envFromText "prod" = Just Prod
envFromText "dev" = Just Dev
envFromText "example" = Just Example
envFromText _ = Nothing
