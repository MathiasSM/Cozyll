-- | The context every page is rendered with
module Cozyll.Context (globalContext) where

import Cozyll.Config (SiteConfig)
import Cozyll.Context.Author (authorContext)
import Cozyll.Context.Data (dataContext)
import Cozyll.Context.Feed (feedsContext)
import Cozyll.Context.Language (languageContext)
import Cozyll.Context.Site (siteContext)
import Cozyll.Context.Social (socialMediaContext)
import Cozyll.Format (postSlug)
import Cozyll.Localization (translationsContext)
import Cozyll.Metadata qualified as K
import Data.List (isInfixOf)
import Hakyll (
    Context,
    Item (itemBody),
    boolField,
    defaultContext,
    field,
    getMetadata,
    itemIdentifier,
 )

-- | Every field available to all pages and list items
globalContext :: SiteConfig -> Context String
globalContext cfg =
    siteContext cfg
        <> socialMediaContext cfg
        <> dataContext cfg
        <> languageContext
        <> translationsContext cfg
        <> feedsContext cfg
        <> authorContext cfg
        <> mathContext
        <> slugContext
        <> defaultContext

-- | The item's URL slug: its `path:` front matter with slashes turned to hyphens
slugContext :: Context a
slugContext = field "slug" $ \item -> do
    metadata <- getMetadata (itemIdentifier item)
    case K.lookupKey K.Path metadata of
        Just path -> return (postSlug path)
        Nothing -> fail "Missing `path` front matter for slug"

-- | True when the page's rendered body contains math, so templates can load MathJax
mathContext :: Context String
mathContext =
    boolField "math" $ \item ->
        "class=\"math " `isInfixOf` itemBody item
