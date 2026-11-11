-- | Site-wide information (name, description, author, URLs) as template fields
module Cozyll.Context.Site (siteContext) where

import Cozyll.Brand (SiteIcon (..), brandIcons, iconHref)
import Cozyll.Config (SiteConfig, baseUrl, mathjaxVersion, siteBrand, siteCopyrightYear, siteCurrentYear, siteDescription, siteDomain, siteTitle)
import Cozyll.Format (yearRange)
import Data.Maybe (fromMaybe, isJust)
import Hakyll (Context, Item (itemBody), constField, field, listField, makeItem, noResult)

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
        , constField "mathjax-version" (mathjaxVersion cfg)
        , constField "root" (baseUrl cfg) -- absolute origin used by the atom feeds
        , faviconsContext cfg
        ]

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
            [ field "href" (pure . iconHref . itemBody)
            , field "rel" (pure . fromMaybe "" . iconRel . itemBody)
            , optionalField "type" iconType
            , optionalField "sizes" iconSizes
            ]

-- | A field present only when the icon carries a value, so @$if()$ is false
optionalField :: String -> (a -> Maybe String) -> Context a
optionalField key value = field key $ \item ->
    maybe (noResult $ "no " ++ key) pure (value (itemBody item))
