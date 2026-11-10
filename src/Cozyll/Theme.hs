{- | Resolving content-provided themes: templates and styles that override the
vendored defaults, file by file.
-}
module Cozyll.Theme (
    discoverContentTemplateNames,
    themeFingerprint,
    rewritePartials,
    rewritingTemplateCompiler,
    applyContentAsTemplate,
) where

import Control.Monad (filterM, void)
import Cozyll.Config (SiteConfig, resolveTemplate, templatePattern, templatesDir)
import Data.List (isPrefixOf, stripPrefix)
import Hakyll (
    Compiler,
    Context,
    Identifier,
    Item,
    Template,
    applyAsTemplate,
    compileTemplateItem,
    getMatches,
    getResourceString,
    loadAll,
    toFilePath,
 )
import System.Directory (doesDirectoryExist, doesFileExist, listDirectory)
import System.FilePath.Posix (addTrailingPathSeparator, (</>))

-- | Lists the template names a content dir provides (empty when the dir is absent).
discoverContentTemplateNames :: FilePath -> IO [FilePath]
discoverContentTemplateNames dir = do
    present <- doesDirectoryExist dir
    if not present
        then pure []
        else filterM (doesFileExist . (dir </>)) =<< listDirectory dir

{- | Makes the current item depend on the *set* of available templates, so
adding or removing a @content\/templates\/…@ override marks it out of date.

Hakyll decides what to rebuild from the previous run's dependency set: a new
override is a new 'Hakyll.Core.Identifier.Identifier' that nothing references
yet, so it would be ignored until a clean build. 'loadAll' instead records a
'Hakyll.Core.Dependencies.PatternDependency', whose match set is re-checked on
every run; a changed match set invalidates every dependent item. Compiling the
templates here adds no output, because they are already built as rules.
-}
themeFingerprint :: SiteConfig -> Compiler ()
themeFingerprint cfg = void (loadAll (templatePattern cfg) :: Compiler [Item Template])

{- | Compiles a template, rewriting its @$partial("templates/…")$@ paths through
the override map so content-provided partials are picked up.

The template also depends on the whole template pattern: an override added
since the last run changes how the partials are rewritten, so the compiled
template must not be reused. It records the pattern with 'getMatches' rather
than 'themeFingerprint', because loading the pattern would require the very
template being compiled.
-}
rewritingTemplateCompiler :: SiteConfig -> Compiler (Item Template)
rewritingTemplateCompiler cfg = do
    void (getMatches (templatePattern cfg) :: Compiler [Identifier])
    item <- getResourceString
    tpl <- compileTemplateItem (fmap (rewritePartials cfg) item)
    pure (fmap (const tpl) item)

{- | Applies a content body as a template, rewriting its @$partial("templates/…")$@
paths through the override map first, so templated posts and pages resolve
content-provided partials just like template files do.
-}
applyContentAsTemplate :: SiteConfig -> Context String -> Item String -> Compiler (Item String)
applyContentAsTemplate cfg ctx = applyAsTemplate ctx . fmap (rewritePartials cfg)

{- | Rewrites every @$partial("templates/<name>")$@ to the identifier 'resolveTemplate'
picks; any other @$partial$@ (e.g. @$partial("content/…")$@) is left untouched.
-}
rewritePartials :: SiteConfig -> String -> String
rewritePartials cfg = go
  where
    open = "$partial(\""
    vendoredPrefix = addTrailingPathSeparator (templatesDir cfg)

    go [] = []
    go s@(c : cs)
        | open `isPrefixOf` s =
            let body = drop (length open) s
                (path, afterQuote) = break (== '"') body
                rest = drop 1 afterQuote
                rewritten = case stripPrefix vendoredPrefix path of
                    Just name -> toFilePath (resolveTemplate cfg name)
                    Nothing -> path
             in open ++ rewritten ++ "\"" ++ go rest
        | otherwise = c : go cs
