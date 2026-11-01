{- | Resolving content-provided themes: templates and styles that override the
vendored defaults, file by file.
-}
module Cozyll.Theme (
    discoverContentTemplateNames,
    rewritePartials,
    rewritingTemplateCompiler,
    applyContentAsTemplate,
) where

import Control.Monad (filterM)
import Cozyll.Config (SiteConfig, resolveTemplate, templatesDir)
import Data.List (isPrefixOf, stripPrefix)
import Hakyll (
    Compiler,
    Context,
    Item,
    Template,
    applyAsTemplate,
    compileTemplateItem,
    getResourceString,
    toFilePath,
 )
import System.Directory (doesDirectoryExist, doesFileExist, listDirectory)
import System.FilePath.Posix (addTrailingPathSeparator, (</>))

{- | Lists the template names a content dir provides (empty when the dir is absent).

Discovery is top-level only: @listDirectory@ is intentionally non-recursive, matching
'Cozyll.Config.templatePattern' (a @/*@ glob), so templates in nested directories are
neither discovered nor shadowable.
-}
discoverContentTemplateNames :: FilePath -> IO [FilePath]
discoverContentTemplateNames dir = do
    present <- doesDirectoryExist dir
    if not present
        then pure []
        else filterM (doesFileExist . (dir </>)) =<< listDirectory dir

{- | Compiles a template, rewriting its @$partial("templates/…")$@ paths through
the override map so content-provided partials are picked up.
-}
rewritingTemplateCompiler :: SiteConfig -> Compiler (Item Template)
rewritingTemplateCompiler cfg = do
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
