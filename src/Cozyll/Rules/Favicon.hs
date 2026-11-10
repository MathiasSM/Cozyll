-- | Rules that generate the site's icons from the brand logo
module Cozyll.Rules.Favicon (faviconRules) where

import Control.Monad (forM_, when)
import Cozyll.Brand (
    Brand (..),
    LogoFormat (..),
    SiteIcon (..),
    brandSourcePath,
    needsImageMagick,
 )
import Data.Maybe (fromMaybe, isNothing)
import Data.String (fromString)
import Hakyll (
    Rules,
    compile,
    customRoute,
    getResourceLBS,
    match,
    preprocess,
    route,
    unixFilterLBS,
    version,
    withItemBody,
 )
import Hakyll.Core.Logger qualified as Logger
import System.Directory (findExecutable)
import System.Exit (die)

{- | Generates the icons the brand asks for, reading the logo as its source.

Icons with a @content\/static@ file at the same path are skipped (the static
file wins), and a site without a logo gets no icons at all. ImageMagick is only
required when a generated icon actually needs converting.
-}
faviconRules :: FilePath -> Maybe Brand -> Rules ()
faviconRules _ Nothing = message "no media/branding/logo.{svg,png}; skipping favicons"
faviconRules contentDir (Just brand) = do
    forM_ overridden $ \icon ->
        message $ "static/" ++ iconPath icon ++ " wins over the generated icon"
    converter <-
        if needsImageMagick (brandFormat brand) generated
            then preprocess findConverter
            else pure Nothing
    when (needsImageMagick (brandFormat brand) generated && isNothing converter)
        $ preprocess
        $ die
        $ "ImageMagick is required to generate favicons from the logo.\n"
            ++ "Install it (providing 'magick' or 'convert'), or add hand-made icons under content/static/."
    match (fromString $ brandSourcePath contentDir (brandFormat brand)) $
        forM_ generated (processFavicon (brandFormat brand) (fromMaybe "convert" converter))
  where
    icons = brandIcons brand
    generated = filter iconGenerated icons
    overridden = filter (not . iconGenerated) icons

-- | Logs a line at Hakyll's message level (shown without @-v@)
message :: String -> Rules ()
message text = preprocess $ do
    logger <- Logger.new Logger.Message
    Logger.message logger text
    Logger.flush logger

-- | The ImageMagick executable, preferring version 7's @magick@
findConverter :: IO (Maybe String)
findConverter = do
    magick <- findExecutable "magick"
    case magick of
        Just _ -> pure (Just "magick")
        Nothing -> findExecutable "convert"

-- | Generates one icon from the logo; the SVG is copied, the rest converted
processFavicon :: LogoFormat -> String -> SiteIcon -> Rules ()
processFavicon format converter icon = version (iconPath icon) $ do
    route $ customRoute $ const $ iconPath icon
    compile $ case faviconCommand format icon of
        Nothing -> getResourceLBS
        Just args -> getResourceLBS >>= withItemBody (unixFilterLBS converter args)

-- | ImageMagick invocation converting the logo on stdin, if the icon needs one
faviconCommand :: LogoFormat -> SiteIcon -> Maybe [String]
faviconCommand LogoSvg icon
    | iconPath icon == "favicon.svg" = Nothing
faviconCommand format icon
    | iconPath icon == "favicon.ico" =
        Just
            [ "-background"
            , "none"
            , input
            , "-define"
            , "icon:auto-resize=32"
            , "+repage"
            , "ico:-"
            ]
    | iconPath icon == "apple-touch-icon.png" = Just (pngArguments 180 20)
    | iconPath icon == "favicon-192.png" = Just (pngArguments 192 20)
    | iconPath icon == "favicon-512.png" = Just (pngArguments 512 40)
    | otherwise = Nothing
  where
    input = case format of
        LogoSvg -> "svg:-"
        LogoPng -> "png:-"

    pngArguments :: Int -> Int -> [String]
    pngArguments size padding =
        [ "-background"
        , "none"
        , input
        , "-gravity"
        , "center"
        , "-scale"
        , show inner ++ "x" ++ show inner
        , "-extent"
        , show size ++ "x" ++ show size
        , "+repage"
        , "png:-"
        ]
      where
        inner = size - padding * 2
