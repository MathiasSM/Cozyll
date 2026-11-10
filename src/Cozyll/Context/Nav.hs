-- | The site menu, built from the pages that declare a nav entry
module Cozyll.Context.Nav (navContext) where

import Control.Monad (filterM)
import Cozyll.Config (SiteConfig, pagesPattern, siteEnv, siteLanguage)
import Cozyll.Content (isHidden, requireNav)
import Cozyll.Domain.Language (Language (..), languageCode)
import Cozyll.Domain.Nav (NavEntry (..), resolveNavLabel)
import Data.List (sortOn)
import Data.Maybe (catMaybes)
import Hakyll (
    Compiler,
    Context,
    Item (Item, itemBody, itemIdentifier),
    boolField,
    field,
    getMatches,
    getMetadata,
    listField,
    noResult,
    toFilePath,
 )
import System.FilePath.Posix (takeBaseName)

{- | The site menu as a @nav@ list (@label@, @href@, @active@, @lang@), built from the
pages that declare `nav:` and ordered by `navOrder`

@current@ is the name of the page being rendered (its file name without extension, or
its post group); that menu entry is @active@. @pageLanguage@ is the language of the
page being rendered: each label is resolved for it (see 'resolveNavLabel'), and an
entry whose rendered label is in another language carries a @lang@ attribute.
-}
navContext :: SiteConfig -> String -> String -> Context a
navContext cfg current pageLanguage = listField "nav" entryContext (navItems cfg)
  where
    entryContext =
        field "label" (fmap fst . resolved)
            <> field "href" (return . navHref . itemBody)
            <> boolField "active" ((== current) . takeBaseName . toFilePath . itemIdentifier)
            <> field "lang" langOf

    resolved item =
        either
            (\problem -> fail $ toFilePath (itemIdentifier item) ++ ": " ++ problem)
            pure
            (resolveNavLabel (Language pageLanguage) (siteLanguage cfg) (itemBody item))

    langOf item = do
        (_, language) <- resolved item
        if languageCode language == pageLanguage
            then noResult "the page's own language"
            else pure $ languageCode language

navItems :: SiteConfig -> Compiler [Item NavEntry]
navItems cfg = do
    pages <- getMatches $ pagesPattern cfg "*"
    visible <- filterM (fmap (not . isHidden (siteEnv cfg)) . getMetadata) pages
    entries <- mapM (\page -> fmap (Item page) <$> requireNav cfg page) visible
    return $ sortOn (navOrder . itemBody) $ catMaybes entries
