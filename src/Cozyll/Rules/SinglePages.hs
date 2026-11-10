-- | Rules for standalone pages
module Cozyll.Rules.SinglePages (Page (..), page, processPage, pageCompiler) where

import Cozyll.CleanURL (pathRoute)
import Cozyll.Compile (applyTemplates, finish, runPandocWith)
import Cozyll.Config (SiteConfig, contentTemplate, pageTemplate, pagesPattern, siteEnv, siteRubyData)
import Cozyll.Content (isHidden, isIndex, isTemplated)
import Cozyll.Context (globalContext)
import Cozyll.Context.Aside (asideContext)
import Cozyll.Context.Nav (navContext)
import Cozyll.Context.SocialMeta (PageItem, PageKind (CollectionPage, WebSite), PageMeta (pageMetaLanguage), pageKindOf, pageMetaOf, socialMetaContext)
import Cozyll.Localization (ogLocaleFor)
import Cozyll.Metadata (Key (Home), lookupKey)
import Cozyll.Theme (applyContentAsTemplate)
import Hakyll (
    Compiler,
    Context,
    Identifier,
    Item,
    Metadata,
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
    , pageListItems :: Compiler [PageItem]
    -- ^ The items this page lists, for the ItemList / hasPart structured data
    }

-- | A page with the minimal context and no extra templates
page :: SiteConfig -> String -> Page
page cfg name = Page{pageName = name, pageContext = return (globalContext cfg), pageTemplates = [], pageListItems = return []}

-- | Compiles a standalone page's body (shared by 'processPage' and the dev example pages)
pageCompiler :: SiteConfig -> Page -> Compiler (Item String)
pageCompiler cfg Page{pageName, pageContext, pageTemplates, pageListItems} = do
    ctx <- pageContext
    templated <- isTemplated
    body <- getResourceString >>= (if templated then applyContentAsTemplate cfg ctx else return)
    (item', tocHtml, mainImg) <- runPandocWith (siteRubyData cfg) body
    underlying <- getUnderlying
    metadata <- getMetadata underlying
    kind <- pageKind metadata
    items <- pageListItems
    let ctx' = asideContext tocHtml <> ctx
        pageMeta = pageMetaOf cfg metadata
    ogLocale <- ogLocaleFor cfg (pageMetaLanguage pageMeta)
    applyTemplates ctx' ([contentTemplate cfg] <> pageTemplates <> [pageTemplate cfg]) item'
        >>= finish cfg (socialMetaContext cfg kind [] items pageMeta mainImg ogLocale <> navContext cfg pageName <> ctx')

-- | The page's structured-data kind: home is a @WebSite@, a group index a @CollectionPage@, anything else from @schemaType:@
pageKind :: Metadata -> Compiler PageKind
pageKind metadata
    | lookupKey Home metadata == Just "true" = pure WebSite
    | isIndex metadata = pure CollectionPage
    | otherwise = case pageKindOf metadata of
        Right kind -> pure kind
        Left unknown ->
            fail $
                "unknown schemaType \""
                    ++ unknown
                    ++ "\" (expected WebPage, AboutPage, ContactPage, CollectionPage, or ProfilePage)"

-- | Processes a standalone page, routed by its `path:` front matter
processPage :: SiteConfig -> Page -> Rules ()
processPage cfg page'@Page{pageName} = matchMetadata (pagesPattern cfg pageName) (not . isHidden (siteEnv cfg)) $ do
    route $ metadataRoute pathRoute
    compile $ pageCompiler cfg page'
