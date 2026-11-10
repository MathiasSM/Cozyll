-- | Rules for a post group: its index page and its posts
module Cozyll.Rules.PostGroup (processPostGroup) where

import Cozyll.CleanURL (pathRoute)
import Cozyll.Compile (applyTemplates, finish, runPandocWith)
import Cozyll.Config (SiteConfig, contentTemplate, postSnapshot, postTemplate, postsPattern, resolveTemplate, siteEnv, siteJaRubyCheck, siteRubyData)
import Cozyll.Content (isHidden, isTemplated, requirePost)
import Cozyll.Context (globalContext)
import Cozyll.Context.Aside (asideContext)
import Cozyll.Context.Author (resolveAuthors)
import Cozyll.Context.Nav (navContext)
import Cozyll.Context.SocialMeta (PageItem, PageKind (Article), PageMeta (pageMetaLanguage), pageItemOf, pageMetaOf, socialMetaContext)
import Cozyll.Localization (ogLocaleFor)
import Cozyll.Rules.SinglePages (Page (..), page, processPage)
import Cozyll.Theme (applyContentAsTemplate)
import Hakyll (
    Compiler,
    Context,
    Rules,
    boolField,
    compile,
    getMetadata,
    getResourceString,
    getUnderlying,
    listField,
    loadAllSnapshots,
    matchMetadata,
    metadataRoute,
    recentFirst,
    route,
    saveSnapshot,
 )

-- | Processes a group: its index page and all the item pages
processPostGroup :: SiteConfig -> String -> Rules ()
processPostGroup cfg groupName = do
    processPostGroupIndex cfg groupName
    processPostGroupItems cfg groupName

-- | Builds the group index page as an archive page
processPostGroupIndex :: SiteConfig -> String -> Rules ()
processPostGroupIndex cfg groupName =
    processPage
        cfg
        (page cfg groupName)
            { pageContext = getCtx cfg groupName
            , pageTemplates = [resolveTemplate cfg "with-posts.html"]
            , pageListItems = getItems cfg groupName
            }

{- | Builds each item/post page

Anything but a draft must have valid front matter, or the build fails.
-}
processPostGroupItems :: SiteConfig -> String -> Rules ()
processPostGroupItems cfg groupName =
    matchMetadata (postsPattern cfg groupName) (not . isHidden (siteEnv cfg)) $ do
        route $ metadataRoute pathRoute
        compile $ do
            _ <- requirePost
            templated <- isTemplated
            getResourceString
                >>= (if templated then applyContentAsTemplate cfg (globalContext cfg) else return)
                >>= runPandocWith (siteRubyData cfg) (siteJaRubyCheck cfg)
                >>= \(item', tocHtml, mainImg) -> do
                    metadata <- getUnderlying >>= getMetadata
                    let pageMeta = pageMetaOf cfg metadata
                        authors = resolveAuthors cfg metadata
                        ctx' = asideContext tocHtml <> globalContext cfg <> boolField "linkAuthors" (const True)
                    ogLocale <- ogLocaleFor cfg (pageMetaLanguage pageMeta)
                    saveSnapshot (postSnapshot groupName) item'
                        >>= applyTemplates ctx' [contentTemplate cfg, postTemplate cfg]
                        >>= finish cfg (socialMetaContext cfg Article authors [] pageMeta mainImg ogLocale <> navContext cfg groupName <> ctx')

-- | Build context for archive page
getCtx :: SiteConfig -> String -> Compiler (Context String)
getCtx cfg groupName = do
    posts <- recentFirst =<< loadAllSnapshots (postsPattern cfg groupName) (postSnapshot groupName)
    return $ listField "posts" (globalContext cfg) (return posts) <> globalContext cfg

-- | The items an archive page lists, for its ItemList structured data
getItems :: SiteConfig -> String -> Compiler [PageItem]
getItems cfg groupName = do
    posts <- recentFirst =<< loadAllSnapshots (postsPattern cfg groupName) (postSnapshot groupName)
    mapM (pageItemOf cfg) posts
