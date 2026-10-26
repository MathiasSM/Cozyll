-- | Pandoc compilation and the post-processing shared by every page
module Cozyll.Compile (runPandoc, applyTemplates, finish) where

import Control.Monad (foldM)
import Cozyll.Accessibility (checkAccessibility)
import Cozyll.CleanURL (cleanIndexHtmls, cleanIndexUrls)
import Cozyll.Config (SiteConfig, siteTemplate)
import Cozyll.Content (tocLabelOf)
import Cozyll.Context.SocialMeta (MainImage, mainImageOf)
import Cozyll.Filters (processRubyText)
import Cozyll.Html (readonlyCheckboxes)
import Data.Maybe (isJust)
import Hakyll (
    Compiler,
    Context,
    Identifier,
    Item (itemBody),
    defaultHakyllReaderOptions,
    defaultHakyllWriterOptions,
    getMetadata,
    getUnderlying,
    loadAndApplyTemplate,
    readPandocWith,
    relativizeUrls,
    writePandocWith,
 )
import Text.Pandoc (Pandoc (Pandoc), nullMeta)
import Text.Pandoc.Options (MathMethod (MathJax), writerMathMethod)
import Text.Pandoc.Walk (walk)
import Text.Pandoc.Writers.Shared (toTableOfContents)

-- TODO(citeproc): Citations are left unprocessed today -- `Ext_citations` is on
-- via `pandocExtensions`, but no citeproc/bibliography is configured, so `@key`
-- in prose renders as a bare `<span class="citation">`. If a bibliography (or
-- citeproc) is ever added, literal `@` in content must be escaped as `\@`, or
-- those fragments will silently turn into citations.

{- | Custom configuration for Pandoc, returning the rendered body, the table
of contents (when @TOC@ is set), and the page's main image (when one is tagged
@#main-image@), so templates can place the TOC separately and social metadata
can use the image.
-}
runPandoc :: Item String -> Compiler (Item String, String, Maybe MainImage)
runPandoc item = do
    metadata <- getUnderlying >>= getMetadata
    let toc = isJust (tocLabelOf metadata)
    pandocItem <- readPandocWith defaultHakyllReaderOptions item
    let pandoc' = walk processRubyText (itemBody pandocItem)
        body = renderPandoc pandocItem pandoc'
        tocHtml = if toc then "<nav id=\"TOC\">" ++ renderPandoc pandocItem (tocPandoc pandoc') ++ "</nav>" else ""
    pure (item{itemBody = body}, tocHtml, mainImageOf (itemBody pandocItem))
  where
    renderPandoc ident pandoc = itemBody (writePandocWith writerOptions (ident{itemBody = pandoc}))

    tocPandoc pandoc = Pandoc nullMeta [toTableOfContents writerOptions (blocksOf pandoc)]

    blocksOf (Pandoc _ blocks) = blocks

    writerOptions =
        defaultHakyllWriterOptions
            { writerMathMethod = MathJax ""
            }

-- | Applies the given templates in order, each wrapping the previous result
applyTemplates :: Context String -> [Identifier] -> Item String -> Compiler (Item String)
applyTemplates ctx templates item = foldM (\i t -> loadAndApplyTemplate t ctx i) item templates

-- | Factors out the final common default steps for basically all pages
finish :: SiteConfig -> Context String -> Item String -> Compiler (Item String)
finish cfg context item =
    applyTemplates context [siteTemplate cfg] item
        >>= relativizeUrls
        >>= cleanIndexUrls
        >>= cleanIndexHtmls
        >>= return . fmap readonlyCheckboxes
        >>= checkAccessibility
