-- | Rules that build redirect pages from aliases
module Cozyll.Rules.Redirects (processRedirects, Entry (..), planRedirects) where

import Cozyll.CleanURL (outputPath)
import Cozyll.Config (SiteConfig, pagesPattern, postsPattern)
import Cozyll.Content (aliasesOf, isDraft)
import Cozyll.Discover (discoverGroups)
import Cozyll.Metadata (Key (Path), lookupKey)
import Cozyll.Theme (themeFingerprint)
import Data.Either (fromLeft)
import Data.List (tails)
import Hakyll (
    Redirect (..),
    Rules,
    compile,
    create,
    fromFilePath,
    getAllMetadata,
    idRoute,
    makeItem,
    preprocess,
    route,
    toFilePath,
    version,
 )

-- | A published page or post, with the old paths that should lead to it
data Entry = Entry
    { entryFile :: FilePath
    , entryPath :: Maybe FilePath
    , entryAliases :: [FilePath]
    }
    deriving (Eq, Show)

{- | Builds a redirect page for every `aliases:` of every published page and post

Invalid aliases fail the build.
-}
processRedirects :: SiteConfig -> Rules ()
processRedirects cfg = do
    groups <- discoverGroups cfg
    items <- concat <$> mapM getAllMetadata (pagesPattern cfg "*" : map (postsPattern cfg) groups)
    let parsed = [(toFilePath ident, metadata, aliasesOf metadata) | (ident, metadata) <- items, not (isDraft metadata)]
        entries = [Entry file (lookupKey Path metadata) aliases | (file, metadata, Right aliases) <- parsed]
        planned = planRedirects entries
        problems =
            [file ++ ": " ++ problem | (file, _, Left found) <- parsed, problem <- found]
                ++ fromLeft [] planned
    case planned of
        Right redirects
            | null problems ->
                version "redirects" $
                    mapM_ redirectRule redirects
        _ -> preprocess $ ioError $ userError $ "Invalid aliases:\n" ++ unlines (map ("  " ++) problems)
  where
    -- Same rule as Hakyll's `createRedirects`, with the theme fingerprint so
    -- the page participates in theme invalidation like every other render path.
    redirectRule (out, target) = create [fromFilePath out] $ do
        route idRoute
        compile $ themeFingerprint cfg >> makeItem (Redirect target)

{- | The redirects to build, as (output file, target path), or every problem found:
an alias that is its own path, the path of another page, or claimed twice
-}
planRedirects :: [Entry] -> Either [String] [(FilePath, FilePath)]
planRedirects entries
    | null problems = Right [(outputPath alias, target) | (_, alias, Just target) <- claims]
    | otherwise = Left problems
  where
    claims = [(file, alias, path) | Entry file path aliases <- entries, alias <- aliases]
    published = [(file, path) | Entry file (Just path) _ <- entries]
    same a b = outputPath a == outputPath b
    problems =
        [file ++ ": aliases need a `path:` to point to" | (file, _, Nothing) <- claims]
            ++ [file ++ ": alias " ++ alias ++ " is its own path" | (file, alias, Just path) <- claims, same alias path]
            ++ [file ++ ": alias " ++ alias ++ " is the path of " ++ other | (file, alias, _) <- claims, (other, path) <- published, other /= file, same alias path]
            ++ [ file ++ ": alias " ++ alias ++ " is also claimed by " ++ other
               | (file, alias, _) : later <- tails claims
               , (other, alias', _) <- later
               , same alias alias'
               ]
