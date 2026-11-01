-- | Author resolution and the per-post author context
module Cozyll.Context.Author (
    resolveAuthors,
    authorItemContext,
    authorContext,
    authorPages,
    copyrightYears,
) where

import Cozyll.Config (SiteConfig, baseUrl, siteAuthors, siteDefaultAuthor)
import Cozyll.Context.SocialMeta (absoluteImageUrl)
import Cozyll.Domain.Author (Author (..), authorTypeName, authorUrlPath)
import Cozyll.Format (yearRange)
import Cozyll.Metadata qualified as Meta
import Data.List (find, nubBy)
import Data.Maybe (fromMaybe, mapMaybe)
import Hakyll (
    Context,
    Item (..),
    Metadata,
    boolFieldM,
    field,
    fromFilePath,
    getMetadata,
    listFieldWith,
 )
import Text.Read (readMaybe)

-- | The authors of a post: its @author:@ ids, or the site-default author
resolveAuthors :: SiteConfig -> Metadata -> [Author]
resolveAuthors cfg metadata =
    case Meta.lookupKeyList Meta.Author metadata of
        Nothing -> [siteDefaultAuthor cfg]
        Just ids -> dedupe (mapMaybe (lookupAuthor cfg) ids)
  where
    dedupe = nubBy (\a b -> authorId a == authorId b)

-- | The author with the given id, if any
lookupAuthor :: SiteConfig -> String -> Maybe Author
lookupAuthor cfg slug = find ((== slug) . authorId) (siteAuthors cfg)

-- | The fields of one author, for the byline and the author page
authorItemContext :: SiteConfig -> Context Author
authorItemContext cfg =
    field "id" (return . authorId . itemBody)
        <> field "name" (return . authorName . itemBody)
        <> field "displayName" (return . displayNameOf . itemBody)
        <> field "path" (return . authorUrlPath . itemBody)
        <> field "url" (return . authorUrl cfg . itemBody)
        <> field "description" (return . fromMaybe "" . authorDescription . itemBody)
        <> field "profileImage" (return . maybe "" (absoluteImageUrl cfg) . authorProfileImage . itemBody)
        <> field "type" (return . authorTypeName . authorType . itemBody)
        <> listFieldWith "links" linkItemContext (return . map linkItem . authorLinks . itemBody)

-- | The per-post author list, resolved from the page's own metadata
authorContext :: SiteConfig -> Context String
authorContext cfg =
    listFieldWith "author" (authorItemContext cfg) resolveFor
        <> boolFieldM "postCopyright" isPostCopyright
        <> field "postCopyrightYears" postCopyrightYears
        <> listFieldWith "postCopyrightHolders" holderContext postCopyrightHolders
  where
    resolveFor item = do
        metadata <- getMetadata (itemIdentifier item)
        pure (map authorItem (resolveAuthors cfg metadata))
    authorItem author = Item (fromFilePath (authorId author)) author

    isPostCopyright item = do
        metadata <- getMetadata (itemIdentifier item)
        pure (any authorAddCopyrightNotice (resolveAuthors cfg metadata))

    postCopyrightYears item = do
        metadata <- getMetadata (itemIdentifier item)
        pure (copyrightYears metadata)

    postCopyrightHolders item = do
        metadata <- getMetadata (itemIdentifier item)
        pure (map authorItem (filter authorAddCopyrightNotice (resolveAuthors cfg metadata)))

-- | The fields of one copyright holder (a bare name)
holderContext :: Context Author
holderContext = field "name" (return . authorName . itemBody)

-- | The copyright years of a post: @date@ to @lastModifiedAt@, as a range
copyrightYears :: Metadata -> String
copyrightYears metadata = case Meta.lookupKey Meta.Date metadata of
    Nothing -> ""
    Just date -> case readMaybe (take 4 date) of
        Nothing -> ""
        Just firstYear ->
            let lastYear = case Meta.lookupKey Meta.LastModifiedAt metadata of
                    Nothing -> firstYear
                    Just modified -> fromMaybe firstYear (readMaybe (take 4 modified))
             in yearRange firstYear lastYear

-- | Every author, in @authors.yaml@ file order
authorPages :: SiteConfig -> [Author]
authorPages = siteAuthors

-- | The display name, falling back to the full name
displayNameOf :: Author -> String
displayNameOf author = fromMaybe (authorName author) (authorDisplayName author)

-- | The absolute URL of an author's page
authorUrl :: SiteConfig -> Author -> String
authorUrl cfg author = baseUrl cfg ++ authorUrlPath author

-- | The fields of one link (a bare URL)
linkItemContext :: Context String
linkItemContext = field "url" (return . itemBody)

-- | A link as an item
linkItem :: String -> Item String
linkItem url = Item (fromFilePath url) url
