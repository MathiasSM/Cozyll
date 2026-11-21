-- | Site-wide information (name, description, author, URLs) as template fields
module Cozyll.Context.Site (siteContext) where

import Cozyll.Brand (SiteIcon (..), brandIcons, iconHref)
import Cozyll.Config (SiteConfig, baseUrl, mathjaxVersion, siteBrand, siteCopyrightYear, siteCurrentYear, siteDescription, siteDomain, siteLogo, siteTitle)
import Cozyll.Context.Common (itemField, maybeField)
import Cozyll.Format (yearRange)
import Cozyll.Paths (stripLeadingSlashes)
import Data.Char (toLower)
import Data.List (isPrefixOf)
import Data.Maybe (fromMaybe, isJust)
import Hakyll (Context, Item (itemBody), constField, field, listField, makeItem)

-- | Sets site-wide information (site-<info>)
siteContext :: SiteConfig -> Context a
siteContext cfg =
    mconcat
        [ constField "site-title" (siteTitle cfg)
        , constField "site-description" (siteDescription cfg)
        , constField "site-copyrightYear" (show $ siteCopyrightYear cfg)
        , constField "site-copyrightRange" (yearRange (siteCopyrightYear cfg) (siteCurrentYear cfg))
        , constField "site-baseUrl" (baseUrl cfg)
        , constField "site-domain" (siteDomain cfg)
        , maybe mempty (constField "site-logo" . siteLogoSrc) (siteLogo cfg)
        , constField "mathjax-version" (mathjaxVersion cfg)
        , constField "root" (baseUrl cfg) -- absolute origin used by the atom feeds
        , faviconsContext cfg
        ]

-- | The @site-logo@ value: a site-root path or an absolute URL
siteLogoSrc :: String -> String
siteLogoSrc logo
    | "//" `isPrefixOf` lowered = logo
    | "http://" `isPrefixOf` lowered = logo
    | "https://" `isPrefixOf` lowered = logo
    | otherwise = '/' : stripLeadingSlashes logo
  where
    lowered = map toLower logo

{- | The icon @<link>@s of the page head: the brand icons that carry a @rel@,
in generation order. Empty when the site has no logo.
-}
faviconsContext :: SiteConfig -> Context a
faviconsContext cfg = listField "favicons" iconContext (mapM makeItem headIcons)
  where
    icons = maybe [] brandIcons (siteBrand cfg)
    headIcons = [icon | icon <- icons, isJust (iconRel icon)]

    iconContext :: Context SiteIcon
    iconContext =
        mconcat
            [ itemField "href" iconHref
            , field "rel" (pure . fromMaybe "" . iconRel . itemBody)
            , maybeField "type" iconType
            , maybeField "sizes" iconSizes
            ]
