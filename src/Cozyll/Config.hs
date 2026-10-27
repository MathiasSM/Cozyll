-- | Site-wide configuration: identity, where content lives, what groups exist, shared templates
module Cozyll.Config (
    -- * Hakyll's 'Configuration'
    siteConfiguration,

    -- * Deployment config
    SiteConfig (..),
    Env (..),
    baseUrl,

    -- * Files
    requiredContent,
    mediaDir,
    projectsGroup,
    postSnapshot,

    -- * 'Pattern's for files
    writingsPattern,
    pagesPattern,
    postsPattern,
    projectsPattern,
    socialsPattern,
    dataPattern,
    dataSchemaPattern,
    templatePattern,
    contentCssPattern,

    -- * Directories
    dataDir,

    -- * Identifiers

    -- ** Templates
    siteTemplate,
    minimalTemplate,
    pageTemplate,
    postTemplate,
    resolveTemplate,

    -- ** Data files
    socialsFile,
    authorsFile,
)
where

import Cozyll.Domain.Author (Author)
import Cozyll.Domain.Website (HighlightStyle)
import Data.String (fromString)
import Hakyll (Configuration (ignoreFile), Identifier, Pattern, Snapshot, defaultConfiguration, fromFilePath, (.||.))
import System.FilePath.Posix (takeFileName, (<.>), (</>))

{- | The build environment: 'Dev' shows drafts for the real content, 'Example'
builds the example content as the whole site, and 'Prod' is the production
build (drafts hidden).
-}
data Env = Dev | Example | Prod
    deriving (Eq, Show)

{- | Build-time site configuration, gathered once from the environment by "Cozyll.Cli".
Every field maps to an environment variable; see @.env.example@
-}
data SiteConfig = SiteConfig
    { siteTitle :: String
    -- ^ Site title, exposed to templates as @site-title@
    , siteDescription :: String
    -- ^ Site tagline, exposed as @site-description@
    , siteCopyrightYear :: Int
    -- ^ Copyright year, exposed as @site-copyrightYear@
    , siteCurrentYear :: Int
    -- ^ The build year, exposed as @site-copyrightRange@ (the end of the range)
    , siteDomain :: String
    -- ^ Domain without scheme, exposed as @site-domain@
    , siteAlternateNames :: [String]
    -- ^ Alternate site names, exposed as @site-alternateNames@ (JSON-LD only for now)
    , siteLogo :: Maybe String
    -- ^ Site-relative path to the raster logo (e.g. @images/logo.png@), for JSON-LD
    , siteAuthors :: [Author]
    -- ^ Every author, in @authors.yaml@ file order
    , siteDefaultAuthor :: Author
    -- ^ The author marked @siteDefault: true@
    , mathjaxVersion :: String
    {- ^ MathJax CDN version (from @mathjax:@ in @website.yaml@), exposed as @mathjax-version@

    I might some day decide not to use the CDN and rather vend the bundle.
    -}
    , highlightStyle :: HighlightStyle
    -- ^ Pandoc syntax-highlighting style (from @highlight.style@ in @website.yaml@), driving the generated CSS
    , contentDir :: FilePath
    -- ^ Where the actual content lives
    , assetsDir :: FilePath
    -- ^ Where the assests live (@/assets/@ by default)
    , templatesDir :: FilePath
    -- ^ Where the templates live (@/templates/@ by default)
    , contentTemplatesDir :: FilePath
    -- ^ Content-provided templates (@content/templates/@), overriding the vendored set file by file
    , contentCssDir :: FilePath
    -- ^ Content-provided styles (@content/css/@), loaded after the vendored styles
    , contentTemplateNames :: [FilePath]
    -- ^ The template names (relative to 'contentTemplatesDir') the content provides
    , siteEnv :: Env
    -- ^ The build environment (see 'Env')
    }

{- | Hakyll's default configuration, except that `.well-known` folders are not ignored
(Hakyll skips every dot-folder, but `assets/static/.well-known/` must be published)
TODO: Review if condition is correct, or even needed
-}
siteConfiguration :: Configuration
siteConfiguration = defaultConfiguration{ignoreFile = ignore}
  where
    ignore path = takeFileName path /= ".well-known" && ignoreFile defaultConfiguration path

-- | Public origin of the site, without trailing slash
baseUrl :: SiteConfig -> String
baseUrl cfg = "https://" ++ siteDomain cfg

-- | Where the site's media lives: `branding/`, `icons/`, `photos/` (published at `images/`)
mediaDir :: SiteConfig -> FilePath
mediaDir cfg = contentDir cfg </> "media"

{- | Files the site cannot build without, relative to the repo root
(@website.yaml@ is loaded separately by "Cozyll.Domain.Website")
-}
requiredContent :: SiteConfig -> [FilePath]
requiredContent cfg = [contentDir cfg </> "socials.yaml", contentDir cfg </> "authors.yaml"]

-- | The group whose items are the projects (its index page lists `projects/`)
projectsGroup :: String
projectsGroup = "showcase"

-- | Every file under 'contentDir'@/writings/@
writingsPattern :: SiteConfig -> Pattern
writingsPattern cfg = fromString $ contentDir cfg </> "writings" </> "**"

-- | A standalone page or group index page (a flat file under 'contentDir'@/writings/@) named @name@
pagesPattern :: SiteConfig -> String -> Pattern
pagesPattern cfg name = fromString $ contentDir cfg </> "writings" </> name <.> "*"

-- | Items of a post group
postsPattern :: SiteConfig -> String -> Pattern
postsPattern cfg group = fromString $ contentDir cfg </> "writings" </> group </> "**"

-- | All showcase projects
projectsPattern :: SiteConfig -> Pattern
projectsPattern cfg = fromString $ contentDir cfg </> "projects" </> "*.yaml"

-- | The single socials file (a list of accounts)
socialsPattern :: SiteConfig -> Pattern
socialsPattern cfg = fromString $ contentDir cfg </> "socials.yaml"

-- | Where generic data files (any YAML) live
dataDir :: SiteConfig -> FilePath
dataDir cfg = contentDir cfg </> "data"

-- | Every generic data file, at any depth under 'dataDir'
dataPattern :: SiteConfig -> Pattern
dataPattern cfg = fromString $ dataDir cfg </> "**.yaml"

-- | The optional JSON Schema for each data file, co-located as @<name>.schema.json@
dataSchemaPattern :: SiteConfig -> Pattern
dataSchemaPattern cfg = fromString $ dataDir cfg </> "**.schema.json"

-- | Every template the site can use: the vendored defaults plus any content-provided overrides
templatePattern :: SiteConfig -> Pattern
templatePattern cfg = fromString (templatesDir cfg </> "*") .||. fromString (contentTemplatesDir cfg </> "*")

-- | Content-provided styles, loaded after the vendored ones
contentCssPattern :: SiteConfig -> Pattern
contentCssPattern cfg = fromString $ contentCssDir cfg </> "*.css"

-- | The snapshot holding each published post of a single group, as rendered HTML (before templates)
postSnapshot :: String -> Snapshot
postSnapshot group = "published-" ++ group

-- | The data files (YAML) read by contexts
socialsFile :: SiteConfig -> Identifier
socialsFile cfg = fromFilePath $ contentDir cfg </> "socials.yaml"

-- | The authors file (a map keyed by author id)
authorsFile :: SiteConfig -> Identifier
authorsFile cfg = fromFilePath $ contentDir cfg </> "authors.yaml"

-- | Templates every kind of page goes through
siteTemplate, minimalTemplate, pageTemplate, postTemplate :: SiteConfig -> Identifier
siteTemplate cfg = resolveTemplate cfg "site.html"
minimalTemplate cfg = resolveTemplate cfg "minimal.html"
pageTemplate cfg = resolveTemplate cfg "as-page.html"
postTemplate cfg = resolveTemplate cfg "as-post.html"

{- | Resolves a template's bare name (@\"site.html\"@) to the identifier to load:
the content-provided override when one exists, else the vendored default.
-}
resolveTemplate :: SiteConfig -> FilePath -> Identifier
resolveTemplate cfg name
    | name `elem` contentTemplateNames cfg = fromFilePath (contentTemplatesDir cfg </> name)
    | otherwise = fromFilePath (templatesDir cfg </> name)
