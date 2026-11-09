{- | Author resolution and the author contexts.

== Resolution

A post's @author:@ is an id (or list of ids) from @authors.yaml@; without it the
post falls back to the site-default author. Unknown ids are dropped and
duplicates are de-duplicated.

== Template fields

@$for(author)$@ exposes each resolved author with:

  [@$id$@] the author id.
  [@$name$@] the full name.
  [@$displayName$@] the shorter display name (falls back to @$name$@).
  [@$path$@] @/authors/<id>@.
  [@$url$@] the absolute profile URL.
  [@$description$@] the bio (@""@ when absent).
  [@$profileImage$@] the absolute image URL (@""@ when absent).
  [@$type$@] @person@ or @organization@.
  [@$for(links)$@] the profile links, with @$url$@ per link.

Posts also get @$postCopyright$@ (whether any author opted in),
@$postCopyrightYears$@, and @$postCopyrightHolders$@ (each with @$name$@),
driven by @addCopyrightNotice@ (a @© <authors> <years>@ line at the end of the
post, years from @date@ to @lastModifiedAt@, not shown in lists or feeds).

An author's page ('authorPageContext') exposes @$title$@, @$path$@, @$name$@,
@$displayName$@, @$url$@, @$type$@, @$links$@, and @$profileImage$@ and
@$description$@ (each only when set).

== Author pages

Every author gets a profile page at @/authors/<id>@ (included in
@sitemap.xml@) showing their display name (or name), description, profile
image, links, and every post they authored; a post without @author:@ counts for
the site-default author. The canonical URL and @og:url@ are
@https://<domain>/authors/<id>@, and @og:image@ is the profile image when one is
set.
-}
module Cozyll.Context.Author (
    resolveAuthors,
    authorItemContext,
    authorContext,
    authorPageContext,
    authorPages,
    authorPosts,
    authoredBy,
    displayNameOf,
    copyrightYears,
) where

import Control.Monad (filterM)
import Cozyll.Config (SiteConfig, baseUrl, postSnapshot, postsPattern, projectsGroup, siteAuthors, siteDefaultAuthor)
import Cozyll.Context.SocialMeta (absoluteImageUrl)
import Cozyll.Discover (discoverGroups)
import Cozyll.Domain.Author (Author (..), authorTypeName, authorUrlPath)
import Cozyll.Format (yearRange)
import Cozyll.Metadata qualified as Meta
import Data.List (find, nubBy)
import Data.Maybe (fromMaybe, mapMaybe)
import Hakyll (
    Compiler,
    Context,
    Item (..),
    Metadata,
    boolFieldM,
    constField,
    field,
    fromFilePath,
    getMetadata,
    listField,
    listFieldWith,
    loadAllSnapshots,
    recentFirst,
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

{- | Every post authored by this author (a post without @author:@ belongs to the
site-default author), newest first within each group
-}
authorPosts :: SiteConfig -> Author -> Compiler [Item String]
authorPosts cfg author = do
    groups <- filter (/= projectsGroup) <$> discoverGroups cfg
    posts <- mapM (\group -> recentFirst =<< loadAllSnapshots (postsPattern cfg group) (postSnapshot group)) groups
    filterM (fmap (authoredBy cfg author) . getMetadata . itemIdentifier) (concat posts)

-- | Whether a post's metadata lists this author
authoredBy :: SiteConfig -> Author -> Metadata -> Bool
authoredBy cfg author metadata = any ((== authorId author) . authorId) (resolveAuthors cfg metadata)

-- | An author's own fields, for their profile page
authorPageContext :: SiteConfig -> Author -> Context String
authorPageContext cfg author =
    constField "title" displayName
        <> constField "path" (authorUrlPath author)
        <> constField "name" (authorName author)
        <> constField "displayName" displayName
        <> constField "url" (authorUrl cfg author)
        <> constField "type" (authorTypeName (authorType author))
        <> maybe
            mempty
            (constField "profileImage" . absoluteImageUrl cfg)
            (authorProfileImage author)
        <> maybe mempty (constField "description") (authorDescription author)
        <> listField "links" linkItemContext (return (map linkItem (authorLinks author)))
  where
    displayName = displayNameOf author

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
