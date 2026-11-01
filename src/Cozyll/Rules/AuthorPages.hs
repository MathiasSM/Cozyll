-- | Rules that build one profile page per author
module Cozyll.Rules.AuthorPages (
    processAuthorPages,
    authorPageIdentifier,
) where

import Cozyll.Compile (applyTemplates, finish)
import Cozyll.Config (SiteConfig, baseUrl, minimalTemplate, resolveTemplate)
import Cozyll.Context (globalContext)
import Cozyll.Context.Author (authorPageContext, authorPages, authorPosts, displayNameOf)
import Cozyll.Context.Nav (navContext)
import Cozyll.Context.SocialMeta (MainImage (..), PageKind (ProfilePage), PageMeta (..), pageItemOf, socialMetaContext)
import Cozyll.Domain.Author (Author (..), authorUrlPath)
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
            pageMeta =
                PageMeta
                    { pageMetaTitle = displayName
                    , pageMetaDescription = authorDescription author
                    , pageMetaUrl = baseUrl cfg ++ authorUrlPath author
                    , pageMetaLanguage = "en"
                    , pageMetaPublished = Nothing
                    , pageMetaModified = Nothing
                    }
            mainImage = MainImage <$> authorProfileImage author <*> pure displayName
            ctx = authorPageContext cfg author <> listField "posts" (globalContext cfg) (return posts) <> globalContext cfg
        makeItem ""
            >>= applyTemplates ctx [minimalTemplate cfg, resolveTemplate cfg "author.html"]
            >>= finish cfg (socialMetaContext cfg ProfilePage [author] items pageMeta mainImage <> navContext cfg "authors" <> ctx)
