-- | @cozyll data ...@: download/derive, verify, and canonicalise the ruby index
module DataCommand (runDataCommand) where

import Codec.Archive.Zip qualified as Zip
import Control.Monad (unless, when)
import Cozyll.Cli (contentDirIO)
import Cozyll.Ruby.Data (
    Index (..),
    Level (..),
    dataDirName,
    decodeIndex,
    encodeIndex,
    indexFileName,
    loadIndexFile,
    manifestFileName,
    sha256Hex,
    writeIndexFile,
    writeTextFileAtomic,
 )
import Cozyll.Ruby.Derive (Issue (..), Upstream (..), deriveIndex, readUpstreamFrom)
import Cozyll.Ruby.Manifest (Manifest (..), Source (..), decodeManifest, encodeManifest, verifyManifest)
import Data.ByteString (ByteString)
import Data.ByteString qualified as BS
import Data.ByteString.Lazy qualified as BL
import Data.Text qualified as T
import Data.Text.Encoding (decodeUtf8', encodeUtf8)
import Network.HTTP.Client (httpLbs, newManager, parseRequest, responseBody, responseStatus)
import Network.HTTP.Client.TLS (tlsManagerSettings)
import Network.HTTP.Types.Status (statusCode)
import System.Directory (doesFileExist)
import System.Exit (die, exitFailure)
import System.FilePath.Posix (takeDirectory, (</>))

data Options = Options
    { optFrom :: Maybe FilePath
    , optDataDir :: Maybe FilePath
    , optCheck :: Bool
    }

runDataCommand :: [String] -> IO ()
runDataCommand args = case args of
    ("fetch" : rest) -> fetch rest
    ("verify" : rest) -> verify rest
    ("fmt" : rest) -> format rest
    ("manifest" : rest) -> rehash rest
    ("--help" : _) -> usage
    ("-h" : _) -> usage
    _ -> usage

usage :: IO ()
usage = do
    putStrLn "Usage: cozyll data <fetch|verify|fmt|manifest> [--from DIR] [--data-dir DIR] [--check]"
    putStrLn ""
    putStrLn "  fetch     download (or read --from) the upstream files, derive ruby-data/index.json"
    putStrLn "  verify    validate index.json against its schema and manifest.json"
    putStrLn "  fmt       rewrite index.json canonically"
    putStrLn "  manifest  re-hash index.json after a hand edit"
    exitFailure

-- Commands --------------------------------------------------------------------

fetch :: [String] -> IO ()
fetch args = do
    opts <- parseOptions args
    (upstream, sources) <- case optFrom opts of
        Just dir -> do
            parsed <- readUpstreamFrom dir
            result <- either dieIssues pure parsed
            sources <- localSources dir
            pure (result, sources)
        Nothing -> downloadUpstream
    idx <- either dieIssues pure (deriveIndex upstream)
    let indexText = encodeIndex idx
        bytes = encodeUtf8 indexText
    path <- indexPathFor opts
    if optCheck opts
        then checkIndex path bytes
        else do
            writeTextFileAtomic path indexText
            writeTextFileAtomic (takeDirectory path </> manifestFileName) $
                encodeManifest (Manifest sources (sha256Hex bytes) (BS.length bytes))
            putStrLn $ "wrote " ++ path ++ " (" ++ summary idx ++ ")"

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

verify :: [String] -> IO ()
verify args = do
    opts <- parseOptions args
    dir <- dataDirFor opts
    let path = dir </> indexFileName
        manifest = dir </> manifestFileName
    exists <- doesFileExist path
    unless exists $ die (path ++ " does not exist")
    bytes <- BS.readFile path
    text <- either (die . show) pure (decodeUtf8' bytes)
    idx <- either die pure (decodeIndex text)
    when (encodeIndex idx /= text) $ die (path ++ ": not canonical (run `cozyll data fmt`)")
    manifestExists <- doesFileExist manifest
    if manifestExists
        then do
            mtext <- either (die . show) pure . decodeUtf8' =<< BS.readFile manifest
            mf <- either die pure (decodeManifest mtext)
            either die pure (verifyManifest mf bytes)
            putStrLn $ path ++ " is valid (" ++ summary idx ++ ")"
        else putStrLn (path ++ " is valid (no manifest.json: provenance not recorded)")

format :: [String] -> IO ()
format args = do
    opts <- parseOptions args
    dir <- dataDirFor opts
    let path = dir </> indexFileName
    loaded <- loadIndexFile path
    case loaded of
        Left problem -> die problem
        Right Nothing -> die (path ++ " does not exist")
        Right (Just _) -> do
            bytes <- BS.readFile path
            text <- either (die . show) pure (decodeUtf8' bytes)
            idx <- either die pure (decodeIndex text)
            writeIndexFile path idx
            putStrLn ("formatted " ++ path)

rehash :: [String] -> IO ()
rehash args = do
    opts <- parseOptions args
    dir <- dataDirFor opts
    let path = dir </> indexFileName
        manifest = dir </> manifestFileName
    bytes <- BS.readFile path
    text <- either (die . show) pure (decodeUtf8' bytes)
    idx <- either die pure (decodeIndex text)
    mf <-
        doesFileExist manifest >>= \case
            False -> pure (Manifest [] "" 0)
            True -> do
                mtext <- either (die . show) pure . decodeUtf8' =<< BS.readFile manifest
                either die pure (decodeManifest mtext)
    let updated = mf{manifestIndexHash = sha256Hex (encodeUtf8 (encodeIndex idx)), manifestIndexBytes = BS.length (encodeUtf8 (encodeIndex idx))}
    writeTextFileAtomic manifest (encodeManifest updated)
    putStrLn ("re-hashed " ++ manifest)

-- Options ---------------------------------------------------------------------

parseOptions :: [String] -> IO Options
parseOptions = go (Options Nothing Nothing False)
  where
    go opts [] = pure opts
    go opts (arg : rest) = case arg of
        "--from" -> case rest of
            (dir : more) -> go opts{optFrom = Just dir} more
            [] -> die "--from needs a directory"
        "--data-dir" -> case rest of
            (dir : more) -> go opts{optDataDir = Just dir} more
            [] -> die "--data-dir needs a directory"
        "--check" -> go opts{optCheck = True} rest
        _ -> die ("unknown option " ++ arg)

dataDirFor :: Options -> IO FilePath
dataDirFor opts = case optDataDir opts of
    Just dir -> pure dir
    Nothing -> (</> dataDirName) <$> contentDirectory

indexPathFor :: Options -> IO FilePath
indexPathFor opts = (</> indexFileName) <$> dataDirFor opts

contentDirectory :: IO FilePath
contentDirectory = contentDirIO

summary :: Index -> String
summary idx =
    show (length (idxKanji idx))
        ++ " kanji, "
        ++ show (length (idxWords idx))
        ++ " words, "
        ++ show (length (idxSegments idx))
        ++ " segments"

dieIssues :: [Issue] -> IO a
dieIssues issues = die (unlines [issueSource i ++ ": " ++ issueMessage i | i <- issues])

-- Upstream --------------------------------------------------------------------

localSources :: FilePath -> IO [Source]
localSources dir = do
    kanji <- hashFile "kanji.json"
    levels <- traverse hashFile ["n5.csv", "n4.csv", "n3.csv", "n2.csv", "n1.csv"]
    jmdict <- hashFile "JmdictFurigana.json"
    let files name = do
            let path = dir </> name
            exists <- doesFileExist path
            if exists then (: []) <$> hashFile name else pure []
    jmnedict <- files "JmnedictFurigana.json"
    pure
        [ Source "kanji-data" "local" "MIT" [kanji]
        , Source "yomitan-jlpt-vocab" "local" "CC-BY-SA-4.0" levels
        , Source "jmdict-furigana" "local" "CC-BY-SA-4.0" [jmdict]
        , Source "jmnedict-furigana" "local" "CC-BY-SA-4.0" jmnedict
        ]
  where
    hashFile name = do
        let path = dir </> name
        exists <- doesFileExist path
        if not exists
            then pure (T.pack name, "", 0)
            else do
                bytes <- BS.readFile path
                pure (T.pack name, sha256Hex bytes, BS.length bytes)

downloadUpstream :: IO (Upstream, [Source])
downloadUpstream = do
    manager <- newManager tlsManagerSettings
    let get url = do
            request <- parseRequest url
            response <- httpLbs request manager
            let code = statusCode (responseStatus response)
            when (code < 200 || code >= 300) $ die (url ++ ": HTTP " ++ show code)
            pure (BL.toStrict (responseBody response))
        raw repo ref path = "https://raw.githubusercontent.com/" ++ repo ++ "/" ++ ref ++ "/" ++ path
        asset name = "https://github.com/Doublevil/JmdictFurigana/releases/download/" ++ releaseTag ++ "/" ++ name

    kanji <- get (raw "davidluzgouveia/kanji-data" kanjiRef "kanji.json")
    n5 <- get (raw "stephenmk/yomitan-jlpt-vocab" yomitanRef "original_data/n5.csv")
    n4 <- get (raw "stephenmk/yomitan-jlpt-vocab" yomitanRef "original_data/n4.csv")
    n3 <- get (raw "stephenmk/yomitan-jlpt-vocab" yomitanRef "original_data/n3.csv")
    n2 <- get (raw "stephenmk/yomitan-jlpt-vocab" yomitanRef "original_data/n2.csv")
    n1 <- get (raw "stephenmk/yomitan-jlpt-vocab" yomitanRef "original_data/n1.csv")
    jmdictZip <- get (asset "JmdictFurigana.json.zip")
    jmnedictZip <- get (asset "JmnedictFurigana.json.zip")
    jmdict <- extractEntry jmdictZip "JmdictFurigana.json"
    jmnedict <- extractEntry jmnedictZip "JmnedictFurigana.json"
    let sources =
            [ Source "kanji-data" (T.pack kanjiRef) "MIT" [("kanji.json", sha256Hex kanji, BS.length kanji)]
            , Source
                "yomitan-jlpt-vocab"
                (T.pack yomitanRef)
                "CC-BY-SA-4.0"
                [ (T.pack ("original_data/n" ++ show n ++ ".csv"), sha256Hex bytes, BS.length bytes)
                | (n, bytes) <- [(5 :: Int, n5), (4, n4), (3, n3), (2, n2), (1, n1)]
                ]
            , Source "jmdict-furigana" (T.pack releaseTag) "CC-BY-SA-4.0" [("JmdictFurigana.json.zip", sha256Hex jmdictZip, BS.length jmdictZip)]
            , Source "jmnedict-furigana" (T.pack releaseTag) "CC-BY-SA-4.0" [("JmnedictFurigana.json.zip", sha256Hex jmnedictZip, BS.length jmnedictZip)]
            ]
    pure (Upstream kanji (zip [N5, N4, N3, N2, N1] [n5, n4, n3, n2, n1]) jmdict jmnedict, sources)
  where
    kanjiRef = "00fd7079c3890f430759536f91aa5e854ec0ca4f"
    yomitanRef = "b062d4e38c4bdd0950ae1d4ec55f04b176182e03"
    releaseTag = "2.3.1%2B2026-10-25"

extractEntry :: ByteString -> String -> IO ByteString
extractEntry zipBytes name =
    case Zip.findEntryByPath name (Zip.toArchive (BL.fromStrict zipBytes)) of
        Nothing -> die ("downloaded archive has no " ++ name)
        Just entry -> pure (BL.toStrict (Zip.fromEntry entry))
