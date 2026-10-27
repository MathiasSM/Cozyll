-- | Rules for standalone pages
module Cozyll.Rules.SinglePages (Page (..), page, processPage, pageCompiler) where

import Cozyll.CleanURL (pathRoute)
import Cozyll.Compile (applyTemplates, finish, runPandoc)
import Cozyll.Config (SiteConfig, minimalTemplate, pageTemplate, pagesPattern, siteEnv)
import Cozyll.Content (isHidden, isTemplated)
import Cozyll.Context (globalContext)
import Cozyll.Context.Aside (asideContext)
import Cozyll.Context.Nav (navContext)
import Cozyll.Context.SocialMeta (SocialKind (WebPage, WebSite), pageMetaOf, socialMetaContext)
import Cozyll.Metadata (Key (Home), lookupKey)
import Cozyll.Theme (applyContentAsTemplate)
import Hakyll (
    Compiler,
    Context,
    Identifier,
    Item,
    Rules,
    compile,
    getMetadata,
    getResourceString,
    getUnderlying,
    matchMetadata,
    metadataRoute,
    route,
 )

-- | A standalone page, backed by content/writings/<pageName>.* and routed by its `path:`
data Page = Page
    { pageName :: String
    , pageContext :: Compiler (Context String)
    -- ^ Context for the page body and its templates
    , pageTemplates :: [Identifier]
    -- ^ Extra templates, applied between the minimal and page templates
    }

-- | A page with the minimal context and no extra templates
page :: SiteConfig -> String -> Page
page cfg name = Page{pageName = name, pageContext = return (globalContext cfg), pageTemplates = []}

-- | Compiles a standalone page's body (shared by 'processPage' and the dev example pages)
pageCompiler :: SiteConfig -> Page -> Compiler (Item String)
pageCompiler cfg Page{pageName, pageContext, pageTemplates} = do
    ctx <- pageContext
    templated <- isTemplated
    body <- getResourceString >>= (if templated then applyContentAsTemplate cfg ctx else return)
    (item', tocHtml, mainImg) <- runPandoc body
    metadata <- getUnderlying >>= getMetadata
    let ctx' = asideContext tocHtml <> ctx
        pageMeta = pageMetaOf cfg metadata
        kind = if lookupKey Home metadata == Just "true" then WebSite else WebPage
    applyTemplates ctx' ([minimalTemplate cfg] <> pageTemplates <> [pageTemplate cfg]) item'
        >>= finish cfg (socialMetaContext cfg kind pageMeta mainImg <> navContext cfg pageName <> ctx')

-- | Processes a standalone page, routed by its `path:` front matter
processPage :: SiteConfig -> Page -> Rules ()
processPage cfg page'@Page{pageName} = matchMetadata (pagesPattern cfg pageName) (not . isHidden (siteEnv cfg)) $ do
    route $ metadataRoute pathRoute
    compile $ pageCompiler cfg page'
