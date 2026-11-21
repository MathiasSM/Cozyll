{- | Per-page aside: the labeled controls (toggles) and the table of contents.

A control is a checkbox in a page's aside that toggles a CSS class on @<html>@
(for example @no-images@), so elements can be shown or hidden by class.

The pieces of a control:

  * a front-matter key whose value is the control's label;
  * a @Cozyll.Metadata.Key@ constructor and its @keyName@ case;
  * membership in @controlKeys@;
  * a @toggleLabelField <Key> "<name>ToggleLabel"@ line in 'asideContext' (the
      label is rendered from inline markdown);
  * the control's partial, and a gated @<li>@ in @site-aside.html@;
  * the CSS rule that hides elements while the class is set.

The ruby level control is special: its @<select>@ stores the reader's JLPT
threshold in @localStorage@, and ruby whose level is not in the index is always
shown (it is not a JLPT level). Checkboxes toggle a class on @<html>@.

'hasAnyControl' and 'hasAside' gate whether the aside renders at all. The
step-by-step recipe lives in @CONTRIBUTING.md@ ("Adding a control (toggle)").
-}
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
controlKeys = [RubyToggle, RubyControl, ImagesToggle]

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
        <> tocLabelField metadata
        <> toggleLabelField metadata RubyToggle "rubyToggleLabel"
        <> toggleLabelField metadata RubyControl "rubyControlLabel"
        <> toggleLabelField metadata ImagesToggle "imagesToggleLabel"
        <> boolFieldM "hasControls" (\_ -> hasAnyControl <$> metadata)
        <> boolFieldM "hasAside" (\_ -> hasAside <$> metadata)
  where
    -- every field of a context is evaluated on its own, so the action is what is shared
    metadata :: Compiler Metadata
    metadata = getUnderlying >>= getMetadata

    tocField "" _ = noResult "no toc"
    tocField html _ = return html

-- | Exposes the table of contents label (markdown-rendered), defaulting to "Contents"
tocLabelField :: Compiler Metadata -> Context String
tocLabelField metadata = field "tocLabel" $ \_ -> do
    o <- metadata
    case tocLabelOf o of
        Just label -> return (renderInlineMarkdown label)
        Nothing -> noResult "no toc"

-- | Exposes a toggle's front-matter label, rendered from markdown to inline HTML
toggleLabelField :: Compiler Metadata -> Key -> String -> Context String
toggleLabelField metadata k name = field name $ \_ -> do
    o <- metadata
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
