-- | Site-wide information (name, description, author, URLs) as template fields
module Cozyll.Context.Site (siteContext) where

import Cozyll.Config (SiteConfig, baseUrl, contactEmail, contactPage, mathjaxVersion, siteAuthor, siteAuthorUrl, siteCopyrightYear, siteDescription, siteDomain, siteName)
import Hakyll (Context, constField, field, noResult)

-- | Sets site-wide information (site-<info>)
siteContext :: SiteConfig -> Context a
siteContext cfg =
    mconcat
        [ constField "site-name" (siteName cfg)
        , constField "site-description" (siteDescription cfg)
        , constField "site-author" (siteAuthor cfg)
        , field "site-author-url" $ \_ ->
            case siteAuthorUrl cfg of
                Just url -> return url
                Nothing -> noResult "no site author url"
        , constField "site-copyrightYear" (show $ siteCopyrightYear cfg)
        , constField "site-baseUrl" (baseUrl cfg)
        , constField "site-domain" (siteDomain cfg)
        , constField "contact-email" (contactEmail cfg)
        , constField "contact-page" (contactPage cfg)
        , constField "mathjax-version" (mathjaxVersion cfg)
        , constField "root" (baseUrl cfg) -- read by Hakyll's own social cards
        ]
