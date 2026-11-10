-- | Rules for the assets: styles, media, static files, and tables
module Cozyll.Rules.Assets (processAssets, mediaRoute, mediaTarget, staticRoute, staticTarget) where

import Control.Monad (unless)
import Cozyll.Config (SiteConfig, assetsDir, contentCssPattern, contentDir, dataPattern, dataSchemaPattern, highlightStyle, localizationPattern, mediaDir, siteBrand, socialsPattern, staticDir, staticPattern)
import Cozyll.Domain.Website (toPandocStyle)
import Cozyll.Rules.Favicon (faviconRules)
import Data.List (stripPrefix)
import Data.Maybe (fromMaybe)
import Data.String (fromString)
import Hakyll (
    Item (itemBody),
    Pattern,
    Routes,
    Rules,
    compile,
    complement,
    composeRoutes,
    compressCssCompiler,
    copyFileCompiler,
    create,
    customRoute,
    getMatches,
    getResourceLBS,
    getResourceString,
    idRoute,
    loadAll,
    makeItem,
    match,
    preprocess,
    route,
    setExtension,
    templateBodyCompiler,
    toFilePath,
    unixFilterLBS,
    version,
    (.&&.),
    (.||.),
 )
import Hakyll.Web.CompressCss (compressCss)
import System.FilePath.Posix (addTrailingPathSeparator, isAbsolute, splitDirectories, (</>))
import Text.Pandoc.Highlighting (styleToCss)

{- | Processes all assets into the final site.

Media is published as a whole, with no extension whitelist:

| source | published |
|---|---|
| @content\/media\/photos\/x.png@ | @\/images\/photos\/x.png@ |
| @content\/media\/icons\/x.svg@ | @\/images\/icons\/x.svg@ (also inlined as @$iconRaw$@) |
| @content\/media\/branding\/x@ | @\/images\/x@ (also inlined as @$partial$@ when SVG) |
| @content\/media\/<any>\/x@ | @\/images\/<any>\/x@ |
| @content\/media\/x@ | @\/images\/x@ |
| @content\/static\/x@ | @\/x@ |

The default versions keep the compile modes used by templates and data files:
icon SVGs are loaded as raw strings (@$iconRaw$@) and branding SVGs as
templates (@$partial$@). The @\"raw\"@ version publishes every non-@.dot@ file
byte for byte; @.dot@ sources are rendered to PNG instead.
-}
processAssets :: SiteConfig -> Rules ()
processAssets cfg = do
    processCss cfg
    processSvgImages cfg
    processDotImages cfg
    processFavicon cfg
    processMedia cfg
    processStaticFiles cfg
    processDataFiles cfg

-- | Copies every media file (except @.dot@ sources) to its published path
processMedia :: SiteConfig -> Rules ()
processMedia cfg = do
    match (mediaPatternAll cfg .&&. complement (dotPattern cfg)) $
        version "raw" $ do
            route $ mediaRoute (mediaDir cfg)
            compile copyFileCompiler

{- | Copies everything under @content\/static\/@ verbatim to the site root

Invalid identifiers are reported once, before anything is written.
-}
processStaticFiles :: SiteConfig -> Rules ()
processStaticFiles cfg = do
    validateStaticPaths cfg
    match (staticPattern cfg) $ do
        route $ staticRoute (staticDir cfg)
        compile copyFileCompiler

-- | Fails the build, once, listing every static file that would escape the root
validateStaticPaths :: SiteConfig -> Rules ()
validateStaticPaths cfg = do
    identifiers <- getMatches (staticPattern cfg)
    let problems = [toFilePath ident ++ ": " ++ problem | ident <- identifiers, Left problem <- [staticTarget (staticDir cfg) (toFilePath ident)]]
    unless (null problems)
        $ preprocess
        $ ioError
        $ userError
        $ "Invalid static files (they must stay inside the site root):\n" ++ unlines (map ("  " ++) problems)

-- | Makes the data files (YAML) and their schemas loadable; they are not routed
processDataFiles :: SiteConfig -> Rules ()
processDataFiles cfg = do
    match (socialsPattern cfg .||. localizationPattern cfg .||. dataPattern cfg) $ compile getResourceString
    match (dataSchemaPattern cfg) $ compile getResourceString

-- | Compress all CSS as one file
processCss :: SiteConfig -> Rules ()
processCss cfg = do
    match (cssFiles cfg) (compile compressCssCompiler)
    match (contentCssPattern cfg) (compile compressCssCompiler)
    create ["styles.css"] $ do
        route idRoute
        compile $ do
            vendored <- loadAll $ cssFiles cfg
            content <- loadAll $ contentCssPattern cfg
            makeItem $
                unlines (map itemBody (vendored ++ content))
                    ++ compressCss (styleToCss (toPandocStyle (highlightStyle cfg)))

-- | Uses unix external filter (dot) to compile every Graphviz source as png
processDotImages :: SiteConfig -> Rules ()
processDotImages cfg = match (dotPattern cfg) $ do
    route $ mediaRoute (mediaDir cfg) `composeRoutes` setExtension "png"
    compile $ getResourceLBS >>= traverse (unixFilterLBS "dot" ["-Tpng"])

{- | Compiles branding and icons into context (for inlining); the @\"raw\"@ rule
in 'processMedia' publishes the files themselves.
-}
processSvgImages :: SiteConfig -> Rules ()
processSvgImages cfg = do
    -- Branding SVGs (e.g. the logo) are inlined via $partial$, so compile them as templates
    match (mediaPattern cfg "branding" ["svg"]) $ compile templateBodyCompiler
    -- Icon SVGs are inlined via the data files' $iconRaw$, so load them as raw strings
    match (mediaPattern cfg "icons" ["svg"]) $ compile getResourceString

-- | Generates the favicons from the brand logo
processFavicon :: SiteConfig -> Rules ()
processFavicon cfg = faviconRules (contentDir cfg) (siteBrand cfg)

-- | Where the site's own stylesheets live (see 'assetsDir')
cssFiles :: SiteConfig -> Pattern
cssFiles cfg = fromString $ assetsDir cfg </> "css" </> "*.css"

-- | Files with one of the extensions, anywhere under a media category
mediaPattern :: SiteConfig -> String -> [String] -> Pattern
mediaPattern cfg category extensions =
    foldr1 (.||.) [fromString $ mediaDir cfg </> category </> ("**." ++ ext) | ext <- extensions]

-- | Every file under 'mediaDir', whatever its extension
mediaPatternAll :: SiteConfig -> Pattern
mediaPatternAll cfg = fromString $ mediaDir cfg </> "**"

-- | Graphviz sources anywhere under 'mediaDir' (published as PNG)
dotPattern :: SiteConfig -> Pattern
dotPattern cfg = fromString $ mediaDir cfg </> "**.dot"

-- | Publishes a media identifier (see 'mediaTarget' for the route table).
mediaRoute :: FilePath -> Routes
mediaRoute mediaDir' = customRoute $ mediaTarget mediaDir' . toFilePath

{- | The site path a media identifier is published at:

| source | published |
|---|---|
| @media\/photos\/x.png@ | @images\/photos\/x.png@ |
| @media\/icons\/x.svg@ | @images\/icons\/x.svg@ |
| @media\/branding\/x@ | @images\/x@ |
| @media\/<any>\/x@ | @images\/<any>\/x@ |
| @media\/x@ | @images\/x@ |

@branding\/@ is the one flattening special case, so the logo stays at
@images\/logo.svg@.
-}
mediaTarget :: FilePath -> FilePath -> FilePath
mediaTarget mediaDir' path =
    let rest = fromMaybe path (stripPrefix (addTrailingPathSeparator mediaDir') path)
     in "images" </> fromMaybe rest (stripPrefix "branding/" rest)

{- | Copies a static identifier to the site root (see 'staticTarget'). The
identifier has already been checked by 'validateStaticPaths'; the fallback
keeps a hypothetical invalid identifier inside the root rather than writing
outside @_site@.
-}
staticRoute :: FilePath -> Routes
staticRoute staticDir' = customRoute $ \ident ->
    case staticTarget staticDir' (toFilePath ident) of
        Right target -> target
        -- Unreachable: 'validateStaticPaths' fails the build first. Stay inside _site regardless.
        Left _ -> "_invalid-static-path"

{- | The site path a static identifier is published at, relative to the root:
@content\/static\/x@ becomes @x@. Fails for identifiers that are not under the
static directory or would escape the root (absolute paths, @..@ segments).
-}
staticTarget :: FilePath -> FilePath -> Either String FilePath
staticTarget staticDir' path =
    case stripPrefix (addTrailingPathSeparator staticDir') path of
        Nothing -> Left "is not under the static directory"
        Just rest
            | isAbsolute rest -> Left "would be published at an absolute path"
            | ".." `elem` splitDirectories rest -> Left "contains a parent-directory (..) segment"
            | otherwise -> Right rest
