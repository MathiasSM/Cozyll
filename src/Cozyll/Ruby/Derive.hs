-- | Pure derivation of the ruby index from the upstream files
module Cozyll.Ruby.Derive (
    Upstream (..),
    Issue (..),
    deriveIndex,
    readUpstreamFrom,
) where

import Control.Monad (forM, unless)
import Cozyll.Ruby.Index (
    Index (..),
    KanjiRow (..),
    Level (..),
    SegmentRow (..),
    WordRow (..),
    isKana,
    levelRank,
    normalizeKey,
 )
import Data.Aeson (Value (..), eitherDecodeStrict')
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap (KeyMap)
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Bifunctor (first)
import Data.ByteString (ByteString)
import Data.ByteString qualified as BS
import Data.Either (partitionEithers)
import Data.Foldable (toList)
import Data.List (sortOn)
import Data.Map.Strict qualified as Map
import Data.Maybe (catMaybes, isJust, mapMaybe)
import Data.Scientific (toBoundedInteger)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding (decodeUtf8')
import System.Directory (doesFileExist)
import System.FilePath.Posix ((</>))

-- | One upstream problem. Derivation fails rather than silently producing a partial index.
data Issue = Issue
    { issueSource :: String
    , issueMessage :: String
    }
    deriving (Eq, Show)

-- | The raw contents of every upstream file
data Upstream = Upstream
    { upKanji :: ByteString
    , upLevels :: [(Level, ByteString)]
    , upJmdict :: ByteString
    , upJmnedict :: ByteString
    }

{- | Derives the index. Fails with every problem found (the caller prints them all).
Conflicting word levels resolve to the easiest level; kana-only word rows are dropped.
-}
deriveIndex :: Upstream -> Either [Issue] Index
deriveIndex upstream = do
    kanji <- withSource "kanji-data" (parseKanji (upKanji upstream))
    wordRows <- concat <$> traverse (uncurry parseWords) (upLevels upstream)
    jmdict <- withSource "jmdict-furigana" (parseFurigana (upJmdict upstream))
    jmnedict <-
        if BS.null (upJmnedict upstream)
            then Right []
            else withSource "jmnedict-furigana" (parseFurigana (upJmnedict upstream))
    pure (buildIndex kanji wordRows (jmdict <> jmnedict))
  where
    withSource source = first (\message -> [Issue source message])
    parseWords level bytes =
        first (pure . Issue ("yomitan-jlpt-vocab/n" ++ T.unpack (levelSuffix level))) (parseWordCsv level bytes)

    levelSuffix N1 = "1"
    levelSuffix N2 = "2"
    levelSuffix N3 = "3"
    levelSuffix N4 = "4"
    levelSuffix N5 = "5"

{- | Reads the upstream files from a directory (used by @data fetch --from@ and the tests).
@JmnedictFurigana.json@ is optional; the rest are required.
-}
readUpstreamFrom :: FilePath -> IO (Either [Issue] Upstream)
readUpstreamFrom dir = do
    results <- traverse readRequired requiredNames
    case partitionEithers results of
        (issues@(_ : _), _) -> pure (Left issues)
        ([], [kanji, n5, n4, n3, n2, n1, jmdict]) -> do
            jmnedict <- readOptional (dir </> "JmnedictFurigana.json")
            pure $ Right $ Upstream kanji (zip [N5, N4, N3, N2, N1] [n5, n4, n3, n2, n1]) jmdict jmnedict
        _ -> pure (Left [Issue dir "unexpected upstream file set"])
  where
    requiredNames =
        [ "kanji.json"
        , "n5.csv"
        , "n4.csv"
        , "n3.csv"
        , "n2.csv"
        , "n1.csv"
        , "JmdictFurigana.json"
        ]

    readRequired name = do
        let path = dir </> name
        exists <- doesFileExist path
        if exists
            then Right <$> BS.readFile path
            else pure (Left (Issue path "not found"))

    readOptional path = do
        exists <- doesFileExist path
        if exists then BS.readFile path else pure BS.empty

-- Parsing: kanji --------------------------------------------------------------

parseKanji :: ByteString -> Either String [KanjiRow]
parseKanji bytes = do
    value <- decodeJson bytes
    obj <- asObject "kanji.json" value
    catMaybes <$> forM (KeyMap.toList obj) (uncurry parseKanjiEntry)
  where
    parseKanjiEntry key value = do
        let chars = Key.toText key
        ch <- case T.unpack chars of
            [c] -> Right c
            _ -> Left ("kanji.json: key " ++ show chars ++ " is not one character")
        obj <- asObject "kanji.json entry" value
        grade <- maybe (Right Nothing) (asMaybeInt "grade") (KeyMap.lookup "grade" obj)
        jlptNew <- maybe (Right Nothing) (asMaybeInt "jlpt_new") (KeyMap.lookup "jlpt_new" obj)
        let level = jlptNew >>= levelFromNew
            keep = maybe False (\g -> g `elem` ([1 .. 6] ++ [8])) grade || isJust level
        pure $ if keep then Just (KanjiRow ch grade level) else Nothing

    levelFromNew n = case n of
        1 -> Just N1
        2 -> Just N2
        3 -> Just N3
        4 -> Just N4
        5 -> Just N5
        _ -> Nothing

-- Parsing: words --------------------------------------------------------------

parseWordCsv :: Level -> ByteString -> Either String [WordRow]
parseWordCsv level bytes = do
    text <- first show (decodeUtf8' bytes)
    let text' = if T.isPrefixOf "\xFEFF" text then T.drop 1 text else text
        rows = [parseCsvLine (T.dropWhileEnd (== '\r') line) | line <- T.lines text', not (T.null (T.strip line))]
        rows' = case rows of
            (header : rest) | "jmdict_seq" `elem` header -> rest
            _ -> rows
    pure $ mapMaybe (toWord level) rows'
  where
    toWord lvl fields = case drop 1 fields of
        (kana : kanji : _) ->
            let surface = normalizeKey (T.strip kanji)
                reading = normalizeKey (T.strip kana)
             in if T.null surface then Nothing else Just (WordRow surface reading lvl)
        _ -> Nothing

-- | A small RFC 4180-ish parser: quoted fields, @""@ escapes, commas inside quotes
parseCsvLine :: Text -> [Text]
parseCsvLine = go False ([] :: [Text]) ([] :: [Char]) . T.unpack
  where
    go _ fields current [] = reverse (T.pack (reverse current) : fields)
    go inQuotes fields current (c : rest)
        | inQuotes && c == '"' = case rest of
            ('"' : more) -> go True fields ('"' : current) more
            _ -> go False fields current rest
        | not inQuotes && c == '"' = go True fields current rest
        | not inQuotes && c == ',' = go False (T.pack (reverse current) : fields) [] rest
        | otherwise = go inQuotes fields (c : current) rest

-- Parsing: furigana -----------------------------------------------------------

parseFurigana :: ByteString -> Either String [SegmentRow]
parseFurigana bytes = do
    value <- decodeJson bytes
    entries <- asArray "furigana file" value
    concat <$> traverse parseEntry entries

parseEntry :: Value -> Either String [SegmentRow]
parseEntry value = do
    obj <- asObject "furigana entry" value
    text <- required "text" obj >>= asText "text"
    parts <- required "furigana" obj >>= asArray "furigana"
    parsed <- traverse parsePart parts
    let concatenated = T.concat (map fst parsed)
    unless (concatenated == text) $
        Left ("furigana entry " ++ show text ++ ": parts do not concatenate to the text")
    pure
        [ SegmentRow (normalizeKey ruby) (normalizeKey rt)
        | (ruby, Just rt) <- parsed
        , not (T.null rt)
        , T.any (not . isKana) ruby
        ]
  where
    parsePart part = do
        obj <- asObject "furigana part" part
        ruby <- required "ruby" obj >>= asText "ruby"
        rt <- case KeyMap.lookup "rt" obj of
            Nothing -> Right Nothing
            Just Null -> Right Nothing
            Just v -> Just <$> asText "rt" v
        pure (ruby, rt)

-- Building --------------------------------------------------------------------

buildIndex :: [KanjiRow] -> [WordRow] -> [SegmentRow] -> Index
buildIndex kanji wordRows segments =
    Index
        { idxKanji = sortOn krChar kanji
        , idxWords = [WordRow surface reading lvl | ((surface, reading), lvl) <- Map.toList wordMap]
        , idxSegments = sortOn (\r -> (srSurface r, srReading r)) (Set.toList segmentSet)
        }
  where
    wordMap = Map.fromListWith easier [((wrSurface r, wrReading r), wrLevel r) | r <- wordRows]
    easier new old = if levelRank new <= levelRank old then new else old
    segmentSet = Set.fromList segments

-- JSON helpers ----------------------------------------------------------------

decodeJson :: ByteString -> Either String Value
decodeJson = first show . eitherDecodeStrict' . stripBom

stripBom :: ByteString -> ByteString
stripBom bytes
    | BS.take 3 bytes == BS.pack [0xEF, 0xBB, 0xBF] = BS.drop 3 bytes
    | otherwise = bytes

asObject :: String -> Value -> Either String (KeyMap Value)
asObject _ (Object o) = Right o
asObject label _ = Left (label ++ " must be an object")

asArray :: String -> Value -> Either String [Value]
asArray _ (Array a) = Right (toList a)
asArray label _ = Left (label ++ " must be an array")

required :: String -> KeyMap Value -> Either String Value
required name obj = maybe (Left ("missing field " ++ name)) Right (KeyMap.lookup (Key.fromText (T.pack name)) obj)

asText :: String -> Value -> Either String Text
asText _ (String t) = Right t
asText label _ = Left (label ++ " must be a string")

asMaybeInt :: String -> Value -> Either String (Maybe Int)
asMaybeInt _ Null = Right Nothing
asMaybeInt _ (Number n) = maybe (Left "expected an integer") (Right . Just) (toBoundedInteger n)
asMaybeInt label _ = Left (label ++ " must be an integer")
