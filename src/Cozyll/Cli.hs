{-# LANGUAGE Trustworthy #-}

-- | The command-line interface and its subcommands
module Cozyll.Cli (cli) where

import Control.Monad (filterM, unless)
import Cozyll.Cli.Data (runDataCommand)
import Cozyll.Config (Env (..), SiteConfig (..), requiredContent, siteConfiguration)
import Cozyll.Domain.Author qualified as Author
import Cozyll.Domain.Website qualified as Web
import Cozyll.Ruby.Index (dataDirName, indexFileName, indexLimitIO, loadIndexFile)
import Cozyll.Rules (rules)
import Cozyll.Theme (discoverContentTemplateNames)
import Data.Maybe (fromMaybe)
import Data.Time (getCurrentTime, utctDay)
import Data.Time.Calendar (toGregorian)
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
    env <- parseEnv =<< lookupEnv "SITE_ENV"
    let contentDir = contentDirFor env
    -- 1. Parse args
    args <- getArgs
    -- 2. `data` is a pre-Hakyll command and must not require website.yaml
    case args of
        ("data" : rest) -> runDataCommand contentDir rest
        _ -> runBuild env contentDir args

-- | The build/server/clean commands, which need @website.yaml@ and Hakyll
runBuild :: Env -> FilePath -> [String] -> IO ()
runBuild env contentDir args = do
    -- 2. Get and validate website files/config
    -- (`website.yaml` is always required, even for `clean`)
    website <- Web.loadWebsite contentDir
    unless ("clean" `elem` args) (Web.validateSecurityExpiration website)
    -- 3. Check content exists
    cfg <- loadSiteConfig env contentDir website
    unless ("clean" `elem` args) (ensureContentExists cfg)
    -- 4. Load the derived ruby index (if the content provides one)
    limit <- indexLimitIO
    rubyData <-
        if "clean" `elem` args
            then pure Nothing
            else loadIndexFile limit (contentDir </> dataDirName </> indexFileName) >>= either die pure
    -- 5. Run command
    hakyllWith siteConfiguration (rules cfg{siteRubyData = rubyData} website)

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
loadSiteConfig :: Env -> FilePath -> Web.Website -> IO SiteConfig
loadSiteConfig env contentDir website = do
    let site = Web.websiteSite website
    title <- override "SITE_TITLE" (Web.siteTitle site)
    description <- override "SITE_DESCRIPTION" (Web.siteDescription site)
    year <- override "SITE_COPYRIGHT_YEAR" (Web.siteCopyrightYear site)
    domain <- override "SITE_DOMAIN" (Web.siteDomain site)
    mathjax <- override "MATHJAX_VERSION" (Web.mathjaxVersion (Web.websiteMathjax website))
    highlight <- highlightStyleFromEnv (Web.websiteHighlight website)
    contentTemplates <- discoverContentTemplateNames (contentDir </> "templates")
    authors <- Author.loadAuthors contentDir
    defaultAuthor' <- either (die . unlines) pure (Author.defaultAuthor authors)
    today <- utctDay <$> getCurrentTime
    let (currentYearInteger, _, _) = toGregorian today
        currentYear = fromIntegral currentYearInteger
    pure
        SiteConfig
            { siteTitle = title
            , siteDescription = description
            , siteCopyrightYear = year
            , siteCurrentYear = currentYear
            , siteDomain = domain
            , siteAlternateNames = Web.siteAlternateNames site
            , siteLogo = Web.siteLogo site
            , siteAuthors = authors
            , siteDefaultAuthor = defaultAuthor'
            , mathjaxVersion = mathjax
            , highlightStyle = highlight
            , contentDir = contentDir
            , assetsDir = "assets" -- TODO
            , templatesDir = "templates" -- TODO
            , contentTemplatesDir = contentDir </> "templates"
            , contentCssDir = contentDir </> "css"
            , contentTemplateNames = contentTemplates
            , siteEnv = env
            , siteRubyData = Nothing
            }
  where
    override :: (Read a) => String -> a -> IO a
    override var fallback = fromMaybe fallback . (>>= readMaybe) <$> lookupEnv var

    -- Unlike 'override', unknown values fail (matching the strict @website.yaml@ parsing)
    highlightStyleFromEnv :: Web.Highlight -> IO Web.HighlightStyle
    highlightStyleFromEnv section = do
        value <- lookupEnv "HIGHLIGHT_STYLE"
        case value of
            Nothing -> pure (Web.highlightStyle section)
            Just name -> maybe (die $ "unknown HIGHLIGHT_STYLE \"" ++ name ++ "\"") pure (Web.parseHighlightStyle name)

{- | Parses @SITE_ENV@ (@dev@, @example@, or @prod@). Unset defaults to 'Prod'; any
other value fails the build.
-}
parseEnv :: Maybe String -> IO Env
parseEnv Nothing = pure Prod
parseEnv (Just "prod") = pure Prod
parseEnv (Just "dev") = pure Dev
parseEnv (Just "example") = pure Example
parseEnv (Just other) = die $ "unknown SITE_ENV \"" ++ other ++ "\" (expected prod, dev, or example)"

-- | The content directory an environment builds (@example@ builds the example content)
contentDirFor :: Env -> FilePath
contentDirFor Example = "example-content"
contentDirFor _ = "content"
