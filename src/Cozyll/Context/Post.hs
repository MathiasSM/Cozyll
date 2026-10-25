-- | Per-post fields (author) as template fields
module Cozyll.Context.Post (postContext) where

import Control.Applicative ((<|>))
import Cozyll.Config (SiteConfig, siteAuthor, siteAuthorUrl)
import Cozyll.Metadata qualified as K
import Data.Maybe (fromMaybe)
import Hakyll (Context, Item (itemIdentifier), field, getMetadata, noResult)

{- | A post's author: its front-matter @author@, else the site author.
@authorUrl@ is the post's @authorUrl@, else the site's, else absent (so
templates can render a plain name by default and a linked h-card only when a
URL is known).
-}
postContext :: SiteConfig -> Context a
postContext cfg =
    mconcat
        [ field "author" authorName
        , field "authorUrl" authorUrl
        ]
  where
    authorName item = do
        metadata <- getMetadata (itemIdentifier item)
        return $ fromMaybe (siteAuthor cfg) (K.lookupKey K.Author metadata)

    authorUrl item = do
        metadata <- getMetadata (itemIdentifier item)
        case K.lookupKey K.AuthorUrl metadata <|> siteAuthorUrl cfg of
            Just url -> return url
            Nothing -> noResult "no author url"
