-- | Site-wide information (name, description, author, URLs) as template fields
module Cozyll.Context.Site (siteContext) where

import Cozyll.Config (SiteConfig, baseUrl, mathjaxVersion, siteAuthor, siteCopyrightYear, siteDescription, siteDomain, siteName)
import Hakyll (Context, constField)

-- | Sets site-wide information (site-<info>)
siteContext :: SiteConfig -> Context a
siteContext cfg =
    mconcat
        [ constField "site-name" (siteName cfg)
        , constField "site-description" (siteDescription cfg)
        , constField "site-author" (siteAuthor cfg)
        , constField "site-copyrightYear" (show $ siteCopyrightYear cfg)
        , constField "site-baseUrl" (baseUrl cfg)
        , constField "site-domain" (siteDomain cfg)
        , constField "mathjax-version" (mathjaxVersion cfg)
        , constField "root" (baseUrl cfg) -- absolute origin used by the atom feeds
        ]
