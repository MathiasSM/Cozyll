{-# LANGUAGE Trustworthy #-}

-- | The command-line interface and its subcommands
module Cozyll.Cli (cli) where

import Control.Monad (filterM, unless)
import Cozyll.Config (Env (..), SiteConfig (..), requiredContent, siteConfiguration)
import Cozyll.Domain.Website qualified as Web
import Cozyll.Rules (rules)
import Cozyll.Theme (discoverContentTemplateNames)
import Data.Maybe (fromMaybe)
import Hakyll (hakyllWith)
import System.Directory (doesDirectoryExist, doesFileExist)
import System.Environment (getArgs, lookupEnv)
import System.Exit (die)
import System.FilePath.Posix ((</>))
import Text.Read (readMaybe)

{- | Main entrypoint for the cli subcommands (usually called like @cabal run cozyll SUBCMD@)

[@build@]: Generate the site into @_site@
[@clean@]: Clean the generated files from @_site@
[@rebuild@]: Runs @clean@ + @build@
[@server@]: Setup a quick dev server serving the files in @_site@
[@watch@]: Build, serve and rebuild site pieces as code changes
[@check@]: Verify broken links in @_site@ files

Note: build commands check for required content before running.
-}
cli :: IO ()
cli = do
    let contentDir = "content"
    -- 1. Parse args
    args <- getArgs
    -- 2. Get and validate website files/config
    -- (`website.yaml` is always required, even for `clean`)
    website <- Web.loadWebsite contentDir
    unless ("clean" `elem` args) (Web.validateSecurityExpiration website)
    -- 3. Check content exists
    cfg <- loadSiteConfig contentDir website
    unless ("clean" `elem` args) (ensureContentExists cfg)
    -- 4. Run command
    hakyllWith siteConfiguration (rules cfg website)

{- | Throws if the content repo is missing, or lacks a file the site needs

(Hakyll would otherwise build whatever it finds, possibly silently leaving out missing pages)
-}
ensureContentExists :: SiteConfig -> IO ()
ensureContentExists cfg = do
    present <- doesDirectoryExist $ contentDir cfg
    unless present
        $ die
        $ contentDir cfg ++ "/ not found"
    missing <- filterM (fmap not . doesFileExist) (requiredContent cfg)
    unless (null missing)
        $ die
        $ "Missing required content:\n" ++ unlines (map ("  " ++) missing)

-- | Builds the site configuration from @website.yaml@, with env variables overrides.
loadSiteConfig :: FilePath -> Web.Website -> IO SiteConfig
loadSiteConfig contentDir website = do
    let site = Web.websiteSite website
    env <- siteEnv <$> lookupEnv "SITE_ENV"
    name <- override "SITE_NAME" (Web.siteName site)
    description <- override "SITE_DESCRIPTION" (Web.siteDescription site)
    author <- override "SITE_AUTHOR" (Web.siteAuthor site)
    year <- override "SITE_COPYRIGHT_YEAR" (Web.siteCopyrightYear site)
    domain <- override "SITE_DOMAIN" (Web.siteDomain site)
    twitter <- override "TWITTER_HANDLE" (Web.siteTwitterHandle site)
    authorUrl <- overrideOptional "SITE_AUTHOR_URL" (Web.siteAuthorUrl site)
    let contact = Web.websiteContact website
    mathjax <- override "MATHJAX_VERSION" (Web.mathjaxVersion (Web.websiteMathjax website))
    highlight <- highlightStyleFromEnv (Web.websiteHighlight website)
    contentTemplates <- discoverContentTemplateNames (contentDir </> "templates")
    pure
        SiteConfig
            { siteName = name
            , siteDescription = description
            , siteAuthor = author
            , siteAuthorUrl = authorUrl
            , siteCopyrightYear = year
            , siteDomain = domain
            , twitterHandle = twitter
            , contactEmail = Web.contactEmail contact
            , contactPage = Web.contactPage contact
            , mathjaxVersion = mathjax
            , highlightStyle = highlight
            , contentDir = contentDir
            , assetsDir = "assets" -- TODO
            , templatesDir = "templates" -- TODO
            , contentTemplatesDir = contentDir </> "templates"
            , contentCssDir = contentDir </> "css"
            , contentTemplateNames = contentTemplates
            , siteEnv = env
            }
  where
    override :: (Read a) => String -> a -> IO a
    override var fallback = fromMaybe fallback . (>>= readMaybe) <$> lookupEnv var

    -- An optional string override; an empty value falls back to the default
    overrideOptional :: String -> Maybe String -> IO (Maybe String)
    overrideOptional var fallback = do
        value <- lookupEnv var
        pure $ case value of
            Just v | not (null v) -> Just v
            _ -> fallback

    -- Unlike 'override', unknown values fail (matching the strict @website.yaml@ parsing)
    highlightStyleFromEnv :: Web.Highlight -> IO Web.HighlightStyle
    highlightStyleFromEnv section = do
        value <- lookupEnv "HIGHLIGHT_STYLE"
        case value of
            Nothing -> pure (Web.highlightStyle section)
            Just name -> maybe (die $ "unknown HIGHLIGHT_STYLE \"" ++ name ++ "\"") pure (Web.parseHighlightStyle name)

    -- Defaults to Prod; unknown values currently also fall through to Prod.
    -- TODO: Let's have a stricter parse; unknown values should fail
    siteEnv (Just "prod") = Prod
    siteEnv (Just "dev") = Dev
    siteEnv _ = Prod
