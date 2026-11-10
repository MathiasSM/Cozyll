-- | Level assignment and the build checks that run on rendered page bodies
module Cozyll.Ruby (LevelSource (..), levelOf, checkCoverage, checkReadings) where

import Cozyll.Ruby.Index (Level, RubyData (rdKanji, rdSegments, rdWords), isHan, levelRank, normalizeKey)
import Data.Char (isAsciiUpper)
import Data.List (maximumBy, nub, sortOn)
import Data.Map.Strict qualified as Maple
import Data.Maybe (maybeToList)
import Data.Ord (comparing)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as T
import Text.HTML.TagSoup (Tag (..), isTagCloseName, parseTags)

-- | Where a level came from
data LevelSource = FromWord | FromKanji | FromUnknown
    deriving (Eq, Show)

{- | Word first, then the hardest constituent kanji, else unknown.

@rdWords@ is keyed by the normalised surface and reading, so the caller does not
have to normalise.
-}
levelOf :: RubyData -> Text -> Text -> (Maybe Level, LevelSource)
levelOf rubyData base reading =
    case Maple.lookup (normalizeKey base, normalizeKey reading) (rdWords rubyData) of
        Just level -> (Just level, FromWord)
        Nothing -> case filter isHan (T.unpack (normalizeKey base)) of
            [] -> (Nothing, FromUnknown)
            chars -> case traverse charLevel chars of
                Just levels -> (Just (maximumBy (comparing levelRank) levels), FromKanji)
                Nothing -> (Nothing, FromUnknown)
  where
    charLevel c = Maple.lookup c (rdKanji rubyData) >>= snd

{- | Fails when a non-jōyō kanji in Japanese text is not inside a @<ruby>@ base.

@pageLang@ is the item's front matter language; elements may override it with
@lang=@. Only @ja*@ subtrees are inspected. @<rt>@, @<rp>@, whole @<ruby>@
sections, code-ish elements and the @rubySkip@ words are ignored.
-}
checkCoverage :: String -> [Text] -> RubyData -> String -> [String]
checkCoverage pageLang skipWords rubyData html =
    nub
        [ "non-jōyō kanji “" ++ [c] ++ "” in “" ++ T.unpack run ++ "” has no ruby"
        | (inJapanese, run) <- hanRuns
        , inJapanese
        , c <- T.unpack run
        , not (isJoyo c)
        ]
  where
    tags = skipSections (parseTags html)
    inJapaneseRuns = runsWithLanguage (rootLanguage pageLang) tags
    hanRuns =
        [ (ja, run)
        | (ja, text) <- inJapaneseRuns
        , run <- hanGroups (stripSkips text)
        , not (T.null run)
        ]
    stripSkips text = foldl' (\acc w -> T.replace w "" acc) text (sortOn (negate . T.length) skipWords)
    isJoyo c = case Maple.lookup c (rdKanji rubyData) of
        Just (Just grade, _) -> grade `elem` ([1 .. 6] ++ [8])
        _ -> False

hanGroups :: Text -> [Text]
hanGroups text =
    [ T.pack group
    | group@(c : _) <- groupByHan (T.unpack text)
    , isHan c
    ]

groupByHan :: [Char] -> [[Char]]
groupByHan [] = []
groupByHan (c : cs) =
    let (same, rest) = span ((== isHan c) . isHan) cs
     in (c : same) : groupByHan rest

-- | Page language, reduced to its primary subtag
rootLanguage :: String -> String
rootLanguage = takeWhile (/= '-') . map toLowerAscii

toLowerAscii :: Char -> Char
toLowerAscii c
    | isAsciiUpper c = toEnum (fromEnum c + 32)
    | otherwise = c

{- | Fails when a ruby reading is not attested in the derived index.

@allow@ entries are either a surface (@薔薇@) or a surface/reading pair
(@薔薇:ばら@). A base with no Han characters (katakana/emphasis ruby) is skipped.
-}
checkReadings :: [Text] -> RubyData -> String -> [String]
checkReadings allow rubyData html =
    nub
        [ "ruby [" ++ T.unpack base ++ "](-" ++ T.unpack reading ++ "): reading “" ++ T.unpack reading ++ "” not attested for “" ++ T.unpack base ++ "”"
        | (base, reading) <- rubyPairs (parseTags html)
        , T.any isHan base
        , not (T.null reading)
        , not (allowed base reading)
        , not (attested rubyData (normalizeKey base) (normalizeKey reading))
        ]
  where
    allowed base reading =
        any
            ( \entry -> case T.breakOn ":" entry of
                (surface, rest)
                    | T.null rest -> normalizeKey surface == normalizeKey base
                    | otherwise -> normalizeKey surface == normalizeKey base && normalizeKey (T.drop 1 rest) == normalizeKey reading
            )
            allow

-- | The (base, reading) pairs of every @<ruby>@ on the page
rubyPairs :: [Tag String] -> [(Text, Text)]
rubyPairs = go
  where
    go (TagOpen "ruby" _ : rest) =
        let (content, after) = break (isTagCloseName "ruby") rest
         in rubyPair content : go (drop 1 after)
    go (_ : rest) = go rest
    go [] = []

    rubyPair content =
        let (_, _, base, reading) = foldl' collect (False, False, T.empty, T.empty) content
         in (T.strip base, T.strip reading)

    collect (inRt, inRp, base, reading) tag = case tag of
        TagOpen "rt" _ -> (True, False, base, reading)
        TagClose "rt" -> (False, False, base, reading)
        TagOpen "rp" _ -> (inRt, True, base, reading)
        TagClose "rp" -> (inRt, False, base, reading)
        TagText text
            | inRt -> (inRt, inRp, base, reading <> T.pack text)
            | inRp -> (inRt, inRp, base, reading)
            | otherwise -> (inRt, inRp, base <> T.pack text, reading)
        _ -> (inRt, inRp, base, reading)

-- | Whether a (normalised) base/reading pair is attested
attested :: RubyData -> Text -> Text -> Bool
attested rubyData base reading
    | Maple.member (base, reading) (rdWords rubyData) = True
    | maybe False (Set.member reading) (Maple.lookup base (rdSegments rubyData)) = True
    | dp rubyData base reading = True
    | T.any (== '\x3005') base = dp rubyData (expandIteration base) reading
    | otherwise = False

{- | Dynamic programming over the segment table: literal kana edges plus every
attested run that matches a prefix of the remaining reading.
-}
dp :: RubyData -> Text -> Text -> Bool
dp rubyData base reading
    | baseLength > 512 || readingLength > 1024 = False
    | otherwise = search (Set.singleton (0, 0))
  where
    baseLength = T.length base
    readingLength = T.length reading

    search seen
        | Set.member (baseLength, readingLength) seen = True
        | Set.null next = False
        | otherwise = search (seen <> next)
      where
        next =
            Set.fromList
                [ position
                | (i, j) <- Set.toList seen
                , i < baseLength
                , j < readingLength
                , position <- step i j
                ]

    step i j =
        [(i + 1, j + 1) | not (isHan (T.index base i)), T.index base i == T.index reading j]
            <> [ (i + len, j + T.length rt)
               | len <- [1 .. min 32 (baseLength - i)]
               , let surface = T.take len (T.drop i base)
               , Just readings <- [Maple.lookup surface (rdSegments rubyData)]
               , rt <- Set.toList readings
               , rt `T.isPrefixOf` T.drop j reading
               ]

-- | Replaces @々@ with the preceding character
expandIteration :: Text -> Text
expandIteration = T.pack . go Nothing . T.unpack
  where
    go _ [] = []
    go previous ('\x3005' : rest) = maybeToList previous <> go previous rest
    go _ (c : rest) = c : go (Just c) rest

-- TagSoup walking -------------------------------------------------------------

{- | Drops whole sections of elements whose text must not be inspected. The tag
list is flat, so this is a depth-counted scan rather than a tree walk.
-}
skipSections :: [Tag String] -> [Tag String]
skipSections = go (0 :: Int)
  where
    go _ [] = []
    go depth (tag : rest) = case tag of
        TagOpen name _
            | name `elem` skippedElements -> go (depth + 1) rest
        TagClose name
            | name `elem` skippedElements -> go (max 0 (depth - 1)) rest
        _ | depth > 0 -> go depth rest
        _ -> tag : go depth rest

skippedElements :: [String]
skippedElements = ["rt", "rp", "ruby", "code", "pre", "kbd", "samp", "script", "style", "textarea"]

{- | Returns text nodes paired with whether their effective language is Japanese.

The page language is the root; a @lang@ attribute on an ancestor overrides it.
Void elements do not push a scope.
-}
runsWithLanguage :: String -> [Tag String] -> [(Bool, Text)]
runsWithLanguage root = go [root]
  where
    go _ [] = []
    go stack (tag : rest) = case tag of
        TagOpen name attrs ->
            let lang = maybe (current stack) (map toLowerAscii) (lookup "lang" attrs)
             in if name `elem` voidElements
                    then go stack rest
                    else go (lang : stack) rest
        TagClose _ -> go (drop 1 stack) rest
        TagText text -> (isJapanese (current stack), T.pack text) : go stack rest
        _ -> go stack rest

    current [] = root
    current (lang : _) = lang

    isJapanese lang =
        let primary = takeWhile (/= '-') lang
         in primary == "ja"

voidElements :: [String]
voidElements =
    [ "area"
    , "base"
    , "br"
    , "col"
    , "embed"
    , "hr"
    , "img"
    , "input"
    , "link"
    , "meta"
    , "param"
    , "source"
    , "track"
    , "wbr"
    ]
