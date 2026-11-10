{- | The example site assembled for integration tests: the vendored theme plus
@example-content@ in a build directory. Shared by the golden suite and the
cache regression test, so both start from exactly the same fixture.
-}
module Cozyll.Fixture (
    mkSiteConfig,
    copyTree,
    exampleSite,
    copyFixture,
) where

import Control.Monad (forM_)
import Cozyll.Config (Env (Example), SiteConfig (..))
import Cozyll.Domain.Author qualified as Author
import Cozyll.Domain.Website (Website)
import Cozyll.Domain.Website qualified as Web
import Cozyll.Ruby.Index (RubyData, defaultMaxIndexBytes, loadIndexFile)
import Cozyll.Theme (discoverContentTemplateNames)
import System.Directory (
    copyFile,
    createDirectoryIfMissing,
    doesDirectoryExist,
    listDirectory,
 )
import System.FilePath ((</>))

-- | Builds a 'SiteConfig' from a parsed @website.yaml@ (no environment overrides)
mkSiteConfig :: Web.Website -> [Author.Author] -> [FilePath] -> Maybe RubyData -> SiteConfig
mkSiteConfig website authors contentTemplateNames rubyData =
    let site = Web.websiteSite website
        defaultAuthor' = either (error . unlines) id (Author.defaultAuthor authors)
     in SiteConfig
            { siteTitle = Web.siteTitle site
            , siteDescription = Web.siteDescription site
            , siteCopyrightYear = Web.siteCopyrightYear site
            , siteCurrentYear = 2021
            , siteDomain = Web.siteDomain site
            , siteAlternateNames = Web.siteAlternateNames site
            , siteLogo = Web.siteLogo site
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
            , siteEnv = Example
            , siteRubyData = rubyData
            , siteJaRubyCheck = Web.websiteJaRubyCheck website
            }

{- | Loads the configuration and the website of @root@'s example content.

The example content's own @website.yaml@ drives the build, so the output does
not depend on the environment.
-}
exampleSite :: FilePath -> IO (SiteConfig, Website)
exampleSite root = do
    website <- Web.loadWebsite (root </> "example-content")
    contentTemplateNames <- discoverContentTemplateNames (root </> "example-content" </> "templates")
    authors <- Author.loadAuthors (root </> "example-content")
    loaded <- loadIndexFile defaultMaxIndexBytes (root </> "example-content" </> "ruby-data" </> "index.json")
    rubyData <- either error pure loaded
    pure (mkSiteConfig website authors contentTemplateNames rubyData, website)

-- | Copies the vendored theme and the example content into a build directory
copyFixture :: FilePath -> FilePath -> IO ()
copyFixture root destination = do
    createDirectoryIfMissing True destination
    copyTree (root </> "templates") (destination </> "templates")
    copyTree (root </> "assets") (destination </> "assets")
    copyTree (root </> "example-content") (destination </> "content")

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
