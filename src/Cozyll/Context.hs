-- | The context every page is rendered with
module Cozyll.Context (globalContext) where

import Cozyll.Config (SiteConfig)
import Cozyll.Context.Author (authorContext)
import Cozyll.Context.Data (dataContext)
import Cozyll.Context.Feed (feedsContext)
import Cozyll.Context.Language (languageContext)
import Cozyll.Context.Site (siteContext)
import Cozyll.Context.Social (socialMediaContext)
import Cozyll.Localization (translationsContext)
import Data.List (isInfixOf)
import Hakyll (
    Context,
    Item (itemBody),
    boolField,
    defaultContext,
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
        <> defaultContext

-- | True when the page's rendered body contains math, so templates can load MathJax
mathContext :: Context String
mathContext =
    boolField "math" $ \item ->
        "class=\"math " `isInfixOf` itemBody item
