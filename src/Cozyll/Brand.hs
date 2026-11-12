-- | The configured brand: the logo, the source it resolves to, and the icons
module Cozyll.Brand (
    LogoFormat (..),
    SiteIcon (..),
    Brand (..),
    brandCandidates,
    brandIconsFor,
    iconHref,
    iconNeedsConversion,
    manifestIcons,
    needsImageMagick,
    resolveBrand,
) where

import Control.Monad (filterM)
import Cozyll.Paths (mediaTarget)
import Data.Char (toLower)
import Data.List (isPrefixOf, stripPrefix)
import System.Directory (doesDirectoryExist, doesFileExist, listDirectory)
import System.FilePath.Posix (splitDirectories, takeExtension, (</>))
import System.IO (hPutStrLn, stderr)

-- | The format of a convertible logo source
data LogoFormat = LogoSvg | LogoPng
    deriving (Eq, Show)

-- | An icon the site serves, with the template/manifest fields
data SiteIcon = SiteIcon
    { iconPath :: FilePath
    -- ^ Site-relative path or absolute URL
    , iconRel :: Maybe String
    -- ^ The @rel@ attribute; 'Nothing' for manifest-only icons
    , iconType :: Maybe String
    -- ^ The @type@ attribute
    , iconSizes :: Maybe String
    -- ^ The @sizes@ attribute
    , iconGenerated :: Bool
    -- ^ Whether the favicon rules generate it
    , iconManifest :: Bool
    -- ^ Whether it belongs in @manifest.webmanifest@
    }
    deriving (Eq, Show)

{- | The configured logo, the source it resolves to, and the ordered icon list.
'brandSource' is the content-relative identifier favicon generation reads; it is
'Nothing' when the logo is remote or is used as a single icon. 'brandFormat' is
'Nothing' when no conversion happens.
-}
data Brand = Brand
    { brandLogo :: FilePath
    -- ^ The configured path or URL, for JSON-LD and the header
    , brandSource :: Maybe FilePath
    -- ^ The resolved source identifier, for favicon generation
    , brandFormat :: Maybe LogoFormat
    -- ^ The source format when it can be converted
    , brandIcons :: [SiteIcon]
    -- ^ Every icon, in head/manifest order
    }
    deriving (Eq, Show)

-- | The site path an icon is served at; absolute URLs stay as-is
iconHref :: SiteIcon -> FilePath
iconHref icon
    | isWebUrl (iconPath icon) = iconPath icon
    | otherwise = '/' : dropWhile (== '/') (iconPath icon)

{- | The candidates for a site-relative logo path, in resolution order:
@content\/static@ first, then the media files that publish at that path.
Empty for a URL, a @data:@ URI or an unsafe path.
-}
brandCandidates :: FilePath -> FilePath -> [FilePath]
brandCandidates contentDir logo
    | isWebUrl logo || isDataUrl logo || not (safeSitePath logo) = []
    | otherwise =
        let path = dropWhile (== '/') logo
            static = contentDir </> "static" </> path
            media = contentDir </> "media"
            mediaCandidates = case stripPrefix "images/" path of
                Nothing -> []
                Just rest -> [media </> rest, media </> "branding" </> rest]
            confirmed =
                filter (\candidate -> mediaTarget media candidate == path) mediaCandidates
         in static : confirmed

{- | Resolves the configured logo. A local path must be published by
@content\/static@ or @content\/media@; a missing source warns and omits the logo.
-}
resolveBrand :: FilePath -> Maybe String -> IO (Maybe Brand)
resolveBrand _ Nothing = pure Nothing
resolveBrand contentDir (Just raw)
    | isDataUrl raw = do
        warn "site.logo: data: URLs are not supported (the logo is repeated on every page); omitting the logo"
        pure Nothing
    | isWebUrl raw = pure (Just (urlBrand raw))
    | not (safeSitePath raw) = do
        warn ("site.logo: " ++ raw ++ " must be a site path or an absolute URL; omitting the logo")
        pure Nothing
    | otherwise = do
        overrides <- staticFiles (contentDir </> "static")
        existing <- filterM doesFileExist (brandCandidates contentDir raw)
        case existing of
            [] -> do
                warn ("site.logo: " ++ raw ++ " is not published by content/media or content/static; omitting the logo")
                pure Nothing
            source : _ -> pure (Just (localBrand raw source overrides))

-- | The brand for a remote icon: one icon, no generation
urlBrand :: FilePath -> Brand
urlBrand url = Brand url Nothing Nothing [singleIcon url]

-- | The brand for a local source: generate the icon set for SVG/PNG
localBrand :: FilePath -> FilePath -> [FilePath] -> Brand
localBrand raw source overrides =
    let logo = dropWhile (== '/') raw
     in case logoFormat source of
            Just format -> Brand logo (Just source) (Just format) (brandIconsFor format overrides)
            Nothing -> Brand logo Nothing Nothing [singleIcon logo]

-- | A single icon used as-is, without conversion
singleIcon :: FilePath -> SiteIcon
singleIcon path =
    SiteIcon
        { iconPath = path
        , iconRel = Just "icon"
        , iconType = iconMimeType path
        , iconSizes = Nothing
        , iconGenerated = False
        , iconManifest = True
        }

{- | The ordered icons for a source format, excluding the SVG copy for a raster
logo. A static override suppresses generation and avoids Hakyll's multiple
writes for a route.
-}
brandIconsFor :: LogoFormat -> [FilePath] -> [SiteIcon]
brandIconsFor format overrides =
    icon "favicon.ico" (Just "icon") Nothing (Just "any") False
        : [ icon "favicon.svg" (Just "icon") (Just "image/svg+xml") Nothing False
          | format == LogoSvg
          ]
        ++ [ icon "apple-touch-icon.png" (Just "apple-touch-icon") Nothing Nothing False
           , icon "favicon-192.png" Nothing (Just "image/png") (Just "192x192") True
           , icon "favicon-512.png" Nothing (Just "image/png") (Just "512x512") True
           ]
  where
    icon path rel typ sizes manifest =
        SiteIcon
            { iconPath = path
            , iconRel = rel
            , iconType = typ
            , iconSizes = sizes
            , iconGenerated = path `notElem` overrides
            , iconManifest = manifest
            }

-- | The icons declared in @manifest.webmanifest@
manifestIcons :: [SiteIcon] -> [SiteIcon]
manifestIcons = filter iconManifest

-- | Whether an icon needs ImageMagick (everything except the copied SVG)
iconNeedsConversion :: Maybe LogoFormat -> SiteIcon -> Bool
iconNeedsConversion format icon =
    iconGenerated icon && not (format == Just LogoSvg && iconPath icon == "favicon.svg")

-- | Whether any generated icon needs ImageMagick
needsImageMagick :: Maybe LogoFormat -> [SiteIcon] -> Bool
needsImageMagick format = any (iconNeedsConversion format)

-- | The format of a convertible logo source
logoFormat :: FilePath -> Maybe LogoFormat
logoFormat path = case map toLower (takeExtension path) of
    ".svg" -> Just LogoSvg
    ".png" -> Just LogoPng
    _ -> Nothing

-- | The MIME type inferred from a file name, when known
iconMimeType :: FilePath -> Maybe String
iconMimeType path = case map toLower (takeExtension path) of
    ".svg" -> Just "image/svg+xml"
    ".png" -> Just "image/png"
    ".ico" -> Just "image/x-icon"
    ".gif" -> Just "image/gif"
    ".jpg" -> Just "image/jpeg"
    ".jpeg" -> Just "image/jpeg"
    ".webp" -> Just "image/webp"
    _ -> Nothing

-- | Whether a path is a safe site-relative path (no @..@ or @.@ segments)
safeSitePath :: FilePath -> Bool
safeSitePath path =
    let segments = splitDirectories (dropWhile (== '/') path)
     in not (null segments) && all (`notElem` [".", ".."]) segments

-- | Whether a value is a protocol-relative or absolute web URL
isWebUrl :: String -> Bool
isWebUrl value =
    let lowered = map toLower value
     in "//" `isPrefixOf` lowered
            || "http://" `isPrefixOf` lowered
            || "https://" `isPrefixOf` lowered

-- | Whether a value is a @data:@ URI
isDataUrl :: String -> Bool
isDataUrl = isPrefixOf "data:" . map toLower

-- | Logs a configuration warning at the message level
warn :: String -> IO ()
warn = hPutStrLn stderr

-- | Every file under the static directory, relative to it
staticFiles :: FilePath -> IO [FilePath]
staticFiles dir = do
    present <- doesDirectoryExist dir
    if present then go "" else pure []
  where
    go relative = do
        entries <- listDirectory (dir </> relative)
        fmap concat . mapM (entry relative) $ entries

    entry relative name = do
        let child = if null relative then name else relative </> name
        isDir <- doesDirectoryExist (dir </> child)
        if isDir then go child else pure [child]
