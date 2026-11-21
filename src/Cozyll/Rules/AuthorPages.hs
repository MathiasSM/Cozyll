-- | Rules that build one profile page per author
module Cozyll.Rules.AuthorPages (
    processAuthorPages,
    authorPageIdentifier,
) where

import Cozyll.Compile (applyTemplates, finishPage)
import Cozyll.Config (SiteConfig, baseUrl, resolveTemplate, siteLanguage)
import Cozyll.Context (globalContext)
import Cozyll.Context.Author (authorPageContext, authorPages, authorPosts, displayNameOf)
import Cozyll.Context.SocialMeta (MainImage (..), PageKind (ProfilePage), PageMeta (PageMeta), pageItemOf)
import Cozyll.Domain.Author (Author (..), authorUrlPath)
import Cozyll.Domain.Language (languageCode)
import Hakyll (
    Identifier,
    Rules,
    compile,
    create,
    fromFilePath,
    idRoute,
    listField,
    makeItem,
    route,
 )
import System.FilePath.Posix ((</>))

-- | One page per author, at @authors/<id>/index.html@
processAuthorPages :: SiteConfig -> Rules ()
processAuthorPages cfg = mapM_ (processAuthorPage cfg) (authorPages cfg)

-- | The identifier of an author's page
authorPageIdentifier :: SiteConfig -> Author -> Identifier
authorPageIdentifier _ author = fromFilePath $ "authors" </> authorId author </> "index.html"

-- | Builds an author's page: their details and every post they authored
processAuthorPage :: SiteConfig -> Author -> Rules ()
processAuthorPage cfg author = create [authorPageIdentifier cfg author] $ do
    route idRoute
    compile $ do
        posts <- authorPosts cfg author
        items <- mapM (pageItemOf cfg) posts
        let displayName = displayNameOf author
            pageMeta = authorPageMeta cfg author
            mainImage = MainImage <$> authorProfileImage author <*> pure displayName
            ctx = authorPageContext cfg author <> listField "posts" (globalContext cfg) (return posts) <> globalContext cfg
        makeItem ""
            >>= applyTemplates ctx [resolveTemplate cfg "author.html"]
            >>= finishPage cfg ProfilePage [author] items pageMeta mainImage ctx "authors"

-- | The page metadata of an author's profile page
authorPageMeta :: SiteConfig -> Author -> PageMeta
authorPageMeta cfg author =
    PageMeta
        (displayNameOf author)
        (authorDescription author)
        (baseUrl cfg ++ authorUrlPath author)
        (languageCode $ siteLanguage cfg)
        Nothing
        Nothing
