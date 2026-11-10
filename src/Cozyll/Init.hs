{- | @cozyll init@: scaffolds a minimal, working content repo.

The kit ships next to the binary, so the scaffold reads the kit's
@schema\/example.website.yaml@ (in the current working directory) for the
MathJax version it should pin. Everything else is generated here: copying the
example's fictional site would make a first site look like somebody else's.

The scaffold follows the schema that ships with the same kit: when the schema
still requires @funding:@, a placeholder section is written so the generated
@website.yaml@ is valid; once @funding:@ is optional, the section is omitted and
the generated site has no @funding.json@.
-}
module Cozyll.Init (
    InitOptions (..),
    defaultInitOptions,
    initSite,
) where

import Control.Monad (forM_)
import Cozyll.Domain.Website (Mathjax (..), Website (..))
import Data.Aeson (Value (..))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Time (Day, defaultTimeLocale, formatTime, getCurrentTime, utctDay)
import Data.Time.Calendar (addGregorianYearsRollOver, toGregorian)
import Data.Yaml (ParseException, decodeFileEither, prettyPrintParseException)
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, listDirectory)
import System.FilePath.Posix (takeDirectory, (</>))

-- | Where to scaffold, where the kit's @schema\/@ lives, and whether to overwrite
data InitOptions = InitOptions
    { initDir :: FilePath
    -- ^ Directory to create the site in (the scaffold goes under @<dir>\/content@)
    , initSchemaDir :: FilePath
    -- ^ The kit's schema directory; the CLI uses the default (@schema@ in the CWD)
    , initForce :: Bool
    -- ^ Write the scaffold even when @content\/@ already exists and is not empty
    }
    deriving (Eq, Show)

-- | Scaffold in the current directory, from @schema\/@ in the current directory
defaultInitOptions :: InitOptions
defaultInitOptions =
    InitOptions
        { initDir = "."
        , initSchemaDir = "schema"
        , initForce = False
        }

{- | Creates the content scaffold, returning the files relative to 'initDir'

Returns a 'Left' instead of exiting so the CLI can report the error and the
tests can assert on it.
-}
initSite :: InitOptions -> IO (Either String [FilePath])
initSite options = do
    schema <- loadMathjaxVersion (initSchemaDir options)
    case schema of
        Left problem -> pure $ Left problem
        Right mathjax -> do
            funding <- schemaRequiresFunding (initSchemaDir options)
            target <- checkTarget options
            case target of
                Left problem -> pure $ Left problem
                Right () -> do
                    now <- utctDay <$> getCurrentTime
                    let files = scaffoldFiles now mathjax funding
                    forM_ files $ \(path, contents) -> do
                        let destination = initDir options </> path
                        createDirectoryIfMissing True (takeDirectory destination)
                        writeFile destination contents
                    pure $ Right (map fst files)

-- | Reads the MathJax version the kit pins, failing when the kit is not around
loadMathjaxVersion :: FilePath -> IO (Either String String)
loadMathjaxVersion schemaDir = do
    schemaExists <- doesDirectoryExist schemaDir
    if not schemaExists
        then pure $ Left $ schemaDir ++ "/ not found.\n\n" ++ kitHint
        else do
            let examplePath = schemaDir </> "example.website.yaml"
            exampleExists <- doesFileExist examplePath
            if not exampleExists
                then pure $ Left $ examplePath ++ " not found.\n\n" ++ kitHint
                else do
                    result <- decodeFileEither examplePath :: IO (Either ParseException Website)
                    pure $ case result of
                        Left problem ->
                            Left $ "Invalid " ++ examplePath ++ ":\n" ++ prettyPrintParseException problem
                        Right website -> Right $ mathjaxVersion (websiteMathjax website)

-- | What to tell a user who is not standing in the unpacked kit directory
kitHint :: String
kitHint = "Run 'cozyll init' from the unpacked kit directory (the one with schema/, templates/ and assets/)."

{- | Whether the kit's website schema still requires @funding:@

Pre-optional-funding kits require the section, so the scaffold must include it
to be valid. A missing or unreadable schema defaults to including it, which is
harmless once the field is optional.
-}
schemaRequiresFunding :: FilePath -> IO Bool
schemaRequiresFunding schemaDir = do
    let path = schemaDir </> "website.schema.json"
    exists <- doesFileExist path
    if not exists
        then pure True
        else do
            decoded <- decodeFileEither path :: IO (Either ParseException Value)
            pure $ case decoded of
                Right (Object object) -> case KeyMap.lookup (Key.fromString "required") object of
                    Just (Array required) -> String "funding" `elem` required
                    _ -> False
                _ -> True

-- | Refuses a non-empty @content\/@ unless forced
checkTarget :: InitOptions -> IO (Either String ())
checkTarget options = do
    let contentPath = initDir options </> "content"
    isDirectory <- doesDirectoryExist contentPath
    isFile <- doesFileExist contentPath
    if isFile
        then pure $ Left $ contentPath ++ " exists and is not a directory"
        else
            if not isDirectory
                then pure $ Right ()
                else do
                    entries <- listDirectory contentPath
                    pure $
                        if null entries || initForce options
                            then Right ()
                            else Left $ contentPath ++ " is not empty; pass --force to overwrite the scaffold files"

-- | The scaffold, as @(path relative to the target, contents)@
scaffoldFiles :: Day -> String -> Bool -> [(FilePath, String)]
scaffoldFiles today mathjax funding =
    [ ("content" </> "website.yaml", websiteYaml today mathjax funding)
    , ("content" </> "socials.yaml", socialsYaml)
    , ("content" </> "authors.yaml", authorsYaml)
    , ("content" </> "localization.yaml", localizationYaml)
    , ("content" </> "writings" </> "home.md", homePage)
    , ("content" </> "writings" </> "contact.md", contactPage)
    , ("content" </> ".gitignore", gitignore)
    ]

-- | A minimal @website.yaml@, valid for the kit that ships the schema
websiteYaml :: Day -> String -> Bool -> String
websiteYaml today mathjax funding =
    unlines $
        [ "# Site identity and output switches. Every field is explained in schema/example.website.yaml."
        , "site:"
        , "  title: My site"
        , "  description: A site built with Cozyll."
        , "  copyrightYear: " ++ show copyrightYear
        , "  domain: example.com"
        , ""
        , "# How visitors can reach you."
        , "contact:"
        , "  email: you@example.com"
        , "  page: /contact"
        , ""
        , "# Web app manifest colours."
        , "manifest:"
        , "  backgroundColor: \"#fff\""
        , "  themeColor: \"hsl(210, 75%, 50%)\""
        , ""
        , "mathjax:"
        , "  version: \"" ++ mathjax ++ "\""
        , ""
        , "highlight:"
        , "  style: pygments"
        , ""
        , "feed:"
        , "  size: 20"
        , ""
        , "security:"
        , "  preferredLanguages: en"
        , "  expires: \"" ++ expires ++ "\""
        , "  expirationMarginDays: 90"
        , ""
        , "robots:"
        , "  disallow: [/404.html]"
        , ""
        , "trust:"
        , "  trainingAllowed: \"no\""
        ]
            ++ fundingSection funding
  where
    (copyrightYear, _, _) = toGregorian today
    expires = formatTime defaultTimeLocale "%Y-%m-%d" (addGregorianYearsRollOver 2 today) ++ "T22:59:00.000Z"

-- | A placeholder @funding:@ block, only for kits whose schema still requires it
fundingSection :: Bool -> [String]
fundingSection False = []
fundingSection True =
    [ ""
    , "# funding.json data; delete this section if you do not want a funding manifest."
    , "funding:"
    , "  entity:"
    , "    email: you@example.com"
    , "    description: \"What you are being funded for.\""
    , "  projects:"
    , "    - guid: my-site"
    , "      name: \"My site\""
    , "      description: \"A site built with Cozyll.\""
    , "      repositoryUrl: \"https://github.com/you/my-site\""
    , "      repositoryWellKnown: \"https://github.com/you/my-site/blob/master/static/.well-known/funding-manifest-urls\""
    , "      licenses: [\"spdx:MIT\"]"
    , "      tags: [\"website\"]"
    , "  channels:"
    , "    - guid: funding"
    , "      type: other"
    , "      address: \"\""
    , "      description: \"A funding channel.\""
    , "  plans:"
    , "    - guid: one-time"
    , "      status: active"
    , "      name: \"One-time contribution\""
    , "      description: \"A single contribution.\""
    , "      amount: 0"
    , "      currency: EUR"
    , "      frequency: one-time"
    , "      channels: [\"funding\"]"
    ]

-- | An empty list of social accounts, with the shape of an item in a comment
socialsYaml :: String
socialsYaml =
    unlines
        [ "# Social accounts, shown in the footer and social links."
        , "# Add one item per account, for example:"
        , "#   - icon: github"
        , "#     href: https://github.com/you"
        , "#     username: you"
        , "[]"
        ]

-- | One site-default author
authorsYaml :: String
authorsYaml =
    unlines
        [ "# Authors, keyed by the id used in `author:` front matter."
        , "# Exactly one author must set siteDefault: true."
        , "your-name:"
        , "  name: Your Name"
        , "  siteDefault: true"
        ]

-- | The UI strings the stock templates consume, in English
localizationYaml :: String
localizationYaml =
    unlines
        [ "# UI strings per language, read by the t(\"id\") template function."
        , "# Each used language also needs its og:locale under _ogLocaleDefaultRegion."
        , "aside.controls:"
        , "  en: Controls"
        , ""
        , "post.updated:"
        , "  en: Updated"
        , ""
        , "project.started:"
        , "  en: Started on"
        , ""
        , "project.finished:"
        , "  en: Finished"
        , ""
        , "author.by:"
        , "  en: By"
        , ""
        , "_ogLocaleDefaultRegion: {en: en_US}"
        ]

-- | The home page the rest of the site links to
homePage :: String
homePage =
    unlines
        [ "---"
        , "title: \"My site\""
        , "path: \"/\""
        , "home: true"
        , "---"
        , ""
        , "Welcome to your new Cozyll site. Edit content/writings/home.md to get started."
        ]

-- | The page @contact.page@ in @website.yaml@ points at
contactPage :: String
contactPage =
    unlines
        [ "---"
        , "title: \"Contact\""
        , "path: \"/contact\""
        , "schemaType: ContactPage"
        , "---"
        , ""
        , "Reach me at you@example.com."
        ]

-- | Ignore the build output and coverage files a content repo should not commit
gitignore :: String
gitignore =
    unlines
        [ "_site/"
        , "_cache/"
        , "*.tix"
        ]
