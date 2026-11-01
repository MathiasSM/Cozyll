-- | Rules for the projects group: its index page and the projects
module Cozyll.Rules.Showcase (processShowcaseGroup) where

import Cozyll.Config (SiteConfig, projectsGroup, projectsPattern, resolveTemplate)
import Cozyll.Content (requireProject, showcaseKey)
import Cozyll.Context (globalContext)
import Cozyll.Context.Project (projectContext)
import Cozyll.Rules.SinglePages (Page (..), page, processPage)
import Data.List (sortOn)
import Hakyll (
    Compiler,
    Context,
    Item (Item, itemBody, itemIdentifier),
    Rules,
    compile,
    getResourceString,
    listField,
    loadAll,
    match,
 )

-- | Processes the projects group: its index page and the projects it lists
processShowcaseGroup :: SiteConfig -> Rules ()
processShowcaseGroup cfg = do
    processShowcaseItems cfg
    processShowcaseIndex cfg

-- | Builds the index page, listing all projects
processShowcaseIndex :: SiteConfig -> Rules ()
processShowcaseIndex cfg =
    processPage cfg (page cfg projectsGroup){pageContext = getProjectsCtx cfg, pageTemplates = [resolveTemplate cfg "with-projects.html"]}

{- | Compiles each project (not routed), so the index can list it

The raw YAML is kept as the item; parsing here makes an invalid project fail the build.
-}
processShowcaseItems :: SiteConfig -> Rules ()
processShowcaseItems cfg =
    match (projectsPattern cfg) $
        compile $ do
            item <- getResourceString
            _ <- requireProject item
            return item

-- | Build context for the index page
getProjectsCtx :: SiteConfig -> Compiler (Context String)
getProjectsCtx cfg = do
    items <- loadAll (projectsPattern cfg)
    projects <- mapM (\item -> Item (itemIdentifier item) <$> requireProject item) items
    let ordered = sortOn (showcaseKey . itemBody) projects
    return $ listField "projects" (projectContext cfg) (return ordered) <> globalContext cfg
