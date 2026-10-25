-- | Per-page aside: the labeled controls (toggles) and the table of contents
module Cozyll.Context.Aside (
    asideContext,
    hasAnyControl,
    hasAside,
    renderInlineMarkdown,
) where

import Cozyll.Content (tocLabelOf)
import Cozyll.Metadata (Key (..), keyName, lookupKey)
import Data.Maybe (isJust)
import Data.Text qualified as T
import Hakyll (
    Compiler,
    Context,
    Metadata,
    boolFieldM,
    defaultHakyllReaderOptions,
    defaultHakyllWriterOptions,
    field,
    getMetadata,
    getUnderlying,
    noResult,
 )
import Text.Pandoc (
    Block (Para, Plain),
    Pandoc (Pandoc),
    nullMeta,
    readMarkdown,
    runPure,
    writeHtml5String,
 )

-- | The labeled toggles the controls menu can show; each key's value is its label
controlKeys :: [Key]
controlKeys = [RubyToggle, ImagesToggle]

-- | Whether any labeled toggle is enabled on the page
hasAnyControl :: Metadata -> Bool
hasAnyControl o = any (\k -> maybe False (not . null) (lookupKey k o)) controlKeys

-- | Whether the aside has anything to show: a control, or a table of contents
hasAside :: Metadata -> Bool
hasAside o = hasAnyControl o || isJust (tocLabelOf o)

{- | The context the aside (and its templates) render with. @tocHtml@ is the
table-of-contents markup produced by "Cozyll.Compile" (@""@ when none).
-}
asideContext :: String -> Context String
asideContext tocHtml =
    field "toc" (tocField tocHtml)
        <> tocLabelField
        <> toggleLabelField RubyToggle "rubyToggleLabel"
        <> toggleLabelField ImagesToggle "imagesToggleLabel"
        <> boolFieldM "hasControls" (\_ -> hasAnyControl <$> metadata)
        <> boolFieldM "hasAside" (\_ -> hasAside <$> metadata)
  where
    metadata = getUnderlying >>= getMetadata

    tocField "" _ = noResult "no toc"
    tocField html _ = return html

-- | Exposes the table of contents label (markdown-rendered), defaulting to "Contents"
tocLabelField :: Context String
tocLabelField = field "tocLabel" $ \_ -> do
    o <- getUnderlying >>= getMetadata
    case tocLabelOf o of
        Just label -> return (renderInlineMarkdown label)
        Nothing -> noResult "no toc"

-- | Exposes a toggle's front-matter label, rendered from markdown to inline HTML
toggleLabelField :: Key -> String -> Context String
toggleLabelField k name = field name $ \_ -> do
    o <- getUnderlying >>= getMetadata
    case lookupKey k o of
        Just label -> return (renderInlineMarkdown label)
        Nothing -> noResult $ keyName k ++ ": not set"

-- | Renders a short markdown fragment as inline HTML (no wrapping @\<p\>@)
renderInlineMarkdown :: String -> String
renderInlineMarkdown md =
    case runPure $ do
        Pandoc _ blocks <- readMarkdown defaultHakyllReaderOptions (T.pack md)
        let inline = Pandoc nullMeta [Plain (concatMap inlines blocks)]
        writeHtml5String defaultHakyllWriterOptions inline of
        Left _ -> md
        Right html -> T.unpack html
  where
    inlines (Para is) = is
    inlines (Plain is) = is
    inlines _ = []
