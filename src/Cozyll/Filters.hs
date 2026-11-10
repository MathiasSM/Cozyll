-- | Custom Pandoc filters, like the ruby-text transform
module Cozyll.Filters (processRubyText, processRubyTextWith) where

import Cozyll.Ruby (LevelSource (..), levelOf)
import Cozyll.Ruby.Index (RubyData, levelText)
import Data.Text (Text)
import Data.Text qualified as T
import Text.Pandoc (Inline (Link, RawInline, Str))

{- | Change special syntax (overloading Links) into ruby-annotated text

Ex. @[飯](-はん)@ into @<ruby>飯<rt>はん</rt></ruby>@

NOTE: Uses "RawInline" since there's no native AST representation

NOTE: Author should manually add @{lang=ja/ko/zh/...}@ for accesibility and using correct CJK font
-}
processRubyText :: Inline -> Inline
processRubyText = processRubyTextWith Nothing

{- | Like 'processRubyText', but with the derived index: adds @data-jlpt@ and
@data-jlpt-source@ attributes. Without an index the output is byte-identical to
the original filter.

The conversion rule is unchanged: every link whose target starts with @-@ becomes
ruby, whether or not the base is Japanese. The index only supplies the level.
-}
processRubyTextWith :: Maybe RubyData -> Inline -> Inline
processRubyTextWith rubyData x@(Link _ [Str base] (src, _)) =
    case T.uncons src of
        Just ('-', reading) -> RawInline "html" (rubyHtml rubyData base reading)
        _ -> x
processRubyTextWith _ x = x

rubyHtml :: Maybe RubyData -> Text -> Text -> Text
rubyHtml rubyData base reading =
    "<ruby"
        <> attributes
        <> ">"
        <> escapeHtml base
        <> "<rp>(</rp><rt>"
        <> escapeHtml reading
        <> "</rt><rp>)</rp></ruby>"
  where
    attributes = case rubyData of
        Nothing -> ""
        Just rubyData' ->
            let (level, source) = levelOf rubyData' base reading
             in " data-jlpt=\""
                    <> maybe "unknown" levelText level
                    <> "\" data-jlpt-source=\""
                    <> sourceName source
                    <> "\""

    sourceName FromWord = "word"
    sourceName FromKanji = "kanji"
    sourceName FromUnknown = "unknown"

escapeHtml :: Text -> Text
escapeHtml = T.concatMap escape
  where
    escape '&' = "&amp;"
    escape '<' = "&lt;"
    escape '>' = "&gt;"
    escape '"' = "&quot;"
    escape c = T.singleton c
