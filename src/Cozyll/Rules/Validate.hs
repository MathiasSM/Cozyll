-- | Build-time checks that content is consistent across files
module Cozyll.Rules.Validate (validateNavEntries, validateAuthorRefs) where

import Control.Monad (unless)
import Cozyll.Config (SiteConfig, pagesPattern, postsPattern, projectsGroup, siteAuthors)
import Cozyll.Discover (discoverGroups)
import Cozyll.Domain.Author (authorId)
import Cozyll.Domain.Nav (parseNavEntry)
import Cozyll.Metadata (Key (Author), lookupKeyList)
import Hakyll (Rules, getAllMetadata, preprocess, toFilePath)

{- | Fails the build, once, listing every page whose menu entry (`nav:`) is invalid

Without this each page would report the same problem while rendering the menu.
-}
validateNavEntries :: SiteConfig -> Rules ()
validateNavEntries cfg = do
    pages <- getAllMetadata $ pagesPattern cfg "*"
    let problems = [toFilePath page ++ ": " ++ problem | (page, metadata) <- pages, Left found <- [parseNavEntry metadata], problem <- found]
    unless (null problems)
        $ preprocess
        $ ioError
        $ userError
        $ "Invalid menu entries:\n" ++ unlines (map ("  " ++) problems)

{- | Fails the build, once, listing every post whose @author:@ id is unknown

Without this each post would silently drop the unknown author while rendering.
-}
validateAuthorRefs :: SiteConfig -> Rules ()
validateAuthorRefs cfg = do
    groups <- discoverGroups cfg
    let postGroups = filter (/= projectsGroup) groups
        knownIds = map authorId (siteAuthors cfg)
    posts <- concat <$> mapM (getAllMetadata . postsPattern cfg) postGroups
    let problems =
            [ toFilePath page ++ ": " ++ theId
            | (page, metadata) <- posts
            , Just ids <- [lookupKeyList Author metadata]
            , theId <- ids
            , theId `notElem` knownIds
            ]
    unless (null problems)
        $ preprocess
        $ ioError
        $ userError
        $ "Unknown author ids:\n" ++ unlines (map ("  " ++) problems)
