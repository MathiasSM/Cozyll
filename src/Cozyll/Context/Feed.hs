-- | The site's Atom feeds as a context, for the page head
module Cozyll.Context.Feed (feedsContext) where

import Cozyll.Config (SiteConfig)
import Cozyll.Context.Common (itemField)
import Cozyll.Domain.Feed (Feed (..), feedHref, feeds, siteFeed)
import Hakyll (Context, Item (Item), fromFilePath, listField)

{- | The site's Atom feeds as a `feeds` list (@title@, @href@), for the page
head. The site-wide feed comes first, then one per post group.
-}
feedsContext :: SiteConfig -> Context a
feedsContext cfg = listField "feeds" feedContext $ do
    found <- feeds cfg
    either (fail . unlines) (pure . map toItem . (siteFeed cfg :)) found
  where
    toItem feed = Item (fromFilePath $ feedFile feed) feed
    feedContext =
        itemField "title" feedTitle
            <> itemField "href" feedHref
