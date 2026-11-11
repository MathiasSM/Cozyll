-- | Tests for brand discovery, the generated icon list, and manifest parity
module Cozyll.BrandSpec (tests) where

import Control.Exception (bracket)
import Cozyll.Brand (
    Brand (..),
    LogoFormat (..),
    SiteIcon (..),
    brandIconsFor,
    discoverBrand,
    iconHref,
    manifestIcons,
    needsImageMagick,
 )
import Cozyll.Config (siteConfiguration)
import Cozyll.Domain.Website (Manifest (..))
import Cozyll.Fixture (buildFixture, copyTree, withBuildLock)
import Cozyll.Rules.WellKnown (manifestTxt)
import Data.List (isInfixOf)
import Hakyll.Commands qualified as Commands
import Hakyll.Core.Logger qualified as Logger
import System.Directory (
    createDirectoryIfMissing,
    getCurrentDirectory,
    removeFile,
    removePathForcibly,
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
        , discoveryTests
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
                @?= [iconPath icon | icon <- icons, iconType icon == Just "image/png"]
        , testCase "ImageMagick is only needed for a generated conversion" $ do
            needsImageMagick LogoSvg (brandIconsFor LogoSvg []) @?= True
            needsImageMagick
                LogoSvg
                (brandIconsFor LogoSvg ["favicon.ico", "apple-touch-icon.png", "favicon-192.png", "favicon-512.png"])
                @?= False
        ]

discoveryTests :: TestTree
discoveryTests =
    testGroup
        "discoverBrand"
        [ testCase "prefers logo.svg over logo.png" $
            withSystemTempDirectory "brand" $ \dir -> do
                writeLogo dir "logo.png"
                writeLogo dir "logo.svg"
                brand <- discoverBrand dir
                (brandFormat <$> brand) @?= Just LogoSvg
        , testCase "falls back to logo.png" $
            withSystemTempDirectory "brand" $ \dir -> do
                writeLogo dir "logo.png"
                brand <- discoverBrand dir
                (brandFormat <$> brand) @?= Just LogoPng
        , testCase "is Nothing without either logo" $
            withSystemTempDirectory "brand" $ \dir -> do
                brand <- discoverBrand dir
                brand @?= Nothing
        , testCase "marks a static icon as overridden" $
            withSystemTempDirectory "brand" $ \dir -> do
                writeLogo dir "logo.svg"
                createDirectoryIfMissing True (dir </> "static")
                writeFile (dir </> "static" </> "favicon.svg") ""
                brand <- discoverBrand dir
                let icons = maybe [] brandIcons brand
                [iconGenerated icon | icon <- icons, iconPath icon == "favicon.svg"] @?= [False]
        ]

manifestTests :: TestTree
manifestTests =
    testGroup
        "manifestTxt"
        [ testCase "lists exactly the generated PNG icons" $ do
            let output = manifestTxt "Example" manifest (brandIconsFor LogoSvg [])
            assertBool "192 icon" ("/favicon-192.png" `isInfixOf` output)
            assertBool "512 icon" ("/favicon-512.png" `isInfixOf` output)
            assertBool "no ICO" (not ("/favicon.ico" `isInfixOf` output))
            assertBool "no SVG" (not ("/favicon.svg" `isInfixOf` output))
            assertBool "no apple icon" (not ("/apple-touch-icon.png" `isInfixOf` output))
        , testCase "omits the icons key without a logo" $
            assertBool "no icons key" (not ("\"icons\"" `isInfixOf` manifestTxt "Example" manifest []))
        ]

integrationTests :: TestTree
integrationTests =
    testGroup
        "integration"
        [ testCase "the logo drives the head links, the manifest, and the no-logo fallback" $ do
            root <- getCurrentDirectory
            bracket (buildFixture root (root </> "example-content")) (removePathForcibly . fst) $ \(_, site) -> do
                html <- readFile (site </> "index.html")
                assertBool "ico link" ("<link rel=\"icon\" href=\"./favicon.ico\" sizes=\"any\">" `isInfixOf` html)
                assertBool "svg link" ("<link rel=\"icon\" href=\"./favicon.svg\" type=\"image/svg+xml\">" `isInfixOf` html)
                assertBool "apple link" ("<link rel=\"apple-touch-icon\" href=\"./apple-touch-icon.png\">" `isInfixOf` html)
                assertBool "manifest link" ("<link rel=\"manifest\" href=\"./manifest.webmanifest\">" `isInfixOf` html)
                manifest <- readFile (site </> "manifest.webmanifest")
                assertBool "192 icon" ("/favicon-192.png" `isInfixOf` manifest)
                assertBool "512 icon" ("/favicon-512.png" `isInfixOf` manifest)

            withSystemTempDirectory "brand-content" $ \content -> do
                copyTree (root </> "example-content") content
                removeFile (content </> "media" </> "branding" </> "logo.svg")
                removeFile (content </> "media" </> "branding" </> "logo.png")
                bracket (buildFixture root content) (removePathForcibly . fst) $ \(_, site) -> do
                    html <- readFile (site </> "index.html")
                    assertBool "no icon links" (not ("rel=\"icon\"" `isInfixOf` html))
                    assertBool "no apple icon" (not ("apple-touch-icon" `isInfixOf` html))
                    manifest <- readFile (site </> "manifest.webmanifest")
                    assertBool "no icons key" (not ("\"icons\"" `isInfixOf` manifest))
                    logger <- Logger.new Logger.Error
                    result <-
                        withBuildLock
                            $ withCurrentDirectory (takeDirectory site)
                            $ Commands.check siteConfiguration logger Commands.InternalLinks
                    result @?= ExitSuccess
        ]

-- | Writes an empty logo under @media/branding@ (discovery only checks existence)
writeLogo :: FilePath -> FilePath -> IO ()
writeLogo dir name = do
    let branding = dir </> "media" </> "branding"
    createDirectoryIfMissing True branding
    writeFile (branding </> name) ""

-- | A manifest with only the colours the icon list does not touch
manifest :: Manifest
manifest = Manifest "#fff" "#000"
