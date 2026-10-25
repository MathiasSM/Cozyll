-- | Front-matter queries and content-loading helpers (the Hakyll-facing side of the domain)
module Cozyll.Content (
    isDraft,
    isHidden,
    isIndex,
    isSitemapExcluded,
    isTemplated,
    tocLabelOf,
    groupOf,
    aliasesOf,
    parseAliasesYaml,
    showcaseKey,
    requirePost,
    requirePostOf,
    requireLanguage,
    requireNav,
    requireProject,
    requireSocials,
) where

import Control.Monad ((>=>))
import Cozyll.Config (Env (..))
import Cozyll.Domain.Language (Language, languageOf)
import Cozyll.Domain.Nav (NavEntry, parseNavEntry)
import Cozyll.Domain.Post (Post, parsePost)
import Cozyll.Domain.Project (Project (..), parseProjectYaml)
import Cozyll.Domain.Social (Social, parseSocialsYaml)
import Cozyll.Metadata qualified as K
import Cozyll.Yaml (Check (runCheck), decodeYaml, optional)
import Data.Aeson (FromJSON (parseJSON), Value (String))
import Data.List (intercalate, stripPrefix)
import Data.Maybe (fromMaybe)
import Data.Ord (Down (Down))
import Data.Time (Day)
import Hakyll (
    Compiler,
    Identifier,
    Item (itemBody),
    Metadata,
    getMetadata,
    getUnderlying,
    toFilePath,
 )
import System.FilePath.Posix (addTrailingPathSeparator, (</>))

-- | Whether an item is marked `draft: true`, and so left out of the site
isDraft :: Metadata -> Bool
isDraft o = runCheck (optional o K.Draft) == Right (Just True)

-- | Whether a draft item is hidden from this build (dev shows drafts, prod and example hide them)
isHidden :: Env -> Metadata -> Bool
isHidden Dev = const False
isHidden _ = isDraft

-- | Whether an item is a group index page (`index: true` in its front matter)
isIndex :: Metadata -> Bool
isIndex o = runCheck (optional o K.Index) == Right (Just True)

-- | Whether an item is marked `sitemap: false`, and so left out of the sitemap
isSitemapExcluded :: Metadata -> Bool
isSitemapExcluded o = runCheck (optional o K.Sitemap) == Right (Just False)

-- | Whether the current item is marked `templated: true`, and so may use template syntax in its body
isTemplated :: Compiler Bool
isTemplated = do
    metadata <- getUnderlying >>= getMetadata
    return $ K.lookupKey K.Templated metadata == Just "true"

-- | The table of contents label (markdown); 'Nothing' when the page has none.
tocLabelOf :: Metadata -> Maybe String
tocLabelOf o = case K.lookupKey K.TOC o of
    Just "" -> Nothing
    Just label -> Just label
    Nothing -> Nothing

-- | The group an item belongs to: its `group:` front matter, or the folder it sits in under `writings/`
groupOf :: FilePath -> Identifier -> Metadata -> Maybe String
groupOf contentDir ident metadata =
    case K.lookupKey K.Group metadata of
        Just group -> Just group
        Nothing -> do
            rest <- stripPrefix (addTrailingPathSeparator (contentDir </> "writings")) (toFilePath ident)
            case break (== '/') rest of
                (group, '/' : _) -> Just group
                _ -> Nothing

{- | Old paths an item should redirect from (`aliases: [/old]`, or a single `aliases: /old`)

Each must be an absolute path other than the home page.
-}
aliasesOf :: Metadata -> Either [String] [FilePath]
aliasesOf o = do
    aliases <- maybe [] unAliasList <$> runCheck (optional o K.Aliases)
    case concatMap problem aliases of
        [] -> Right aliases
        problems -> Left problems
  where
    problem alias
        | alias == "/" = ["aliases: / is the home page, it can't be an alias"]
        | take 1 alias /= "/" = ["aliases: " ++ show alias ++ " must start with / (like /old-name)"]
        | otherwise = []

-- | A string or a list of strings
newtype AliasList = AliasList {unAliasList :: [String]}

instance FromJSON AliasList where
    parseJSON v@(String _) = AliasList . pure <$> parseJSON v
    parseJSON v = AliasList <$> parseJSON v

-- | 'aliasesOf' on YAML text (the same shape as front matter)
parseAliasesYaml :: String -> Either [String] [FilePath]
parseAliasesYaml = decodeYaml >=> aliasesOf

{- | Sort key for the showcase: projects with a @priority@ first (lowest number
first), then the rest, newest start first
-}
showcaseKey :: Project -> (Int, Down Day)
showcaseKey p = (fromMaybe maxBound (projectPriority p), Down (projectStart p))

-- | Parses the current item's front matter, failing the build with the problems found
requirePost :: Compiler Post
requirePost = do
    metadata <- getUnderlying >>= getMetadata
    either (failWith "invalid front matter") pure (parsePost metadata)

-- | Parses the front matter of any item, failing the build (naming it) with the problems found
requirePostOf :: Identifier -> Compiler Post
requirePostOf ident = do
    metadata <- getMetadata ident
    either (failWith $ toFilePath ident ++ ": invalid front matter") pure (parsePost metadata)

-- | The language of an item, failing the build if it's not a known one
requireLanguage :: Identifier -> Compiler Language
requireLanguage ident = do
    metadata <- getMetadata ident
    either (failWith $ toFilePath ident ++ ": invalid language") pure (runCheck $ languageOf metadata)

-- | The menu entry of any page, failing the build (naming the page) if it's invalid
requireNav :: Identifier -> Compiler (Maybe NavEntry)
requireNav ident = do
    metadata <- getMetadata ident
    either (failWith $ toFilePath ident ++ ": invalid menu entry") pure (parseNavEntry metadata)

-- | Parses a project item (its body is the YAML), failing the build with the problems found
requireProject :: Item String -> Compiler Project
requireProject = either (failWith "invalid project") pure . parseProjectYaml . itemBody

-- | Parses the socials item (its body is the YAML list), failing the build with the problems found
requireSocials :: Item String -> Compiler [Social]
requireSocials = either (failWith "invalid socials") pure . parseSocialsYaml . itemBody

{- | Fails the build listing the problems.

Hakyll already prefixes the error with the item being compiled, so the message
only says what is wrong (and names the other item when it isn't the one compiling).
-}
failWith :: String -> [String] -> Compiler a
failWith what problems = fail $ what ++ ":\n" ++ intercalate "\n" (map ("  " ++) problems)
