-- | Site-wide information (name, description, author, URLs) as template fields
module Cozyll.Context.Site (siteContext) where

import Cozyll.Config (SiteConfig, baseUrl, mathjaxVersion, siteCopyrightYear, siteDescription, siteDomain, siteTitle)
import Hakyll (Context, constField)

-- | Sets site-wide information (site-<info>)
siteContext :: SiteConfig -> Context a
siteContext cfg =
    mconcat
        [ constField "site-title" (siteTitle cfg)
        , constField "site-description" (siteDescription cfg)
        , constField "site-copyrightYear" (show $ siteCopyrightYear cfg)
        , constField "site-baseUrl" (baseUrl cfg)
        , constField "site-domain" (siteDomain cfg)
        , constField "mathjax-version" (mathjaxVersion cfg)
        , constField "root" (baseUrl cfg) -- absolute origin used by the atom feeds
        ]
