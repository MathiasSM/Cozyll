-- | The single brand source behind the favicons, the web manifest and JSON-LD
module Cozyll.Brand (
    LogoFormat (..),
    SiteIcon (..),
    Brand (..),
    brandFor,
    brandIconsFor,
    brandLogoPath,
    brandSourcePath,
    iconHref,
    iconNeedsConversion,
    manifestIcons,
    needsImageMagick,
    discoverBrand,
) where

import System.Directory (doesDirectoryExist, doesFileExist, listDirectory)
import System.FilePath.Posix ((</>))

{- | The format of the logo under @content\/media\/branding\/@. SVG wins over
PNG when both exist.
-}
data LogoFormat = LogoSvg | LogoPng
    deriving (Eq, Show)

-- | An icon the site serves from its root, with the template/manifest fields
data SiteIcon = SiteIcon
    { iconPath :: FilePath
    -- ^ Site-relative path, without a leading slash
    , iconRel :: Maybe String
    -- ^ The @rel@ attribute; 'Nothing' for manifest-only icons
    , iconType :: Maybe String
    -- ^ The @type@ attribute
    , iconSizes :: Maybe String
    -- ^ The @sizes@ attribute
    , iconGenerated :: Bool
    -- ^ Whether the favicon rules generate it; 'False' when @content\/static@ provides it
    }
    deriving (Eq, Show)

{- | Everything derived from the site's logo: the source format, the published
logo path, and the ordered icon list.
-}
data Brand = Brand
    { brandFormat :: LogoFormat
    , brandLogo :: FilePath
    -- ^ Published logo path (e.g. @images\/logo.svg@), for JSON-LD
    , brandIcons :: [SiteIcon]
    -- ^ Every icon, in head/manifest order
    }
    deriving (Eq, Show)

-- | The file name of a logo format under @media\/branding@
logoFileName :: LogoFormat -> FilePath
logoFileName LogoSvg = "logo.svg"
logoFileName LogoPng = "logo.png"

-- | The identifier of a logo under a content directory
brandSourcePath :: FilePath -> LogoFormat -> FilePath
brandSourcePath contentDir format = contentDir </> "media" </> "branding" </> logoFileName format

{- | The published path of the logo. Branding files flatten to the images root;
this mirrors @Cozyll.Rules.Assets.mediaTarget@.
-}
brandLogoPath :: LogoFormat -> FilePath
brandLogoPath LogoSvg = "images/logo.svg"
brandLogoPath LogoPng = "images/logo.png"

-- | The site path an icon is served at
iconHref :: SiteIcon -> FilePath
iconHref = ('/' :) . iconPath

{- | The brand for a source format, given the site-relative paths that
@content\/static@ already provides. An icon with a static file at the same path
stays in the list (it is still served) but is not generated.
-}
brandFor :: LogoFormat -> [FilePath] -> Brand
brandFor format overrides = Brand format (brandLogoPath format) (brandIconsFor format overrides)

{- | The ordered icons for a source format, excluding the SVG copy for a raster
logo. A static override suppresses generation and avoids Hakyll's multiple
writes for a route.
-}
brandIconsFor :: LogoFormat -> [FilePath] -> [SiteIcon]
brandIconsFor format overrides =
    icon "favicon.ico" (Just "icon") Nothing (Just "any")
        : [ icon "favicon.svg" (Just "icon") (Just "image/svg+xml") Nothing
          | format == LogoSvg
          ]
        ++ [ icon "apple-touch-icon.png" (Just "apple-touch-icon") Nothing Nothing
           , icon "favicon-192.png" Nothing (Just "image/png") (Just "192x192")
           , icon "favicon-512.png" Nothing (Just "image/png") (Just "512x512")
           ]
  where
    icon path rel typ sizes =
        SiteIcon
            { iconPath = path
            , iconRel = rel
            , iconType = typ
            , iconSizes = sizes
            , iconGenerated = path `notElem` overrides
            }

-- | The icons declared in @manifest.webmanifest@: the PNG icons only
manifestIcons :: [SiteIcon] -> [SiteIcon]
manifestIcons = filter ((== Just "image/png") . iconType)

-- | Whether an icon needs ImageMagick (everything except the copied SVG)
iconNeedsConversion :: LogoFormat -> SiteIcon -> Bool
iconNeedsConversion format icon =
    iconGenerated icon && not (format == LogoSvg && iconPath icon == "favicon.svg")

-- | Whether any generated icon needs ImageMagick
needsImageMagick :: LogoFormat -> [SiteIcon] -> Bool
needsImageMagick format = any (iconNeedsConversion format)

{- | Discovers the brand under a content directory: @logo.svg@ wins over
@logo.png@, and files under @content\/static@ override the generated icon at
the same path. 'Nothing' when neither logo exists.
-}
discoverBrand :: FilePath -> IO (Maybe Brand)
discoverBrand contentDir = do
    overrides <- staticFiles (contentDir </> "static")
    source <- firstPresent [LogoSvg, LogoPng]
    pure (brandFor <$> source <*> pure overrides)
  where
    firstPresent [] = pure Nothing
    firstPresent (format : rest) = do
        present <- doesFileExist (brandSourcePath contentDir format)
        if present then pure (Just format) else firstPresent rest

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
