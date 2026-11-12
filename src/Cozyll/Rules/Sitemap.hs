-- | Rules that build the sitemap
module Cozyll.Rules.Sitemap (processSitemap) where

import Control.Applicative ((<|>))
import Control.Monad (filterM, forM)
import Cozyll.CleanURL (cleanIndexHtmls)
import Cozyll.Config (SiteConfig, pagesPattern, postsPattern, resolveTemplate, siteInputFingerprint)
import Cozyll.Content (isIndex, isSitemapExcluded)
import Cozyll.Context (globalContext)
import Cozyll.Context.Author (authorPages, authorPosts)
import Cozyll.Discover (discoverGroups)
import Cozyll.Metadata qualified as K
import Cozyll.Rules.AuthorPages (authorPageIdentifier)
import Cozyll.Theme (themeFingerprint)
import Data.Maybe (catMaybes)
import Data.Time (Day, defaultTimeLocale, formatTime)
import Data.Time.Format (parseTimeM)
import Hakyll (
    Compiler,
    Context (..),
    ContextField (..),
    Identifier,
    Item,
    Metadata,
    Rules,
    compile,
    create,
    getMetadata,
    idRoute,
    itemIdentifier,
    listField,
    load,
    loadAll,
    loadAndApplyTemplate,
    makeItem,
    noResult,
    recentFirst,
    route,
 )

-- | Builds sitemap.xml from the standalone pages, every post group, and the author pages
processSitemap :: SiteConfig -> Rules ()
processSitemap cfg = create ["sitemap.xml"] $ do
    route idRoute
    compile $ do
        siteInputFingerprint cfg
        themeFingerprint cfg
        groups <- discoverGroups cfg
        postsByGroup <- forM groups $ \group -> recentFirst =<< loadAll (postsPattern cfg group)
        pages <- loadAll $ pagesPattern cfg "*"
        authors <- mapM (load . authorPageIdentifier cfg) (authorPages cfg)

        -- Newest effective date (`lastModifiedAt`, else `date`) of each group's posts
        latestByGroup <- forM (zip groups postsByGroup) $ \(group, ps) -> do
            days <- catMaybes <$> mapM itemModified ps
            pure (group, latestOf days)
        let groupLatest = [(g, d) | (g, Just d) <- latestByGroup]
            siteLatest = latestOf [d | (_, Just d) <- latestByGroup]

        -- A derived `lastModifiedAt` for the home page and each group index: the newest
        -- of their own front-matter date and the newest date among their posts
        pageOverrides <- forM pages $ \item -> do
            let ident = itemIdentifier item
            meta <- getMetadata ident
            let own = modifiedOf meta
                derived
                    | isHome meta = newer own siteLatest
                    | isIndex meta = newer own (K.lookupKey K.Group meta >>= (`lookup` groupLatest))
                    | otherwise = Nothing
            pure ((,) ident . renderDay <$> derived)

        -- A derived `lastModifiedAt` for each author page: its newest post's date
        authorOverrides <-
            forM (zip (authorPages cfg) authors) $ \(author, item) -> do
                posts <- authorPosts cfg author
                days <- catMaybes <$> mapM itemModified posts
                pure ((,) (itemIdentifier item) . renderDay <$> latestOf days)

        let overrides = catMaybes pageOverrides <> catMaybes authorOverrides
            allItems = filterM isIndexable (pages <> concat postsByGroup <> authors)
            sitemapCtx =
                listField "entries" (sitemapLastmod overrides <> globalContext cfg) allItems
                    <> globalContext cfg
        makeItem ""
            >>= loadAndApplyTemplate (resolveTemplate cfg "sitemap.xml") sitemapCtx
            >>= cleanIndexHtmls

{- | Adds a derived @lastModifiedAt@ only to the pages the sitemap computes it for;
every other item falls through to its own metadata (the template already
prefers @lastModifiedAt@, then @date@)
-}
sitemapLastmod :: [(Identifier, String)] -> Context String
sitemapLastmod overrides = Context $ \key _ item ->
    if key /= "lastModifiedAt"
        then noResult ("missing field '" ++ key ++ "' in sitemap lastmod context")
        else case lookup (itemIdentifier item) overrides of
            Just day -> pure (StringField day)
            Nothing -> noResult "lastModifiedAt"

-- | Whether an item should appear in the sitemap (not marked `sitemap: false`)
isIndexable :: Item String -> Compiler Bool
isIndexable item = not . isSitemapExcluded <$> getMetadata (itemIdentifier item)

-- | Whether the page is the home page (`home: true` in front matter)
isHome :: Metadata -> Bool
isHome meta = K.lookupKey K.Home meta == Just "true"

-- | An item's effective last-modified date: @lastModifiedAt@, falling back to @date@
itemModified :: Item String -> Compiler (Maybe Day)
itemModified item = modifiedOf <$> getMetadata (itemIdentifier item)

-- | A front-matter date: @lastModifiedAt@, falling back to @date@
modifiedOf :: Metadata -> Maybe Day
modifiedOf meta =
    (K.lookupKey K.LastModifiedAt meta >>= parseDay)
        <|> (K.lookupKey K.Date meta >>= parseDay)

-- | A @YYYY-MM-DD@ value
parseDay :: String -> Maybe Day
parseDay = parseTimeM True defaultTimeLocale "%Y-%m-%d"

renderDay :: Day -> String
renderDay = formatTime defaultTimeLocale "%Y-%m-%d"

-- | The newest date of a (possibly empty) list
latestOf :: [Day] -> Maybe Day
latestOf [] = Nothing
latestOf xs = Just (maximum xs)

-- | The newer of two optional dates, preferring a present one
newer :: Maybe Day -> Maybe Day -> Maybe Day
newer a b = case (a, b) of
    (Just x, Just y) -> Just (max x y)
    (Just x, Nothing) -> Just x
    (Nothing, Just y) -> Just y
    _ -> Nothing
