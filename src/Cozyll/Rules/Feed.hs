-- | Rules that build the Atom feeds
module Cozyll.Rules.Feed (processFeeds) where

import Control.Monad (forM_)
import Cozyll.CleanURL (cleanIndex)
import Cozyll.Config (SiteConfig, baseUrl, postSnapshot, postsPattern, resolveTemplate, siteDefaultAuthor)
import Cozyll.Content (requirePostOf)
import Cozyll.Domain.Author (authorName)
import Cozyll.Domain.Feed (Feed (..), absoluteUrl, feeds)
import Cozyll.Domain.Post (Post (..))
import Cozyll.Domain.Website (Website (websiteFeed), feedSize)
import Data.Maybe (fromMaybe)
import Data.Time (Day, defaultTimeLocale, formatTime)
import Hakyll (
    Context,
    FeedConfiguration (..),
    Item (itemBody, itemIdentifier),
    Rules,
    compile,
    create,
    defaultContext,
    field,
    fromFilePath,
    idRoute,
    loadAllSnapshots,
    loadBody,
    mapContext,
    preprocess,
    recentFirst,
    renderAtomWithTemplates,
    route,
    urlField,
    withUrls,
 )

-- | Builds the Atom feed of every post group: its newest posts, in full
processFeeds :: SiteConfig -> Website -> Rules ()
processFeeds cfg website = do
    found <- feeds cfg
    let feedSize' = feedSize $ websiteFeed website
    case found of
        Left problems -> preprocess $ ioError $ userError $ "Invalid feeds:\n" ++ unlines (map ("  " ++) problems)
        Right all' -> forM_ all' $ \feed ->
            create [fromFilePath $ feedFile feed] $ do
                route idRoute
                compile $ do
                    posts <- recentFirst =<< loadAllSnapshots (postsPattern cfg $ feedGroup feed) (postSnapshot $ feedGroup feed)
                    feedTemplate <- loadBody (resolveTemplate cfg "atom-feed.xml")
                    itemTemplate <- loadBody (resolveTemplate cfg "atom-item.xml")
                    renderAtomWithTemplates feedTemplate itemTemplate (configuration cfg feed) (itemContext cfg) (take feedSize' posts)

configuration :: SiteConfig -> Feed -> FeedConfiguration
configuration cfg feed =
    FeedConfiguration
        { feedTitle = Cozyll.Domain.Feed.feedTitle feed
        , feedDescription = Cozyll.Domain.Feed.feedDescription feed
        , feedAuthorName = authorName (siteDefaultAuthor cfg)
        , feedAuthorEmail = ""
        , feedRoot = baseUrl cfg
        }

{- | What each entry reads: its clean URL, its full text with absolute links
(@description@, the feed templates' name for the content), and its dates
-}
itemContext :: SiteConfig -> Context String
itemContext cfg =
    mapContext cleanIndex (urlField "url")
        <> field "description" (return . withUrls (absoluteUrl (baseUrl cfg)) . itemBody)
        <> timestampField "published" postDate
        <> timestampField "updated" (\post -> fromMaybe (postDate post) (postLastModified post))
        <> defaultContext

-- | An RFC 3339 timestamp (midnight UTC) of one of the post's dates
timestampField :: String -> (Post -> Day) -> Context String
timestampField name pick = field name $ \item ->
    formatTime defaultTimeLocale "%Y-%m-%dT00:00:00Z" . pick <$> requirePostOf (itemIdentifier item)
