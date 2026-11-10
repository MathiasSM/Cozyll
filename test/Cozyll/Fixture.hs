-- | Shared fixture helpers: a 'SiteConfig' builder and a full site build
module Cozyll.Fixture (
    mkSiteConfig,
    mkSiteConfigFor,
    buildFixture,
    buildFixtureFor,
    withBuildLock,
    loadFixtureConfig,
    loadFixtureConfigFor,
    runBuild,
    copyTree,
) where

import Control.Concurrent.MVar (MVar, newMVar, withMVar)
import Control.Monad (forM_, when)
import Cozyll.Brand (Brand, brandLogo, discoverBrand)
import Cozyll.Config (Env (..), SiteConfig (..), siteConfiguration)
import Cozyll.Domain.Author qualified as Author
import Cozyll.Domain.Website (loadWebsite)
import Cozyll.Domain.Website qualified as Web
import Cozyll.Ruby.Index (RubyData, defaultMaxIndexBytes, loadIndexFile)
import Cozyll.Rules (rules)
import Cozyll.Theme (discoverContentTemplateNames)
import Hakyll.Commands qualified as Commands
import Hakyll.Core.Logger qualified as Logger
import Hakyll.Core.Runtime (RunMode (RunModeNormal))
import System.Directory (copyFile, createDirectoryIfMissing, doesDirectoryExist, listDirectory, withCurrentDirectory)
import System.Exit (ExitCode (..), exitFailure)
import System.FilePath ((</>))
import System.IO.Temp (createTempDirectory, getCanonicalTemporaryDirectory)
import System.IO.Unsafe (unsafePerformIO)

{- | Serialises fixture builds: 'withCurrentDirectory' is process-wide, so two
concurrent builds would interleave their working directories.
-}
{-# NOINLINE buildLock #-}
buildLock :: MVar ()
buildLock = unsafePerformIO (newMVar ())

-- | Runs an action while holding the fixture-build lock
withBuildLock :: IO a -> IO a
withBuildLock action = withMVar buildLock (const action)

-- | Builds an 'Example' 'SiteConfig' from a parsed @website.yaml@
mkSiteConfig :: Web.Website -> [Author.Author] -> [FilePath] -> Maybe Brand -> Maybe RubyData -> SiteConfig
mkSiteConfig = mkSiteConfigFor Example

-- | Builds a 'SiteConfig' for @env@ from a parsed @website.yaml@ (no environment overrides)
mkSiteConfigFor :: Env -> Web.Website -> [Author.Author] -> [FilePath] -> Maybe Brand -> Maybe RubyData -> SiteConfig
mkSiteConfigFor env website authors contentTemplateNames brand rubyData =
    let site = Web.websiteSite website
        defaultAuthor' = either (error . unlines) id (Author.defaultAuthor authors)
        logo = case Web.siteLogo site of
            Just path -> Just path
            Nothing -> brandLogo <$> brand
     in SiteConfig
            { siteTitle = Web.siteTitle site
            , siteDescription = Web.siteDescription site
            , siteCopyrightYear = Web.siteCopyrightYear site
            , siteCurrentYear = 2021
            , siteDomain = Web.siteDomain site
            , siteAlternateNames = Web.siteAlternateNames site
            , siteLogo = logo
            , siteBrand = brand
            , siteAuthors = authors
            , siteDefaultAuthor = defaultAuthor'
            , mathjaxVersion = Web.mathjaxVersion (Web.websiteMathjax website)
            , highlightStyle = Web.highlightStyle (Web.websiteHighlight website)
            , contentDir = "content"
            , assetsDir = "assets"
            , templatesDir = "templates"
            , contentTemplatesDir = "content/templates"
            , contentCssDir = "content/css"
            , contentTemplateNames = contentTemplateNames
            , siteEnv = env
            , siteRubyData = rubyData
            , siteJaRubyCheck = Web.websiteJaRubyCheck website
            }

{- | Loads the configuration and the website of a fixture build directory.

The directory must hold the vendored @templates/@ and @assets/@ next to the
@content/@ directory; this is what 'buildFixture' sets up and what a second
build (e.g. the cache regression test) reloads after changing the content.
-}
loadFixtureConfig :: FilePath -> IO (SiteConfig, Web.Website)
loadFixtureConfig = loadFixtureConfigFor Example

-- | 'loadFixtureConfig' for @env@
loadFixtureConfigFor :: Env -> FilePath -> IO (SiteConfig, Web.Website)
loadFixtureConfigFor env buildDir = do
    let contentDir = buildDir </> "content"
    website <- loadWebsite contentDir
    contentTemplateNames <- discoverContentTemplateNames (contentDir </> "templates")
    authors <- Author.loadAuthors contentDir
    brand <- discoverBrand contentDir
    loaded <- loadIndexFile defaultMaxIndexBytes (contentDir </> "ruby-data" </> "index.json")
    rubyData <- either error pure loaded
    pure (mkSiteConfigFor env website authors contentTemplateNames brand rubyData, website)

-- | Builds the site in @buildDir@, returning Hakyll's exit code
runBuild :: FilePath -> SiteConfig -> Web.Website -> IO ExitCode
runBuild buildDir cfg website = withBuildLock (runBuildIn buildDir cfg website)

-- | 'runBuild' without taking the lock (the caller already holds it)
runBuildIn :: FilePath -> SiteConfig -> Web.Website -> IO ExitCode
runBuildIn buildDir cfg website = withCurrentDirectory buildDir $ do
    -- An Error-only logger keeps the build silent on success
    logger <- Logger.new Logger.Error
    Commands.build RunModeNormal siteConfiguration logger (rules cfg website)

{- | Builds an 'Example' site from @contentSource@ in a fresh temporary
directory (see 'buildFixtureFor').
-}
buildFixture :: FilePath -> FilePath -> IO (FilePath, FilePath)
buildFixture = buildFixtureFor Example

{- | Builds a site for @env@ from @contentSource@ in a fresh temporary
directory, with the vendored templates and assets next to it. Returns the work
directory and its @_site@; the caller removes the work directory afterwards.
-}
buildFixtureFor :: Env -> FilePath -> FilePath -> IO (FilePath, FilePath)
buildFixtureFor env root contentSource = withBuildLock $ do
    work <- getCanonicalTemporaryDirectory >>= \tmp -> createTempDirectory tmp "cozyll-fixture"
    let buildDir = work </> "build"
    copyTree (root </> "templates") (buildDir </> "templates")
    copyTree (root </> "assets") (buildDir </> "assets")
    copyTree contentSource (buildDir </> "content")
    (cfg, website) <- loadFixtureConfigFor env buildDir
    createDirectoryIfMissing True buildDir
    runBuildIn buildDir cfg website >>= \code -> when (code /= ExitSuccess) exitFailure
    pure (work, buildDir </> "_site")

-- | Copies a directory tree, creating the destination as needed
copyTree :: FilePath -> FilePath -> IO ()
copyTree source destination = do
    createDirectoryIfMissing True destination
    entries <- listDirectory source
    forM_ entries $ \entry -> do
        let from = source </> entry
            to = destination </> entry
        isDir <- doesDirectoryExist from
        if isDir then copyTree from to else copyFile from to
