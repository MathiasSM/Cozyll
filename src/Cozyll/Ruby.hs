-- | Level assignment and the build checks that run on rendered page bodies
module Cozyll.Ruby (LevelSource (..), levelOf, checkCoverage) where

import Cozyll.Ruby.Index (Level, RubyData (rdKanji, rdWords), isHan, levelRank, normalizeKey)
import Data.Char (isAsciiUpper)
import Data.List (maximumBy, nub, sortOn)
import Data.Map.Strict qualified as Maple
import Data.Ord (comparing)
import Data.Text (Text)
import Data.Text qualified as T
import Text.HTML.TagSoup (Tag (..), parseTags)

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
