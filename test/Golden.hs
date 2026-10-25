{- | Builds the fixture site in-process and compares its output, file by file,
with the baseline under @test\/golden@. Run with @cabal test golden@; regenerate
the baseline with @cabal test golden --test-options=--accept@.

Images are compared by format and dimensions (their bytes embed timestamps and
vary with the ImageMagick version); everything else byte for byte.
-}
module Golden (
    buildSiteSnapshot,
    relativeFiles,
    goldenTests,
)
where

import Control.Monad (forM, forM_)
import Cozyll.Config (Env (Dev), SiteConfig (..), siteConfiguration)
import Cozyll.Domain.Website (loadWebsite)
import Cozyll.Domain.Website qualified as Web
import Cozyll.Rules (rules)
import Cozyll.Theme (discoverContentTemplateNames)
import Data.ByteString (ByteString)
import Data.ByteString qualified as BS
import Data.List (sort)
import Hakyll.Commands qualified as Commands
import Hakyll.Core.Logger qualified as Logger
import Hakyll.Core.Runtime (RunMode (RunModeNormal))
import System.Directory (
    copyFile,
    createDirectoryIfMissing,
    doesDirectoryExist,
    listDirectory,
    withCurrentDirectory,
 )
import System.Exit (ExitCode (..), exitFailure)
import System.FilePath (takeDirectory, takeExtension, (</>))
import System.IO.Temp (createTempDirectory, getCanonicalTemporaryDirectory)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.Golden (goldenVsFile, writeBinaryFile)

-- | Builds a 'SiteConfig' from a parsed @website.yaml@ (no environment overrides)
mkSiteConfig :: Web.Website -> [FilePath] -> SiteConfig
mkSiteConfig website contentTemplateNames =
    let site = Web.websiteSite website
     in SiteConfig
            { siteName = Web.siteName site
            , siteDescription = Web.siteDescription site
            , siteAuthor = Web.siteAuthor site
            , siteAuthorUrl = Web.siteAuthorUrl site
            , siteCopyrightYear = Web.siteCopyrightYear site
            , siteDomain = Web.siteDomain site
            , twitterHandle = Web.siteTwitterHandle site
            , contactEmail = Web.contactEmail (Web.websiteContact website)
            , contactPage = Web.contactPage (Web.websiteContact website)
            , mathjaxVersion = Web.mathjaxVersion (Web.websiteMathjax website)
            , highlightStyle = Web.highlightStyle (Web.websiteHighlight website)
            , contentDir = "content"
            , assetsDir = "assets"
            , templatesDir = "templates"
            , contentTemplatesDir = "content/templates"
            , contentCssDir = "content/css"
            , contentTemplateNames = contentTemplateNames
            , siteEnv = Dev
            }

{- | Builds the fixture site in a fresh temporary directory and mirrors its
output into a comparable snapshot. Returns the work directory and the
snapshot directory inside it; the caller is responsible for removing the
work directory afterwards.
-}
buildSiteSnapshot :: FilePath -> IO (FilePath, FilePath)
buildSiteSnapshot root = do
    work <- getCanonicalTemporaryDirectory >>= \tmp -> createTempDirectory tmp "golden"
    let buildDir = work </> "build"
        snapshot = work </> "snapshot"
    -- The fixture's own website.yaml drives the build, so the golden output does not depend on the environment
    website <- loadWebsite (root </> "test" </> "fixtures" </> "content")
    contentTemplateNames <- discoverContentTemplateNames (root </> "test" </> "fixtures" </> "content" </> "templates")
    let cfg = mkSiteConfig website contentTemplateNames
    createDirectoryIfMissing True buildDir
    copyTree (root </> "templates") (buildDir </> "templates")
    copyTree (root </> "assets") (buildDir </> "assets")
    copyTree (root </> "test" </> "fixtures" </> "content") (buildDir </> "content")
    copyTree (root </> "dev") (buildDir </> "dev")
    withCurrentDirectory buildDir $ do
        -- An Error-only logger keeps the build silent on success, like the old script
        logger <- Logger.new Logger.Error
        Commands.build RunModeNormal siteConfiguration logger (rules cfg website) >>= \case
            ExitSuccess -> pure ()
            _ -> exitFailure
    buildSnapshot (buildDir </> "_site") snapshot
    pure (work, snapshot)

{- | One golden test per file, comparing the built snapshot against the
baseline in @test\/golden@.
-}
goldenTests :: FilePath -> FilePath -> [FilePath] -> TestTree
goldenTests root snapshot files =
    testGroup "snapshots" $
        [ goldenVsFile file (goldenDir </> file) (snapshot </> file) (pure ())
        | file <- files
        ]
  where
    goldenDir = root </> "test" </> "golden"

{- | Mirrors the build output into a comparable snapshot: every file except
images, plus @images.txt@ listing each image's format and dimensions
-}
buildSnapshot :: FilePath -> FilePath -> IO ()
buildSnapshot site snapshot = do
    files <- relativeFiles site
    let images = [file | file <- files, isImage file]
        others = [file | file <- files, not (isImage file)]
    createDirectoryIfMissing True snapshot
    forM_ others $ \file -> do
        let destination = snapshot </> file
        createDirectoryIfMissing True (takeDirectory destination)
        copyFile (site </> file) destination
    listing <- forM (sort images) $ \file -> do
        bytes <- BS.readFile (site </> file)
        pure $ case imageInfo bytes of
            Just (format, width, height) -> "./" ++ file ++ " " ++ format ++ " " ++ show width ++ "x" ++ show height ++ " "
            Nothing -> "./" ++ file ++ " unknown "
    writeBinaryFile (snapshot </> "images.txt") (unlines listing)

-- | Image files (compared by signature rather than content)
isImage :: FilePath -> Bool
isImage file = takeExtension file `elem` [".png", ".ico"]

-- | Every file below the root, as paths relative to it
relativeFiles :: FilePath -> IO [FilePath]
relativeFiles root = go ""
  where
    go relative = do
        entries <- listDirectory (root </> relative)
        fmap concat . forM entries $ \entry -> do
            let child = if null relative then entry else relative </> entry
            isDir <- doesDirectoryExist (root </> child)
            if isDir then go child else pure [child]

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

{- | The format and dimensions of a PNG or ICO, read from its header

The bytes of these files change between machines (embedded timestamps, converter
version), so their dimensions are compared instead.
-}
imageInfo :: ByteString -> Maybe (String, Int, Int)
imageInfo bytes
    | BS.length bytes >= 24
    , BS.take 8 bytes == pngSignature =
        Just ("PNG", be32 (BS.drop 16 bytes), be32 (BS.drop 20 bytes))
    | BS.length bytes >= 8
    , BS.take 4 bytes == icoSignature =
        Just ("ICO", iconSize 6, iconSize 7)
    | otherwise = Nothing
  where
    pngSignature = BS.pack [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
    icoSignature = BS.pack [0x00, 0x00, 0x01, 0x00]
    be32 bytes' = foldl (\acc index -> acc * 256 + fromIntegral (BS.index bytes' index)) 0 [0 .. 3]
    -- An ICO entry byte of 0 means 256
    iconSize index =
        let size = fromIntegral (BS.index bytes index)
         in if size == 0 then 256 else size
