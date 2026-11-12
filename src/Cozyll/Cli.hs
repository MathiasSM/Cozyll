{-# LANGUAGE Trustworthy #-}

-- | The command-line interface and its subcommands
module Cozyll.Cli (Invocation (..), cli, invocationFor, parseEnvValue, versionString) where

import Control.Exception (IOException, SomeException, displayException, fromException, try)
import Control.Monad (filterM, unless, void, when)
import Cozyll.Brand (brandLogo, resolveBrand)
import Cozyll.BuildState (
    BuildStart (..),
    BuildState (..),
    applyBuildStart,
    decideBuildStart,
    envText,
    newestContentChange,
    readBuildState,
    siteOutputExists,
    writeBuildState,
 )
import Cozyll.Cli.Data (runDataCommand)
import Cozyll.Config (Env (..), SiteConfig (..), requiredContent, siteConfiguration)
import Cozyll.Domain.Author qualified as Author
import Cozyll.Domain.Language (defaultLanguage)
import Cozyll.Domain.Website qualified as Web
import Cozyll.Init (InitOptions (..), defaultInitOptions, initSite)
import Cozyll.Ruby.Index (dataDirName, indexFileName, indexLimitIO, loadIndexFile)
import Cozyll.Rules (rules)
import Cozyll.Theme (discoverContentTemplateNames)
import Data.Either (fromRight, isRight)
import Data.List (dropWhileEnd, intercalate, isPrefixOf, stripPrefix)
import Data.Maybe (fromMaybe)
import Data.Text qualified as T
import Data.Time (getCurrentTime, utctDay)
import Data.Time.Calendar (toGregorian)
import Data.Version (showVersion)
import Hakyll (Command (..), Options (..), defaultParserInfo, defaultParserPrefs, hakyllWithArgs, hakyllWithExitCodeAndArgs)
import Hakyll.Core.Logger qualified as Logger
import Hakyll.Core.Runtime (RunMode (..))
import Options.Applicative qualified as OA
import Paths_cozyll (version)
import System.Directory (doesDirectoryExist, doesFileExist)
import System.Environment (getArgs, lookupEnv)
import System.Exit (ExitCode (ExitFailure, ExitSuccess), die, exitFailure, exitWith)
import System.FilePath.Posix (takeFileName, (</>))
import System.IO (hFlush, hPutStr, hPutStrLn, stderr, stdout)
import Text.Read (readMaybe)

-- | What the command line asks for before Hakyll's parser gets to see it
data Invocation
    = ShowHelp
    | ShowVersion
    | RunDataArgs [String]
    | Init [String]
    | RunCommand
    deriving (Eq, Show)

{- | Main entrypoint for the cli subcommands (usually called like @cabal run cozyll SUBCMD@)

Arguments are parsed with Hakyll's own parser /before/ any content is loaded, so
@--help@, @--version@ and @-v@/@--verbose@ work without a content repo, and
unknown commands are rejected with a usage message instead of being silently
built. @clean@ and @check@ need no content and skip @SITE_ENV@ validation
entirely; every other command loads @website.yaml@ and the rest of the content
first.

[@--help@]: Print Hakyll's usage and the command list, then exit 0 (also what no
arguments prints)
[@--version@, @-V@]: Print @cozyll \<version\>@; only recognised as the sole
argument
[@init@]: Scaffold a working @content\/@ directory from the kit's schema examples
(needs neither content nor @SITE_ENV@); see 'runInit'
[@-v@, @--verbose@]: Enable debug logging (including the resolved @SITE_ENV@ and
content directory)

[@build@]: Generate the site into @_site@, clearing stale output when @SITE_ENV@ changed
[@clean@]: Clean the generated files from @_site@ (needs no content)
[@rebuild@]: Runs @clean@ + @build@
[@server@]: Setup a quick dev server serving the files in @_site@
[@watch@]: Build, serve and rebuild site pieces as code changes
[@check@]: Verify broken links in @_site@ files, refusing a missing, foreign-env or
stale tree (needs no content)

Note: build commands check for required content before running.
-}
cli :: IO ()
cli = do
    args <- getArgs
    case invocationFor args of
        ShowHelp -> void $ OA.handleParseResult $ parseOptions ["--help"]
        ShowVersion -> putStrLn versionString
        RunDataArgs rest -> do
            env <- parseEnv =<< lookupEnv "SITE_ENV"
            runDataCommand (contentDirFor env) rest
        Init initArgs -> runInit initArgs
        RunCommand -> run args

{- | Classifies the raw arguments: empty means help, a lone @--version@/@-V@
means version; @data@ (pre-Hakyll) and @init@ are our own subcommands.
-}
invocationFor :: [String] -> Invocation
invocationFor [] = ShowHelp
invocationFor ["--version"] = ShowVersion
invocationFor ["-V"] = ShowVersion
invocationFor ("data" : rest) = RunDataArgs rest
invocationFor ("init" : initArgs) = Init initArgs
invocationFor _ = RunCommand

-- | The @--version@ output, e.g. @cozyll 3.3.0.0@
versionString :: String
versionString = "cozyll " ++ showVersion version

-- | What @cozyll init@'s arguments ask for
data InitInvocation = InitHelp | InitRun InitOptions

{- | Runs @cozyll init@: its own tiny parser, no content repo and no @SITE_ENV@

Only the files the scaffold owns are written, so @--force@ never deletes
anything a user added to @content\/@.
-}
runInit :: [String] -> IO ()
runInit args =
    case parseInitArgs args of
        Left problem -> do
            hPutStrLn stderr $ "error: " ++ problem
            hPutStr stderr initUsage
            exitFailure
        Right InitHelp -> putStr initUsage
        Right (InitRun options) -> do
            result <- initSite options
            case result of
                Left problem -> die problem
                Right files -> reportInit options files

{- | Parses @cozyll init@'s flags: @--dir DIR@, @--force@, @-h@/@--help@

Anything else is an error, so a typo never silently scaffolds in the wrong
place.
-}
parseInitArgs :: [String] -> Either String InitInvocation
parseInitArgs = go defaultInitOptions
  where
    go options [] = Right $ InitRun options
    go _ ("--help" : _) = Right InitHelp
    go _ ("-h" : _) = Right InitHelp
    go options ("--force" : rest) = go options{initForce = True} rest
    go options ("--dir" : dir : rest)
        | null dir = Left "option --dir requires a directory"
        | otherwise = go options{initDir = dir} rest
    go _ ["--dir"] = Left "option --dir requires a directory"
    go options (arg : rest)
        | Just dir <- stripPrefix "--dir=" arg = go options{initDir = dir} rest
        | otherwise = Left $ "unknown option `" ++ arg ++ "'"

-- | The @cozyll init --help@ text
initUsage :: String
initUsage =
    unlines
        [ "Usage: cozyll init [--dir DIR] [--force]"
        , ""
        , "Scaffold a working content/ directory from the kit's schema examples."
        , ""
        , "Options:"
        , "  --dir DIR   create the site under DIR (default: the current directory)"
        , "  --force     write the scaffold into a non-empty content/ directory"
        , "  -h, --help  show this help"
        , ""
        , "Run it from the unpacked kit directory (the one with schema/, templates/ and assets/)."
        ]

-- | Prints the scaffold's files and the next step
reportInit :: InitOptions -> [FilePath] -> IO ()
reportInit options files = do
    -- 'initSite' lists the four config files first, then the pages and .gitignore
    let (configs, rest) = splitAt 4 files
    case configs of
        website : others -> putStrLn $ intercalate ", " (display website : map takeFileName others)
        [] -> pure ()
    mapM_ (putStrLn . display) rest
    putStrLn "Next: edit content/website.yaml, then run 'cozyll build'."
  where
    display path
        | initDir options == "." = path
        | otherwise = initDir options </> path

-- | Hakyll's parser, fed with our 'siteConfiguration'
parseOptions :: [String] -> OA.ParserResult Options
parseOptions = OA.execParserPure defaultParserPrefs (defaultParserInfo siteConfiguration)

-- | Dispatches a parsed command, loading content only when the command needs it
run :: [String] -> IO ()
run args =
    case parseOptions args of
        OA.Success options -> dispatch options
        failure -> void $ OA.handleParseResult failure

dispatch :: Options -> IO ()
dispatch options = case optCommand options of
    -- These only touch the generated files, so they must work without content
    -- (and without a valid SITE_ENV)
    Clean -> hakyllWithArgs siteConfiguration options (pure ())
    Check _ -> do
        guardCheck
        hakyllWithArgs siteConfiguration options (pure ())
    command -> do
        env <- parseEnv =<< lookupEnv "SITE_ENV"
        let contentDir = contentDirFor env
            building = startsBuild command
        debugLog options $ "SITE_ENV=" ++ envText env ++ ", content dir: " ++ contentDir
        -- Get and validate website files/config (`website.yaml` is always required)
        ensureWebsiteExists contentDir
        website <- Web.loadWebsite contentDir
        Web.validateSecurityExpiration website
        -- Check content exists
        cfg <- loadSiteConfig env contentDir website
        ensureContentExists cfg
        -- Load the derived ruby index, when the content provides one
        limit <- indexLimitIO
        rubyData <-
            loadIndexFile limit (contentDir </> dataDirName </> indexFileName) >>= either die pure
        let cfg' = cfg{siteRubyData = rubyData}
        -- Only real builds (not watch/server, and not `build --dry-run`) may
        -- clear output or record provenance
        when building $ prepareBuild options env
        if building
            then runBuild options env cfg' website
            else hakyllWithArgs siteConfiguration options (rules cfg' website)

-- | Clears stale output and reports why, when the current env cannot reuse it
prepareBuild :: Options -> Env -> IO ()
prepareBuild options env = do
    start <- decideBuildStart <$> readBuildState <*> pure env <*> siteOutputExists
    let describe Proceed = "proceed"
        describe (Reset message) = "reset (" ++ T.unpack message ++ ")"
    debugLog options $ "build state: " ++ describe start
    applyBuildStart start

-- | The message of an IO error without the attached callstack
showError :: IOException -> String
showError err =
    dropWhileEnd (== '\n')
        . unlines
        . takeWhile (not . isPrefixOf "HasCallStack backtrace:")
        . lines
        $ displayException err

-- | Runs a build and records the provenance once Hakyll succeeds
runBuild :: Options -> Env -> SiteConfig -> Web.Website -> IO ()
runBuild options env cfg website = do
    -- Rule-set errors (invalid front matter, a missing `path`, a group without
    -- an index page) are thrown as IOExceptions while the rules are built.
    -- Print the message on its own instead of letting the RTS append a
    -- callstack to a user-facing error.
    built <- try (hakyllWithExitCodeAndArgs siteConfiguration options (rules cfg website))
    code <- case built of
        Right result -> pure result
        Left err -> do
            -- `displayException` on an IOError includes GHC's callstack; content
            -- authors only need the message. Flush Hakyll's buffered log first
            -- so the error appears after the rules header.
            hFlush stdout
            hPutStrLn stderr $ case fromException err of
                Just ioErr -> showError (ioErr :: IOException)
                Nothing -> displayException (err :: SomeException)
            pure (ExitFailure 1)
    when (code == ExitSuccess) $ do
        builtAt <- getCurrentTime
        writeBuildState
            BuildState
                { buildStateVersion = showVersion version
                , buildStateEnv = env
                , buildStateBuiltAt = builtAt
                , buildStateContentDir = contentDir cfg
                }
    exitWith code

-- | Whether a command produces @_site@ with this environment
startsBuild :: Command -> Bool
startsBuild Rebuild = True
startsBuild (Build RunModeNormal) = True
startsBuild _ = False

{- | Refuses to audit a missing or foreign-env @_site@, and warns when the
output may be stale. @check@ deliberately does not require a valid @SITE_ENV@;
an unknown value only disables the environment comparison.
-}
guardCheck :: IO ()
guardCheck = do
    envValue <- lookupEnv "SITE_ENV"
    built <- siteOutputExists
    unless built $ die "no built site in _site; run 'cozyll build'"
    state <- readBuildState
    let parsedEnv = parseEnvValue envValue
        env = fromRight Prod parsedEnv
    case parsedEnv of
        Left message -> hPutStrLn stderr $ "warning: " ++ message ++ "; skipping the environment comparison"
        Right _ -> pure ()
    case state of
        Nothing ->
            hPutStrLn stderr "warning: no build state found; cannot verify that _site matches the content; run 'cozyll build'"
        Just previous -> do
            when (isRight parsedEnv && buildStateEnv previous /= env)
                $ die
                $ "_site was built with SITE_ENV="
                    ++ envText (buildStateEnv previous)
                    ++ "; run 'cozyll build'"
            newer <- newestContentChange (buildStateContentDir previous) (buildStateBuiltAt previous)
            mapM_ warnNewer newer
  where
    warnNewer file =
        hPutStrLn stderr $
            "warning: _site was built before " ++ file ++ " changed; run 'cozyll build'"

-- | Emits a debug line only when @-v@/@--verbose@ was passed

-- | Emits a debug line only when @-v@/@--verbose@ was passed
debugLog :: Options -> String -> IO ()
debugLog options message =
    when (verbosity options) $ do
        logger <- Logger.new Logger.Debug
        Logger.debug logger message
        Logger.flush logger

{- | Throws before @website.yaml@ is read when the site's entry point is missing

A first build in an empty directory would otherwise fail with only
@content/website.yaml not found@, hiding the rest of the required tree.
-}
ensureWebsiteExists :: FilePath -> IO ()
ensureWebsiteExists contentDir = do
    let website = contentDir </> "website.yaml"
    present <- doesFileExist website
    unless present
        $ die
        $ website
            ++ " not found.\n\nA Cozyll site needs, under "
            ++ contentDir
            ++ "/:\n"
            ++ unlines (map (\(path, hint) -> "  " ++ pad path ++ hint) requiredTree)
            ++ "\nRun 'cozyll init' to create these, or see docs/authoring.md (the kit ships it)."

-- | The files a site needs, relative to the content directory, with a hint for each
requiredTree :: [(FilePath, String)]
requiredTree =
    [ ("website.yaml", "site identity and output switches  (schema/example.website.yaml)")
    , ("socials.yaml", "your accounts                      (schema/example.socials.yaml)")
    , ("authors.yaml", "author map, one siteDefault: true  (schema/example.authors.yaml)")
    , ("localization.yaml", "UI strings per language            (schema/example.localization.yaml)")
    , ("writings/", "pages and posts (markdown)")
    ]

-- | Pads a file name so every hint in 'requiredTree' lines up
pad :: FilePath -> String
pad path = path ++ replicate (max 0 (19 - length path)) ' '

{- | Throws if the content repo is missing, or lacks a file the site needs

(Hakyll would otherwise build whatever it finds, possibly silently leaving out missing pages)
-}
ensureContentExists :: SiteConfig -> IO ()
ensureContentExists cfg = do
    present <- doesDirectoryExist $ contentDir cfg
    unless present
        $ die
        $ contentDir cfg ++ "/ not found"
    missing <- filterM (fmap not . doesFileExist) (requiredContent cfg)
    unless (null missing)
        $ die
        $ "Missing required content:\n"
            ++ unlines ["  " ++ path ++ "  " ++ hintFor path | path <- missing]
  where
    hintFor path = fromMaybe "" $ lookup (takeFileName path) requiredTree

-- | Builds the site configuration from @website.yaml@, with env variables overrides.
loadSiteConfig :: Env -> FilePath -> Web.Website -> IO SiteConfig
loadSiteConfig env contentDir website = do
    let site = Web.websiteSite website
    title <- override "SITE_TITLE" (Web.siteTitle site)
    description <- override "SITE_DESCRIPTION" (Web.siteDescription site)
    year <- override "SITE_COPYRIGHT_YEAR" (Web.siteCopyrightYear site)
    domain <- override "SITE_DOMAIN" (Web.siteDomain site)
    mathjax <- override "MATHJAX_VERSION" (Web.mathjaxVersion (Web.websiteMathjax website))
    highlight <- highlightStyleFromEnv (Web.websiteHighlight website)
    contentTemplates <- discoverContentTemplateNames (contentDir </> "templates")
    authors <- Author.loadAuthors contentDir
    defaultAuthor' <- either (die . unlines) pure (Author.defaultAuthor authors)
    brand <- resolveBrand contentDir (Web.siteLogo site)
    today <- utctDay <$> getCurrentTime
    let (currentYearInteger, _, _) = toGregorian today
        currentYear = fromIntegral currentYearInteger
        logo = brandLogo <$> brand
    pure
        SiteConfig
            { siteTitle = title
            , siteDescription = description
            , siteCopyrightYear = year
            , siteCurrentYear = currentYear
            , siteDomain = domain
            , siteLanguage = fromMaybe defaultLanguage (Web.siteLanguage site)
            , siteAlternateNames = Web.siteAlternateNames site
            , siteLogo = logo
            , siteLogoConfigured = Web.siteLogo site
            , siteBrand = brand
            , siteAuthors = authors
            , siteDefaultAuthor = defaultAuthor'
            , mathjaxVersion = mathjax
            , highlightStyle = highlight
            , contentDir = contentDir
            , assetsDir = "assets" -- TODO
            , templatesDir = "templates" -- TODO
            , contentTemplatesDir = contentDir </> "templates"
            , contentCssDir = contentDir </> "css"
            , contentTemplateNames = contentTemplates
            , siteEnv = env
            , siteRubyData = Nothing
            , siteJaRubyCheck = Web.websiteJaRubyCheck website
            }
  where
    override :: (Read a) => String -> a -> IO a
    override var fallback = fromMaybe fallback . (>>= readMaybe) <$> lookupEnv var

    -- Unlike 'override', unknown values fail (matching the strict @website.yaml@ parsing)
    highlightStyleFromEnv :: Web.Highlight -> IO Web.HighlightStyle
    highlightStyleFromEnv section = do
        value <- lookupEnv "HIGHLIGHT_STYLE"
        case value of
            Nothing -> pure (Web.highlightStyle section)
            Just name -> maybe (die $ "unknown HIGHLIGHT_STYLE \"" ++ name ++ "\"") pure (Web.parseHighlightStyle name)

{- | Parses @SITE_ENV@ (@dev@, @example@, or @prod@). Unset defaults to 'Prod'; any
other value fails the build.
-}
parseEnv :: Maybe String -> IO Env
parseEnv = either die pure . parseEnvValue

{- | Pure @SITE_ENV@ parser. Unset is 'Prod'; unknown values are reported as a
'Left' so @check@ can warn and continue where a build would fail.
-}
parseEnvValue :: Maybe String -> Either String Env
parseEnvValue Nothing = Right Prod
parseEnvValue (Just "prod") = Right Prod
parseEnvValue (Just "dev") = Right Dev
parseEnvValue (Just "example") = Right Example
parseEnvValue (Just other) = Left $ "unknown SITE_ENV \"" ++ other ++ "\" (expected prod, dev, or example)"

-- | The content directory an environment builds (@example@ builds the example content)
contentDirFor :: Env -> FilePath
contentDirFor Example = "example-content"
contentDirFor _ = "content"
