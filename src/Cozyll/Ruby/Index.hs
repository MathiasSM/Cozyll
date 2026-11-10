{- | The derived ruby index: schema, canonical encoding, normalisation, and lookup structures.

The index is Japanese-specific: 'Level' is a JLPT level (N1–N5), 'KanjiRow' is a
Japanese kanji with its school grade and JLPT level, and 'WordRow'/'SegmentRow'
pair Japanese surfaces with kana readings. Ruby itself is a generic HTML
annotation (pinyin, bopomofo, furigana); this module only models the Japanese
furigana use case.
-}
module Cozyll.Ruby.Index (
    -- * Levels
    Level (..),
    levelRank,
    levelText,
    parseLevel,

    -- * Index
    Index (..),
    KanjiRow (..),
    WordRow (..),
    SegmentRow (..),
    emptyIndex,
    encodeIndex,
    decodeIndex,
    toRubyData,
    RubyData (..),

    -- * Normalisation
    normalizeKey,
    isHan,
    isKana,

    -- * Files
    dataDirName,
    indexFileName,
    indexPath,
    readIndexFile,
    loadIndexFile,
    writeIndexFile,
    writeTextFileAtomic,

    -- * Limits
    defaultMaxIndexBytes,
    indexLimitIO,
) where

import Control.Monad (unless, when)
import Data.Aeson (Value (..), eitherDecodeStrict')
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap (KeyMap)
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Text (encodeToLazyText)
import Data.Bifunctor (first)
import Data.ByteString qualified as BS
import Data.Char (isSpace, ord)
import Data.Foldable (toList)
import Data.List (groupBy, sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Scientific (toBoundedInteger)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding (decodeUtf8', encodeUtf8)
import Data.Text.Encoding.Error (UnicodeException)
import Data.Text.Lazy qualified as TL
import Data.Text.Normalize (NormalizationMode (NFC, NFKC), normalize)
import System.Directory (createDirectoryIfMissing, doesFileExist, getFileSize, renameFile)
import System.Environment (lookupEnv)
import System.Exit (die)
import System.FilePath.Posix (takeDirectory, (</>))
import System.IO (hClose, openBinaryTempFile)
import Text.Read (readMaybe)

-- Levels ----------------------------------------------------------------------

{- | A JLPT level. The derived index only stores levels that are known; "unknown"
is a runtime bucket, not a stored value.
-}
data Level = N1 | N2 | N3 | N4 | N5
    deriving (Eq, Ord, Show, Enum, Bounded)

-- | Difficulty rank: N5 = 1 (easiest) … N1 = 5 (hardest)
levelRank :: Level -> Int
levelRank = \case
    N5 -> 1
    N4 -> 2
    N3 -> 3
    N2 -> 4
    N1 -> 5

-- | The wire spelling, e.g. @n5@
levelText :: Level -> Text
levelText = \case
    N1 -> "n1"
    N2 -> "n2"
    N3 -> "n3"
    N4 -> "n4"
    N5 -> "n5"

-- | Parses a wire spelling; anything else is 'Nothing' (callers decide whether that is an error)
parseLevel :: Text -> Maybe Level
parseLevel = \case
    "n1" -> Just N1
    "n2" -> Just N2
    "n3" -> Just N3
    "n4" -> Just N4
    "n5" -> Just N5
    _ -> Nothing

-- Index -----------------------------------------------------------------------

-- | One row of the @kanji@ table: character, school grade (if any), JLPT level (if any)
data KanjiRow = KanjiRow
    { krChar :: Char
    , krGrade :: Maybe Int
    , krJlpt :: Maybe Level
    }
    deriving (Eq, Ord, Show)

-- | One @(surface, reading) → level@ row
data WordRow = WordRow
    { wrSurface :: Text
    , wrReading :: Text
    , wrLevel :: Level
    }
    deriving (Eq, Ord, Show)

-- | One @(kanji run, reading)@ alignment row
data SegmentRow = SegmentRow
    { srSurface :: Text
    , srReading :: Text
    }
    deriving (Eq, Ord, Show)

-- | The on-disk index, before it is turned into lookup maps
data Index = Index
    { idxKanji :: [KanjiRow]
    , idxWords :: [WordRow]
    , idxSegments :: [SegmentRow]
    }
    deriving (Eq, Show)

emptyIndex :: Index
emptyIndex = Index [] [] []

-- | The runtime form: maps built once at startup
data RubyData = RubyData
    { rdKanji :: Map Char (Maybe Int, Maybe Level)
    , rdWords :: Map (Text, Text) Level
    , rdSegments :: Map Text (Set Text)
    }

toRubyData :: Index -> RubyData
toRubyData idx =
    RubyData
        { rdKanji = Map.fromList [(krChar r, (krGrade r, krJlpt r)) | r <- idxKanji idx]
        , rdWords = Map.fromList [((wrSurface r, wrReading r), wrLevel r) | r <- idxWords idx]
        , rdSegments = Map.fromListWith Set.union [(srSurface r, Set.singleton (srReading r)) | r <- idxSegments idx]
        }

-- Encoding --------------------------------------------------------------------

{- | Canonical serialisation: fixed top-level order, one tuple per line, sorted, LF,
exactly one trailing newline. Hand-written so the byte layout (and therefore the
git diff) is stable; @aeson-pretty@ would split each tuple across lines.
-}
encodeIndex :: Index -> Text
encodeIndex idx =
    T.concat
        [ "{\n"
        , "  \"schemaVersion\": 1,\n"
        , "  \"derivationVersion\": 1,\n"
        , "  \"kanji\": "
        , renderArray (map renderKanji (sortOn krChar (idxKanji idx)))
        , ",\n"
        , "  \"words\": "
        , renderArray (map renderWord (sortOn wordKey (idxWords idx)))
        , ",\n"
        , "  \"segments\": "
        , renderArray (map renderSegment (sortOn segmentKey (idxSegments idx)))
        , "\n"
        , "}\n"
        ]
  where
    wordKey r = (wrSurface r, wrReading r)
    segmentKey r = (srSurface r, srReading r)

    renderArray [] = "[]"
    renderArray rows = "[\n" <> T.intercalate ",\n" (map ("    " <>) rows) <> "\n  ]"

    renderKanji r =
        "["
            <> jsonText (T.singleton (krChar r))
            <> ", "
            <> maybe "null" (T.pack . show) (krGrade r)
            <> ", "
            <> maybe "null" (jsonText . levelText) (krJlpt r)
            <> "]"
    renderWord r =
        "["
            <> jsonText (wrSurface r)
            <> ", "
            <> jsonText (wrReading r)
            <> ", "
            <> jsonText (levelText (wrLevel r))
            <> "]"
    renderSegment r = "[" <> jsonText (srSurface r) <> ", " <> jsonText (srReading r) <> "]"

jsonText :: Text -> Text
jsonText = TL.toStrict . encodeToLazyText . String

-- Decoding --------------------------------------------------------------------

decodeIndex :: Text -> Either String Index
decodeIndex text = do
    value <- eitherDecodeStrict' (encodeUtf8 text)
    obj <- asObject "index.json" value
    schema <- required "schemaVersion" obj >>= asInt "schemaVersion"
    unless (schema == 1) $ Left ("unsupported schemaVersion " ++ show schema ++ " (this cozyll supports 1)")
    derivation <- required "derivationVersion" obj >>= asInt "derivationVersion"
    unless (derivation == 1) $ Left ("unsupported derivationVersion " ++ show derivation ++ " (this cozyll supports 1)")
    kanji <- required "kanji" obj >>= asArray "kanji" >>= traverse decodeKanjiRow
    wordRows <- required "words" obj >>= asArray "words" >>= traverse decodeWordRow
    segments <- required "segments" obj >>= asArray "segments" >>= traverse decodeSegmentRow
    let idx = Index kanji wordRows segments
    _ <- validateIndex idx
    pure idx

decodeKanjiRow :: Value -> Either String KanjiRow
decodeKanjiRow value = do
    xs <- asArray "kanji row" value
    case xs of
        [c, g, l] -> do
            chars <- asText "kanji[0]" c
            ch <- case T.unpack chars of
                [x] -> Right x
                _ -> Left "kanji[0] must be exactly one character"
            grade <- asMaybeInt "kanji[1]" g
            lvl <- asMaybeLevel "kanji[2]" l
            pure (KanjiRow ch grade lvl)
        _ -> Left "kanji row must have 3 elements"

decodeWordRow :: Value -> Either String WordRow
decodeWordRow value = do
    xs <- asArray "word row" value
    case xs of
        [s, r, l] -> WordRow <$> asText "word[0]" s <*> asText "word[1]" r <*> asLevel "word[2]" l
        _ -> Left "word row must have 3 elements"

decodeSegmentRow :: Value -> Either String SegmentRow
decodeSegmentRow value = do
    xs <- asArray "segment row" value
    case xs of
        [s, r] -> SegmentRow <$> asText "segment[0]" s <*> asText "segment[1]" r
        _ -> Left "segment row must have 2 elements"

validateIndex :: Index -> Either String Index
validateIndex idx = do
    checkSortedUnique "kanji" krChar (idxKanji idx)
    checkSortedUnique "words" wordKey (idxWords idx)
    checkSortedUnique "segments" segmentKey (idxSegments idx)
    mapM_ (checkNormalized "words.surface" . wrSurface) (idxWords idx)
    mapM_ (checkNormalized "words.reading" . wrReading) (idxWords idx)
    mapM_ (checkNormalized "segments.surface" . srSurface) (idxSegments idx)
    mapM_ (checkNormalized "segments.reading" . srReading) (idxSegments idx)
    pure idx
  where
    wordKey r = (wrSurface r, wrReading r)
    segmentKey r = (srSurface r, srReading r)

checkSortedUnique :: (Ord k) => String -> (a -> k) -> [a] -> Either String ()
checkSortedUnique label key rows
    | sorted && unique = Right ()
    | not sorted = Left (label ++ " must be sorted")
    | otherwise = Left (label ++ " contains duplicates")
  where
    keys = map key rows
    sorted = keys == sortOn id keys
    unique = length keys == length (Set.toList (Set.fromList keys))

checkNormalized :: String -> Text -> Either String ()
checkNormalized label value =
    unless (normalizeKey value == value) $
        Left (label ++ " is not normalised (run `cozyll data fmt`)")

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

asInt :: String -> Value -> Either String Int
asInt label (Number n) = maybe (Left (label ++ " must be an integer")) Right (toBoundedInteger n)
asInt label _ = Left (label ++ " must be an integer")

asMaybeInt :: String -> Value -> Either String (Maybe Int)
asMaybeInt _ Null = Right Nothing
asMaybeInt label v = Just <$> asInt label v

asLevel :: String -> Value -> Either String Level
asLevel label v = do
    t <- asText label v
    maybe (Left (label ++ " is not a JLPT level")) Right (parseLevel t)

asMaybeLevel :: String -> Value -> Either String (Maybe Level)
asMaybeLevel _ Null = Right Nothing
asMaybeLevel label v = Just <$> asLevel label v

-- Normalisation ---------------------------------------------------------------

{- | Canonical form for lookup keys (never applied to rendered text):

1. NFKC on runs of non-Han characters (composes NFD, folds half-width kana and
   full-width Latin, but leaves Han code points alone so name kanji such as
   @﨑@ and @崎@ stay distinct);
2. katakana → hiragana (including @ヵ@/@ヶ@ → @か@);
3. case fold;
4. strip whitespace;
5. NFC.

Deliberately not folded: @ぢ/じ@, @づ/ず@, @を/お@, @ー@, small vs large kana.
-}
normalizeKey :: Text -> Text
normalizeKey =
    normalize NFC
        . T.filter (not . isSpace)
        . T.toCaseFold
        . T.map foldKana
        . normalizeRuns
  where
    normalizeRuns = T.concat . map normalizeRun . groupBy sameClass . T.unpack
    sameClass a b = isHan a == isHan b
    normalizeRun [] = ""
    normalizeRun chars@(c : _)
        | isHan c = T.pack chars
        | otherwise = normalize NFKC (T.pack chars)

    foldKana c
        | c == '\x30F5' || c == '\x30F6' = 'か'
        | c >= '\x30A1' && c <= '\x30F6' = toEnum (ord c - 0x60)
        | otherwise = c

-- | Whether a character is a Han ideograph (compatibility ideographs included)
isHan :: Char -> Bool
isHan c =
    any
        (\(lo, hi) -> n >= lo && n <= hi)
        [ (0x3400, 0x4DBF)
        , (0x4E00, 0x9FFF)
        , (0xF900, 0xFAFF)
        , (0x20000, 0x2A6DF)
        , (0x2A700, 0x2B73F)
        , (0x2B740, 0x2B81F)
        , (0x2B820, 0x2CEAF)
        , (0x2CEB0, 0x2EBEF)
        , (0x2EBF0, 0x2EE5F)
        , (0x30000, 0x3134F)
        , (0x31350, 0x323AF)
        ]
  where
    n = ord c

-- | Whether a character is kana
isKana :: Char -> Bool
isKana c =
    let n = ord c
     in (n >= 0x3040 && n <= 0x309F) || (n >= 0x30A0 && n <= 0x30FF) || (n >= 0x31F0 && n <= 0x31FF)

-- Files -----------------------------------------------------------------------

dataDirName :: FilePath
dataDirName = "ruby-data"

indexFileName :: FilePath
indexFileName = "index.json"

-- | The index path for a content root
indexPath :: FilePath -> FilePath
indexPath contentDir = contentDir </> dataDirName </> indexFileName

{- | The default limit for an index file, in bytes (8 MiB). Overridable with
@COZYLL_RUBY_INDEX_LIMIT@; see 'indexLimitIO'.
-}
defaultMaxIndexBytes :: Int
defaultMaxIndexBytes = 8 * 1024 * 1024

{- | The configured index size limit: @COZYLL_RUBY_INDEX_LIMIT@ in bytes, or
'defaultMaxIndexBytes'. This is a sanity bound (a corrupt or misplaced file),
not a security boundary; it is configurable so consumers never have to rebuild.
-}
indexLimitIO :: IO Int
indexLimitIO = do
    value <- lookupEnv "COZYLL_RUBY_INDEX_LIMIT"
    case value of
        Nothing -> pure defaultMaxIndexBytes
        Just raw -> maybe (die ("invalid COZYLL_RUBY_INDEX_LIMIT \"" ++ raw ++ "\"")) pure (readMaybe raw)

-- | Reads and parses an index without requiring canonical bytes (for @data fmt@)
readIndexFile :: FilePath -> IO (Either String Index)
readIndexFile path = do
    bytes <- BS.readFile path
    pure $ do
        text <- first show (decodeUtf8' bytes)
        decodeIndex text

{- | Loads and validates an index, rejecting files larger than @limit@ bytes.
@Right Nothing@ when the file is absent (the build then behaves exactly as
before this feature).
-}
loadIndexFile :: Int -> FilePath -> IO (Either String (Maybe RubyData))
loadIndexFile limit path = do
    exists <- doesFileExist path
    if not exists
        then pure (Right Nothing)
        else do
            size <- getFileSize path
            if size > fromIntegral limit
                then pure (Left (path ++ ": index is larger than " ++ show limit ++ " bytes"))
                else do
                    bytes <- BS.readFile path
                    pure $ do
                        text <- first describeUnicode (decodeUtf8' bytes)
                        when (T.isPrefixOf "\xFEFF" text) $ Left (path ++ ": starts with a BOM")
                        idx <- first ((path ++ ": ") ++) (decodeIndex text)
                        when (encodeIndex idx /= text) $
                            Left (path ++ ": not canonical (run `cozyll data fmt`)")
                        pure (Just (toRubyData idx))
  where
    describeUnicode :: UnicodeException -> String
    describeUnicode = show

-- | Writes the index atomically (temp file in the same directory + rename)
writeIndexFile :: FilePath -> Index -> IO ()
writeIndexFile path = writeTextFileAtomic path . encodeIndex

-- | Writes UTF-8 text atomically
writeTextFileAtomic :: FilePath -> Text -> IO ()
writeTextFileAtomic path text = do
    let dir = takeDirectory path
    createDirectoryIfMissing True dir
    (tmp, handle) <- openBinaryTempFile dir ".tmp"
    BS.hPut handle (encodeUtf8 text)
    hClose handle
    renameFile tmp path
