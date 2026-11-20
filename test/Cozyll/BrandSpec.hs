-- | Tests for brand resolution, the generated icon list, and manifest parity
module Cozyll.BrandSpec (tests) where

import Cozyll.Brand (
    Brand (..),
    LogoFormat (..),
    SiteIcon (..),
    brandIcons,
    brandIconsFor,
    iconHref,
    manifestIcons,
    needsImageMagick,
    resolveBrand,
 )
import Cozyll.Config (Env (Example), siteConfiguration)
import Cozyll.Domain.Website (Manifest (..))
import Cozyll.Fixture (copyTree, withBuildLock, withBuiltExample, withBuiltFrom)
import Cozyll.Rules.WellKnown (manifestTxt)
import Cozyll.TestUtils (assertContains, assertNotContains, replaceInFile)
import Hakyll.Commands qualified as Commands
import Hakyll.Core.Logger qualified as Logger
import System.Directory (
    createDirectoryIfMissing,
    doesFileExist,
    getCurrentDirectory,
    removeFile,
    withCurrentDirectory,
 )
import System.Exit (ExitCode (..))
import System.FilePath (takeDirectory, (</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))

tests :: TestTree
tests =
    testGroup
        "Brand"
        [ iconListTests
        , resolutionTests
        , manifestTests
        , integrationTests
        ]

iconListTests :: TestTree
iconListTests =
    testGroup
        "brandIcons"
        [ testCase "an SVG logo yields the SVG plus the raster icons" $ do
            let icons = brandIconsFor LogoSvg []
            map iconPath icons
                @?= ["favicon.ico", "favicon.svg", "apple-touch-icon.png", "favicon-192.png", "favicon-512.png"]
            map iconHref icons
                @?= ["/favicon.ico", "/favicon.svg", "/apple-touch-icon.png", "/favicon-192.png", "/favicon-512.png"]
            map iconRel icons
                @?= [Just "icon", Just "icon", Just "apple-touch-icon", Nothing, Nothing]
            map iconType icons
                @?= [Nothing, Just "image/svg+xml", Nothing, Just "image/png", Just "image/png"]
            map iconSizes icons
                @?= [Just "any", Nothing, Nothing, Just "192x192", Just "512x512"]
            map iconGenerated icons @?= [True, True, True, True, True]
            map iconManifest icons @?= [False, False, False, True, True]
        , testCase "a PNG logo has no SVG icon" $
            map iconPath (brandIconsFor LogoPng [])
                @?= ["favicon.ico", "apple-touch-icon.png", "favicon-192.png", "favicon-512.png"]
        , testCase "a static file keeps its icon but suppresses generation" $ do
            let icons = brandIconsFor LogoSvg ["favicon.svg", "favicon-192.png"]
            length icons @?= 5
            map iconGenerated icons @?= [True, False, True, False, True]
        , testCase "the manifest icons are the PNG icons" $ do
            let icons = brandIconsFor LogoSvg []
            map iconPath (manifestIcons icons)
                @?= ["favicon-192.png", "favicon-512.png"]
            map iconPath (manifestIcons icons)
                @?= [iconPath icon | icon <- icons, iconManifest icon]
        , testCase "ImageMagick is only needed for a generated conversion" $ do
            needsImageMagick (Just LogoSvg) (brandIconsFor LogoSvg []) @?= True
            needsImageMagick
                (Just LogoSvg)
                (brandIconsFor LogoSvg ["favicon.ico", "apple-touch-icon.png", "favicon-192.png", "favicon-512.png"])
                @?= False
        ]

resolutionTests :: TestTree
resolutionTests =
    testGroup
        "resolveBrand"
        [ testCase "resolves a local SVG from media/branding" $
            withContent $ \dir -> do
                writeFileAt dir "media/branding/logo.svg" ""
                brand <- resolveBrand dir (Just "images/logo.svg")
                (brandLogo <$> brand) @?= Just "images/logo.svg"
                (brandFormat <$> brand) @?= Just (Just LogoSvg)
                (brandSource <$> brand) @?= Just (Just (dir </> "media" </> "branding" </> "logo.svg"))
        , testCase "resolves a local PNG from media/branding" $
            withContent $ \dir -> do
                writeFileAt dir "media/branding/logo.png" ""
                brand <- resolveBrand dir (Just "images/logo.png")
                (brandFormat <$> brand) @?= Just (Just LogoPng)
        , testCase "prefers a static source over media" $
            withContent $ \dir -> do
                writeFileAt dir "media/branding/logo.svg" ""
                writeFileAt dir "static/images/logo.svg" ""
                brand <- resolveBrand dir (Just "images/logo.svg")
                (brandSource <$> brand) @?= Just (Just (dir </> "static" </> "images" </> "logo.svg"))
        , testCase "uses a non-convertible source as a single icon" $
            withContent $ \dir -> do
                writeFileAt dir "static/favicon.ico" ""
                brand <- resolveBrand dir (Just "favicon.ico")
                (brandSource <$> brand) @?= Just Nothing
                (brandFormat <$> brand) @?= Just Nothing
                (map iconPath . brandIcons <$> brand) @?= Just ["favicon.ico"]
                (map iconManifest . brandIcons <$> brand) @?= Just [True]
        , testCase "uses a remote URL as a single icon" $
            withContent $ \dir -> do
                brand <- resolveBrand dir (Just "https://cdn.example.com/logo.svg")
                (brandLogo <$> brand) @?= Just "https://cdn.example.com/logo.svg"
                (brandSource <$> brand) @?= Just Nothing
                (brandFormat <$> brand) @?= Just Nothing
                (map iconHref . brandIcons <$> brand) @?= Just ["https://cdn.example.com/logo.svg"]
                (map iconManifest . brandIcons <$> brand) @?= Just [True]
        , testCase "rejects data: URLs" $
            withContent $ \dir -> do
                brand <- resolveBrand dir (Just "data:image/svg+xml,<svg/>")
                brand @?= Nothing
        , testCase "omits a path that is not published" $
            withContent $ \dir -> do
                brand <- resolveBrand dir (Just "images/missing.svg")
                brand @?= Nothing
        , testCase "is Nothing without site.logo" $
            withContent $ \dir -> do
                brand <- resolveBrand dir Nothing
                brand @?= Nothing
        ]

manifestTests :: TestTree
manifestTests =
    testGroup
        "manifestTxt"
        [ testCase "lists exactly the generated PNG icons" $ do
            let output = manifestTxt "Example" manifest (brandIconsFor LogoSvg [])
            assertContains "/favicon-192.png" output
            assertContains "/favicon-512.png" output
            assertNotContains "/favicon.ico" output
            assertNotContains "/favicon.svg" output
            assertNotContains "/apple-touch-icon.png" output
        , testCase "omits the icons key without a logo" $
            assertNotContains "\"icons\"" (manifestTxt "Example" manifest [])
        , testCase "includes a single URL icon without sizes" $ do
            let icon =
                    SiteIcon
                        { iconPath = "https://cdn.example.com/logo.svg"
                        , iconRel = Just "icon"
                        , iconType = Just "image/svg+xml"
                        , iconSizes = Nothing
                        , iconGenerated = False
                        , iconManifest = True
                        }
                output = manifestTxt "Example" manifest [icon]
            assertContains "https://cdn.example.com/logo.svg" output
            assertContains "\"type\": \"image/svg+xml\"" output
            assertNotContains "\"sizes\"" output
        ]

integrationTests :: TestTree
integrationTests =
    testGroup
        "integration"
        [ testCase "the configured logo drives the head, the header, the manifest and JSON-LD" $ do
            root <- getCurrentDirectory
            withBuiltExample $ \_ site -> do
                html <- readFile (site </> "index.html")
                assertContains "<link rel=\"icon\" href=\"./favicon.ico\" sizes=\"any\">" html
                assertContains "<link rel=\"icon\" href=\"./favicon.svg\" type=\"image/svg+xml\">" html
                assertContains "<link rel=\"apple-touch-icon\" href=\"./apple-touch-icon.png\">" html
                assertContains "<img src=\"./images/logo.svg\" alt>" html
                assertContains "https://example.com/images/logo.svg" html
                manifestText <- readFile (site </> "manifest.webmanifest")
                assertContains "/favicon-192.png" manifestText
                assertContains "/favicon-512.png" manifestText

                nested <- readFile (site </> "languages" </> "japanese" </> "index.html")
                assertContains "<img src=\"../../images/logo.svg\" alt>" nested

            withSystemTempDirectory "brand-content" $ \content -> do
                copyTree (root </> "example-content") content
                replaceInFile (content </> "website.yaml") "  logo: images/logo.svg\n" ""
                removeFile (content </> "media" </> "branding" </> "logo.svg")
                withBuiltFrom Example content $ \_ site -> do
                    html <- readFile (site </> "index.html")
                    assertNotContains "rel=\"icon\"" html
                    assertNotContains "apple-touch-icon" html
                    assertNotContains "<img src=\"./images/logo.svg\"" html
                    assertNotContains "\"logo\":" html
                    manifestText <- readFile (site </> "manifest.webmanifest")
                    assertNotContains "\"icons\"" manifestText
                    logger <- Logger.new Logger.Error
                    result <-
                        withBuildLock
                            $ withCurrentDirectory (takeDirectory site)
                            $ Commands.check siteConfiguration logger Commands.InternalLinks
                    result @?= ExitSuccess

            withSystemTempDirectory "brand-remote" $ \content -> do
                copyTree (root </> "example-content") content
                replaceInFile
                    (content </> "website.yaml")
                    "logo: images/logo.svg"
                    "logo: https://cdn.example.com/logo.svg"
                withBuiltFrom Example content $ \_ site -> do
                    html <- readFile (site </> "index.html")
                    assertContains "<link rel=\"icon\" href=\"https://cdn.example.com/logo.svg\" type=\"image/svg+xml\">" html
                    assertContains "<img src=\"https://cdn.example.com/logo.svg\" alt>" html
                    assertContains "https://cdn.example.com/logo.svg" html
                    manifestText <- readFile (site </> "manifest.webmanifest")
                    assertContains "https://cdn.example.com/logo.svg" manifestText
                    assertBool "no generated ico" . not =<< doesFileExist (site </> "favicon.ico")
                    assertBool "no generated svg" . not =<< doesFileExist (site </> "favicon.svg")
        ]

-- | Runs an action in a temporary content directory
withContent :: (FilePath -> IO a) -> IO a
withContent = withSystemTempDirectory "brand"

-- | Writes a file below a content root, creating its parent directories
writeFileAt :: FilePath -> FilePath -> String -> IO ()
writeFileAt root relative contents = do
    let path = root </> relative
    createDirectoryIfMissing True (takeDirectory path)
    writeFile path contents

-- | A manifest with only the colours the icon list does not touch
manifest :: Manifest
manifest = Manifest "#fff" "#000"
