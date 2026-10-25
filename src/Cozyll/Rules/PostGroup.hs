-- | Rules for a post group: its index page and its posts
module Cozyll.Rules.PostGroup (processPostGroup) where

import Cozyll.CleanURL (pathRoute)
import Cozyll.Compile (applyTemplates, finish, runPandoc)
import Cozyll.Config (SiteConfig, minimalTemplate, postSnapshot, postTemplate, postsPattern, resolveTemplate, siteEnv)
import Cozyll.Content (isHidden, isTemplated, requirePost)
import Cozyll.Context (globalContext, postSocialTagsContext)
import Cozyll.Context.Aside (asideContext)
import Cozyll.Context.Nav (navContext)
import Cozyll.Context.Post (postContext)
import Cozyll.Rules.SinglePages (Page (..), page, processPage)
import Cozyll.Theme (applyContentAsTemplate)
import Hakyll (
    Compiler,
    Context,
    Rules,
    compile,
    getResourceString,
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
    processPage cfg (page cfg groupName){pageContext = getCtx cfg groupName, pageTemplates = [resolveTemplate cfg "with-posts.html"]}

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
                >>= runPandoc
                >>= \(item', tocHtml) ->
                    let ctx' = postContext cfg <> asideContext tocHtml <> globalContext cfg
                     in saveSnapshot (postSnapshot groupName) item'
                            >>= applyTemplates ctx' [minimalTemplate cfg, postTemplate cfg]
                            >>= finish cfg (postSocialTagsContext cfg <> navContext cfg groupName <> ctx')

-- | Build context for archive page
getCtx :: SiteConfig -> String -> Compiler (Context String)
getCtx cfg groupName = do
    posts <- recentFirst =<< loadAllSnapshots (postsPattern cfg groupName) (postSnapshot groupName)
    return $ listField "posts" (postContext cfg <> globalContext cfg) (return posts) <> globalContext cfg
