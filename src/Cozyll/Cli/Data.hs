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
import Cozyll.Ruby.Derive (Issue (..), Upstream (..), deriveIndex, readUpstreamFrom)
import Cozyll.Ruby.Index (
    Index (..),
    Level (..),
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
import Data.Text (Text)
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

data Flag
    = FlagFrom FilePath
    | FlagDataDir FilePath
    | FlagSources FilePath
    | FlagCheck
    | FlagWrite
    | FlagForce
    | FlagResolve
    | FlagHelp
    | FlagVersion
    deriving (Eq)

-- | Every flag; commands accept a subset (see 'allowedFlags')
options :: [OptDescr Flag]
options =
    [ Option ['h'] ["help"] (NoArg FlagHelp) "show this help"
    , Option [] ["version"] (NoArg FlagVersion) "show the cozyll version"
    , Option [] ["from"] (ReqArg FlagFrom "DIR") "read upstream files from DIR instead of downloading"
    , Option [] ["data-dir"] (ReqArg FlagDataDir "DIR") "ruby-data directory (default: <content>/ruby-data)"
    , Option [] ["sources"] (ReqArg FlagSources "FILE") "sources file (default: <data-dir>/sources.yaml)"
    , Option [] ["check"] (NoArg FlagCheck) "derive and compare without writing"
    , Option [] ["write"] (NoArg FlagWrite) "copy the default sources file into place"
    , Option [] ["force"] (NoArg FlagForce) "overwrite an existing sources file"
    , Option [] ["resolve"] (NoArg FlagResolve) "resolve latest refs via the GitHub API"
    ]

-- | The long name of a flag, for error messages
flagName :: Flag -> String
flagName = \case
    FlagFrom _ -> "--from"
    FlagDataDir _ -> "--data-dir"
    FlagSources _ -> "--sources"
    FlagCheck -> "--check"
    FlagWrite -> "--write"
    FlagForce -> "--force"
    FlagResolve -> "--resolve"
    FlagHelp -> "--help"
    FlagVersion -> "--version"

-- | The flags each command accepts
allowedFlags :: String -> [String]
allowedFlags command = case command of
    "fetch" -> ["--from", "--data-dir", "--sources", "--check"]
    "verify" -> ["--data-dir"]
    "fmt" -> ["--data-dir"]
    "sources" -> ["--data-dir", "--sources", "--write", "--force", "--resolve"]
    _ -> []

-- | Parses the arguments after @cozyll data@
parseCommand :: [String] -> Either String Command
parseCommand [] = Right Help
parseCommand (arg : _) | arg `elem` ["-h", "--help"] = Right Help
parseCommand (arg : _) | arg == "--version" = Right Version
parseCommand (command : rest) = do
    flags <- parseFlags rest
    if FlagHelp `elem` flags
        then Right Help
        else
            if FlagVersion `elem` flags
                then Right Version
                else do
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

    applyFlag allowed opts flag
        | flagName flag `notElem` allowed =
            Left (flagName flag ++ " is not valid for this command")
        | otherwise = case flag of
            FlagFrom dir -> Right opts{optFrom = Just dir}
            FlagDataDir dir -> Right opts{optDataDir = Just dir}
            FlagSources file -> Right opts{optSources = Just file}
            FlagCheck -> Right opts{optCheck = True}
            FlagWrite -> Right opts{optWrite = True}
            FlagForce -> Right opts{optForce = True}
            FlagResolve -> Right opts{optResolve = True}
            FlagHelp -> Right opts
            FlagVersion -> Right opts

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
    either die pure (toUpstream (concatMap downloadedFiles downloaded))

-- | Turns the downloaded logical files into the derivation input
toUpstream :: [(Text, ByteString)] -> Either String Upstream
toUpstream files = do
    kanji <- need "kanji.json"
    n5 <- need "n5.csv"
    n4 <- need "n4.csv"
    n3 <- need "n3.csv"
    n2 <- need "n2.csv"
    n1 <- need "n1.csv"
    jmdict <- need "JmdictFurigana.json"
    let jmnedict = fromMaybe BS.empty (lookup "JmnedictFurigana.json" files)
    pure (Upstream kanji (zip [N5, N4, N3, N2, N1] [n5, n4, n3, n2, n1]) jmdict jmnedict)
  where
    need name =
        maybe
            (Left ("downloaded sources are missing " ++ T.unpack name))
            Right
            (lookup name files)

-- | Validates the committed index (canonical form and size)
runVerify :: FilePath -> Options -> IO ()
runVerify contentDir opts = do
    let path = dataDir contentDir opts </> indexFileName
    exists <- doesFileExist path
    unless exists $ die (path ++ " does not exist (run `cozyll data fetch`)")
    limit <- indexLimitIO
    size <- getFileSize path
    when (size > fromIntegral limit) $ die (path ++ ": index is larger than " ++ show limit ++ " bytes")
    idx <- readIndexFile path >>= either die pure
    bytes <- BS.readFile path
    text <- either (die . show) pure (decodeUtf8' bytes)
    when (encodeIndex idx /= text) $ die (path ++ ": not canonical (run `cozyll data fmt`)")
    putStrLn (path ++ " is valid (" ++ summary idx ++ ")")

-- | Rewrites the committed index canonically
runFormat :: FilePath -> Options -> IO ()
runFormat contentDir opts = do
    let path = dataDir contentDir opts </> indexFileName
    limit <- indexLimitIO
    size <- getFileSize path
    when (size > fromIntegral limit) $ die (path ++ ": index is larger than " ++ show limit ++ " bytes")
    idx <- readIndexFile path >>= either die pure
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
