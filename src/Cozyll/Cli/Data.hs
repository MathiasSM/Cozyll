{- | @cozyll data ...@: derive, validate, and maintain the committed ruby index.

The index is read offline by the build; only @fetch@ and @sources --resolve@
touch the network. Source locations and versions live in
@ruby-data/sources.yaml@ (or the embedded default); see "Cozyll.Ruby.Sources".
The derived index is CC BY-SA 4.0; that module also records the upstream
licences and the attribution the published site must carry.
-}
module Cozyll.Cli.Data (runDataCommand, parseCommand, Command (..), Options (..)) where

import Control.Applicative ((<|>))
import Control.Monad (foldM, forM_, unless, when)
import Cozyll.Ruby.Derive (Issue (..), Upstream (..), deriveIndex, readUpstreamFrom, upstreamFromFiles)
import Cozyll.Ruby.Index (
    Index (..),
    dataDirName,
    encodeIndex,
    indexFileName,
    indexLimitIO,
    readIndexFile,
    writeIndexFile,
    writeTextFileAtomic,
 )
import Cozyll.Ruby.Sources (
    DownloadedSource (..),
    ResolvedSource (..),
    Source (..),
    defaultSourcesYaml,
    downloadSources,
    loadSources,
    readSourcesFile,
    resolveSources,
    sourcesFileName,
 )
import Data.ByteString (ByteString)
import Data.ByteString qualified as BS
import Data.ByteString.Lazy qualified as BL
import Data.List (isPrefixOf)
import Data.Maybe (fromMaybe)
import Data.Text qualified as T
import Data.Text.Encoding (decodeUtf8, decodeUtf8', encodeUtf8)
import Data.Version (showVersion)
import Network.HTTP.Client (
    Manager,
    httpLbs,
    newManager,
    parseRequest,
    requestHeaders,
    responseBody,
    responseStatus,
 )
import Network.HTTP.Client.TLS (tlsManagerSettings)
import Network.HTTP.Types.Status (statusCode)
import Paths_cozyll (version)
import System.Console.GetOpt (
    ArgDescr (NoArg, ReqArg),
    ArgOrder (Permute),
    OptDescr (Option),
    getOpt,
    usageInfo,
 )
import System.Directory (doesFileExist, getFileSize)
import System.Environment (lookupEnv)
import System.Exit (die)
import System.FilePath.Posix ((</>))

-- | A parsed command
data Command
    = Fetch Options
    | Verify Options
    | Format Options
    | Sources Options
    | Help
    | Version
    deriving (Eq, Show)

-- | Options shared by the subcommands
data Options = Options
    { optFrom :: Maybe FilePath
    , optDataDir :: Maybe FilePath
    , optSources :: Maybe FilePath
    , optCheck :: Bool
    , optWrite :: Bool
    , optForce :: Bool
    , optResolve :: Bool
    }
    deriving (Eq, Show)

emptyOptions :: Options
emptyOptions = Options Nothing Nothing Nothing False False False False

{- | One @data@ flag: how it is spelled, its argument, its help text, the
subcommands that accept it, and how it updates 'Options'. Everything the parser
and the help text need comes from this table. 'specLong' is the bare name, as
@getOpt@ wants it; 'flagName' adds the dashes for the user.
-}
data Spec = Spec
    { specShort :: [Char]
    , specLong :: String
    , specArg :: Maybe String
    , specHelp :: String
    , specCommands :: [String]
    , specApply :: Maybe String -> Options -> Options
    }

-- | Every flag, in help order
specs :: [Spec]
specs =
    [ Spec "h" "help" Nothing "show this help" [] (\_ opts -> opts)
    , Spec "" "version" Nothing "show the cozyll version" [] (\_ opts -> opts)
    , Spec
        ""
        "from"
        (Just "DIR")
        "read upstream files from DIR instead of downloading"
        ["fetch"]
        (\arg opts -> opts{optFrom = arg})
    , Spec
        ""
        "data-dir"
        (Just "DIR")
        "ruby-data directory (default: <content>/ruby-data)"
        ["fetch", "verify", "fmt", "sources"]
        (\arg opts -> opts{optDataDir = arg})
    , Spec
        ""
        "sources"
        (Just "FILE")
        "sources file (default: <data-dir>/sources.yaml)"
        ["fetch", "sources"]
        (\arg opts -> opts{optSources = arg})
    , Spec "" "check" Nothing "derive and compare without writing" ["fetch"] (\_ opts -> opts{optCheck = True})
    , Spec "" "write" Nothing "copy the default sources file into place" ["sources"] (\_ opts -> opts{optWrite = True})
    , Spec "" "force" Nothing "overwrite an existing sources file" ["sources"] (\_ opts -> opts{optForce = True})
    , Spec "" "resolve" Nothing "resolve latest refs via the GitHub API" ["sources"] (\_ opts -> opts{optResolve = True})
    ]

-- | Every flag, as @getOpt@ options
options :: [OptDescr (Spec, Maybe String)]
options = map toOption specs
  where
    toOption spec = Option (specShort spec) [specLong spec] (argDescr spec) (specHelp spec)

    argDescr spec = case specArg spec of
        Nothing -> NoArg (spec, Nothing)
        Just metavar -> ReqArg (\arg -> (spec, Just arg)) metavar

-- | The long name of a flag as the user writes it, for error messages
flagName :: Spec -> String
flagName spec = "--" ++ specLong spec

-- | The flags each command accepts, by long name
allowedFlags :: String -> [String]
allowedFlags command = [flagName spec | spec <- specs, command `elem` specCommands spec]

-- | Parses the arguments after @cozyll data@
parseCommand :: [String] -> Either String Command
parseCommand [] = Right Help
parseCommand (arg : _) | arg `elem` ["-h", "--help"] = Right Help
parseCommand (arg : _) | arg == "--version" = Right Version
parseCommand (command : rest) = do
    flags <- parseFlags rest
    let wants name = name `elem` map (flagName . fst) flags
    case (wants "--help", wants "--version") of
        (True, _) -> Right Help
        (_, True) -> Right Version
        _ -> do
            options' <- foldFlags (allowedFlags command) flags
            case command of
                "fetch" -> Right (Fetch options')
                "verify" -> Right (Verify options')
                "fmt" -> Right (Format options')
                "sources" -> Right (Sources options')
                _ -> Left ("unknown command: " ++ command)
  where
    parseFlags args = case getOpt Permute options args of
        (parsed, [], []) -> Right parsed
        (_, nonOptions, errors) ->
            Left
                ( concat errors
                    ++ case nonOptions of
                        [] -> ""
                        xs -> "unexpected argument(s): " ++ unwords xs ++ "\n"
                )

    foldFlags allowed = foldM (applyFlag allowed) emptyOptions

    applyFlag allowed opts (spec, arg)
        | flagName spec `notElem` allowed =
            Left (flagName spec ++ " is not valid for this command")
        | otherwise = Right (specApply spec arg opts)

-- | Runs a parsed @data@ command
runDataCommand :: FilePath -> [String] -> IO ()
runDataCommand contentDir args = case parseCommand args of
    Left problem -> die (problem ++ "\n\n" ++ usage)
    Right Help -> putStr usage
    Right Version -> putStrLn ("cozyll " ++ showVersion version)
    Right (Fetch opts) -> runFetch contentDir opts
    Right (Verify opts) -> runVerify contentDir opts
    Right (Format opts) -> runFormat contentDir opts
    Right (Sources opts) -> runSources contentDir opts

-- | The @data@ command help text
usage :: String
usage =
    usageInfo "Usage: cozyll data <fetch|verify|fmt|sources> [OPTIONS]" options
        ++ unlines
            [ "Commands:"
            , "  fetch     download (or read --from) the sources and derive ruby-data/index.json"
            , "  verify    validate ruby-data/index.json (schema and canonical form)"
            , "  fmt       rewrite ruby-data/index.json canonically"
            , "  sources   print the effective sources file, or copy the default (--write)"
            ]

-- Paths -----------------------------------------------------------------------

-- | The effective @ruby-data@ directory
dataDir :: FilePath -> Options -> FilePath
dataDir contentDir opts = fromMaybe (contentDir </> dataDirName) (optDataDir opts)

-- | The effective sources file
sourcesFile :: FilePath -> Options -> FilePath
sourcesFile contentDir opts = fromMaybe (dataDir contentDir opts </> sourcesFileName) (optSources opts)

-- Commands --------------------------------------------------------------------

-- | Derives the index from the sources (or @--from@) and writes it
runFetch :: FilePath -> Options -> IO ()
runFetch contentDir opts = do
    upstream <- case optFrom opts of
        Just dir -> readUpstreamFrom dir >>= either dieIssues pure
        Nothing -> downloadUpstream contentDir opts
    idx <- either dieIssues pure (deriveIndex upstream)
    let path = dataDir contentDir opts </> indexFileName
        text = encodeIndex idx
    if optCheck opts
        then checkIndex path (encodeUtf8 text)
        else do
            writeTextFileAtomic path text
            putStrLn ("wrote " ++ path ++ " (" ++ summary idx ++ ")")

-- | Resolves and downloads the effective sources, then builds the derivation input
downloadUpstream :: FilePath -> Options -> IO Upstream
downloadUpstream contentDir opts = do
    manager <- newManager tlsManagerSettings
    token <- lookupEnv "GITHUB_TOKEN" <|> lookupEnv "GH_TOKEN"
    let fetch = httpFetch manager token
    sources <- loadSources (sourcesFile contentDir opts) >>= either die pure
    resolved <- resolveSources fetch sources >>= either dieProblems pure
    downloaded <- downloadSources fetch resolved >>= either dieProblems pure
    forM_ resolved $ \source ->
        putStrLn (T.unpack (sourceId (resolvedSource source)) ++ ": " ++ T.unpack (sourceRef (resolvedSource source)))
    either (dieProblems . map missingUpstreamFile) pure (upstreamFromFiles (concatMap downloadedFiles downloaded))
  where
    missingUpstreamFile name = "downloaded sources are missing " ++ T.unpack name

-- | Reads the committed index, rejecting files larger than the configured limit
loadCheckedIndex :: FilePath -> IO Index
loadCheckedIndex path = do
    limit <- indexLimitIO
    size <- getFileSize path
    when (size > fromIntegral limit) $ die (path ++ ": index is larger than " ++ show limit ++ " bytes")
    readIndexFile path >>= either die pure

-- | Validates the committed index (canonical form and size)
runVerify :: FilePath -> Options -> IO ()
runVerify contentDir opts = do
    let path = dataDir contentDir opts </> indexFileName
    exists <- doesFileExist path
    unless exists $ die (path ++ " does not exist (run `cozyll data fetch`)")
    idx <- loadCheckedIndex path
    bytes <- BS.readFile path
    text <- either (die . show) pure (decodeUtf8' bytes)
    when (encodeIndex idx /= text) $ die (path ++ ": not canonical (run `cozyll data fmt`)")
    putStrLn (path ++ " is valid (" ++ summary idx ++ ")")

-- | Rewrites the committed index canonically
runFormat :: FilePath -> Options -> IO ()
runFormat contentDir opts = do
    let path = dataDir contentDir opts </> indexFileName
    idx <- loadCheckedIndex path
    writeIndexFile path idx
    putStrLn ("formatted " ++ path)

-- | Prints the effective sources file, or copies the default with @--write@
runSources :: FilePath -> Options -> IO ()
runSources contentDir opts = do
    let path = sourcesFile contentDir opts
    if optWrite opts
        then do
            exists <- doesFileExist path
            when (exists && not (optForce opts)) $
                die (path ++ " exists (use --force to overwrite)")
            writeTextFileAtomic path (decodeUtf8 defaultSourcesYaml)
            putStrLn ("wrote " ++ path)
        else do
            bytes <- readSourcesFile path
            BS.putStr bytes
            when (optResolve opts) $ do
                manager <- newManager tlsManagerSettings
                token <- lookupEnv "GITHUB_TOKEN" <|> lookupEnv "GH_TOKEN"
                let fetch = httpFetch manager token
                sources <- loadSources path >>= either die pure
                resolved <- resolveSources fetch sources >>= either dieProblems pure
                putStrLn "\nresolved:"
                forM_ resolved $ \source ->
                    putStrLn (T.unpack (sourceId (resolvedSource source)) ++ ": " ++ T.unpack (sourceRef (resolvedSource source)))

-- | Compares the derived index with the committed one
checkIndex :: FilePath -> ByteString -> IO ()
checkIndex path expected = do
    exists <- doesFileExist path
    if not exists
        then die (path ++ " does not exist (run `cozyll data fetch`)")
        else do
            actual <- BS.readFile path
            if actual == expected
                then putStrLn "index is up to date"
                else die "index is out of date (run `cozyll data fetch`)"

-- | A short human-readable index summary
summary :: Index -> String
summary idx =
    show (length (idxKanji idx))
        ++ " kanji, "
        ++ show (length (idxWords idx))
        ++ " words, "
        ++ show (length (idxSegments idx))
        ++ " segments"

-- | Exits with every derivation issue
dieIssues :: [Issue] -> IO a
dieIssues issues = die (unlines [issueSource i ++ ": " ++ issueMessage i | i <- issues])

-- | Exits with every download or resolution problem
dieProblems :: [String] -> IO a
dieProblems = die . unlines

-- HTTP ------------------------------------------------------------------------

-- | A small HTTP downloader, injecting a GitHub token only for GitHub hosts
httpFetch :: Manager -> Maybe String -> String -> IO (Either String ByteString)
httpFetch manager token url = do
    request <- parseRequest url
    let headers =
            ("User-Agent", "cozyll")
                : case token of
                    Just value | isGithub url -> [("Authorization", "Bearer " <> encodeUtf8 (T.pack value))]
                    _ -> []
    response <- httpLbs request{requestHeaders = headers} manager
    let code = statusCode (responseStatus response)
        body = BL.toStrict (responseBody response)
    pure $ if code >= 200 && code < 300 then Right body else Left ("HTTP " ++ show code)

-- | Whether a URL belongs to GitHub (safe to attach a token)
isGithub :: String -> Bool
isGithub url = "https://github.com/" `isPrefixOf` url || "https://api.github.com/" `isPrefixOf` url || "https://raw.githubusercontent.com/" `isPrefixOf` url
