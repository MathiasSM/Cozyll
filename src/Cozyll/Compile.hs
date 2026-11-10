-- | Pandoc compilation and the post-processing shared by every page
module Cozyll.Compile (runPandoc, runPandocWith, applyTemplates, finish) where

import Control.Monad (foldM, forM_, unless)
import Control.Monad.Except (throwError)
import Cozyll.Accessibility (checkAccessibility)
import Cozyll.CleanURL (cleanIndexHtmls, cleanIndexUrls)
import Cozyll.Config (SiteConfig, siteTemplate)
import Cozyll.Content (tocLabelOf)
import Cozyll.Context.SocialMeta (MainImage, mainImageOf)
import Cozyll.Domain.Website (CheckMode (..), parseCheckMode)
import Cozyll.Filters (processRubyTextWith)
import Cozyll.Html (readonlyCheckboxes)
import Cozyll.Metadata (Key (Language, RubyAllow, RubyCheck, RubySkip), lookupKey, lookupKeyList)
import Cozyll.Ruby (checkCoverage, checkReadings)
import Cozyll.Ruby.Index (RubyData)
import Data.Maybe (fromMaybe, isJust)
import Data.Text qualified as T
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
    toFilePath,
    unsafeCompiler,
    writePandocWith,
 )
import System.IO (hPutStrLn, stderr)
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
runPandoc = runPandocWith Nothing CheckError

-- | Like 'runPandoc', but annotates ruby and checks the body against the ruby index
runPandocWith :: Maybe RubyData -> CheckMode -> Item String -> Compiler (Item String, String, Maybe MainImage)
runPandocWith rubyData checkMode item = do
    metadata <- getUnderlying >>= getMetadata
    let toc = isJust (tocLabelOf metadata)
    pandocItem <- readPandocWith defaultHakyllReaderOptions item
    let pandoc' = walk (processRubyTextWith rubyData) (itemBody pandocItem)
        body = renderPandoc pandocItem pandoc'
        tocHtml = if toc then "<nav id=\"TOC\">" ++ renderPandoc pandocItem (tocPandoc pandoc') ++ "</nav>" else ""
    checkCoverageWith rubyData metadata body
    pure (item{itemBody = body}, tocHtml, mainImageOf (itemBody pandocItem))
  where
    checkCoverageWith Nothing _ _ = pure ()
    checkCoverageWith (Just rubyData') metadata body = do
        path <- toFilePath <$> getUnderlying
        let pageLang = fromMaybe "en" (lookupKey Language metadata)
            skipWords = maybe [] (map T.pack) (lookupKeyList RubySkip metadata)
            allowReadings = maybe [] (map T.pack) (lookupKeyList RubyAllow metadata)
            problems =
                map
                    ((path ++ ": ") ++)
                    (checkCoverage pageLang skipWords rubyData' body <> checkReadings allowReadings rubyData' body)
            effective = maybe checkMode (fromMaybe checkMode . parseCheckMode) (lookupKey RubyCheck metadata)
        case effective of
            CheckOff -> pure ()
            CheckWarn -> unsafeCompiler (forM_ problems (hPutStrLn stderr))
            CheckError -> unless (null problems) (throwError problems)

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
