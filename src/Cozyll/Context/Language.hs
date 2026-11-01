-- | Language variables exposed to templates
module Cozyll.Context.Language (languageContext) where

import Cozyll.Content (requireLanguage)
import Cozyll.Domain.Language (languageCode)
import Hakyll (Context, Item (itemIdentifier), field)

-- | Exposes the page's language code (for @lang=@ attributes and lookups)
languageContext :: Context a
languageContext = field "language" (fmap languageCode . requireLanguage . itemIdentifier)
