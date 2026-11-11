-- | Language variables exposed to templates
module Cozyll.Context.Language (languageContext) where

import Cozyll.Config (SiteConfig, siteLanguage)
import Cozyll.Content (requireLanguage)
import Cozyll.Domain.Language (languageCode)
import Hakyll (Context, Item (itemIdentifier), field, noResult)

{- | Exposes the page's language code (for @lang=@ attributes and lookups), and
@siteChromeLang@: the site's language code when the page is written in a
different language, absent otherwise (so the site chrome only claims a language
when it differs from the page).
-}
languageContext :: SiteConfig -> Context a
languageContext cfg =
    field "language" (fmap languageCode . requireLanguage cfg . itemIdentifier)
        <> field "siteChromeLang" chromeLanguage
  where
    chromeLanguage item = do
        pageLanguage <- requireLanguage cfg (itemIdentifier item)
        let site = siteLanguage cfg
        if languageCode pageLanguage == languageCode site
            then noResult "the page is written in the site's language"
            else pure $ languageCode site
