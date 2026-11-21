-- | Build-time checks that content is consistent across files
module Cozyll.Rules.Validate (missingPaths, validateAuthorRefs, validateNavEntries, validatePaths) where

import Cozyll.Config (Env, SiteConfig, pagesPattern, postsPattern, projectsGroup, siteAuthors, siteEnv, siteLanguage, writingsPattern)
import Cozyll.Content (isHidden)
import Cozyll.Discover (discoverGroups)
import Cozyll.Domain.Author (authorId)
import Cozyll.Domain.Nav (parseNavEntry)
import Cozyll.Metadata (Key (Author, Path), lookupKey, lookupKeyList)
import Cozyll.Rules.Common (failIfAny)
import Hakyll (Metadata, Rules, getAllMetadata, toFilePath)
import System.FilePath.Posix (dropExtension, joinPath, splitDirectories, takeBaseName)

{- | Fails the build, once, listing every page whose menu entry (`nav:`) is invalid

Without this each page would report the same problem while rendering the menu.
-}
validateNavEntries :: SiteConfig -> Rules ()
validateNavEntries cfg = do
    pages <- getAllMetadata $ pagesPattern cfg "*"
    let problems = [toFilePath page ++ ": " ++ problem | (page, metadata) <- pages, Left found <- [parseNavEntry (siteLanguage cfg) metadata], problem <- found]
    failIfAny "Invalid menu entries" problems

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
    failIfAny "Unknown author ids" problems

{- | Fails the build, once, listing every built item whose front matter lacks @path:@

Hakyll would otherwise reach the route's @error@ one item at a time. Drafts that
this environment hides are skipped, exactly like the build skips them.
-}
validatePaths :: SiteConfig -> Rules ()
validatePaths cfg = do
    items <- getAllMetadata $ writingsPattern cfg
    let problems = missingPaths (siteEnv cfg) [(toFilePath ident, metadata) | (ident, metadata) <- items]
    failIfAny "Missing `path` front matter" problems

{- | The items that would be built but have no @path:@, each with the line to add

Takes the environment because drafts are only hidden outside @dev@.
-}
missingPaths :: Env -> [(FilePath, Metadata)] -> [String]
missingPaths env items =
    [ file ++ ": add `path: " ++ suggestedPath file ++ "` (the output URL)"
    | (file, metadata) <- items
    , not (isHidden env metadata)
    , Nothing <- [lookupKey Path metadata]
    ]

-- | A plausible output path for a file, used only to make the suggestion concrete
suggestedPath :: FilePath -> FilePath
suggestedPath file =
    case drop 1 (dropWhile (/= "writings") (splitDirectories file)) of
        [] -> '/' : takeBaseName file
        parts -> '/' : dropExtension (joinPath parts)
