{- | Small helpers that keep the specs short and readable: fixture values, front
matter, assertions and file edits.
-}
module Cozyll.TestUtils (
    Fields,
    render,
    one,
    set,
    without,
    day,
    mkAuthor,
    testConfig,
    metadata,
    metadataJson,
    metadataFromYaml,
    parseFields,
    parseListFields,
    siteYaml,
    assertContains,
    assertNotContains,
    assertFileContains,
    assertFileNotContains,
    assertFails,
    assertFailsWith,
    replaceInFile,
) where

import Cozyll.Config (Env (Dev), SiteConfig (..))
import Cozyll.Domain.Author (Author (..), AuthorType (..))
import Cozyll.Domain.Language (defaultLanguage)
import Cozyll.Domain.Website (CheckMode (CheckError), HighlightStyle (Pygments))
import Cozyll.Yaml (decodeYaml)
import Data.Aeson (Value (String))
import Data.Aeson.Key qualified as AesonKey
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Bifunctor (bimap, first)
import Data.ByteString qualified as BS
import Data.List (isInfixOf)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding (encodeUtf8)
import Data.Time (Day, addUTCTime, fromGregorian)
import Hakyll (Metadata)
import System.Directory (getModificationTime, setModificationTime)
import Test.Tasty.HUnit (Assertion, assertBool, assertFailure)

{- | Key/value pairs for building YAML (project files, post front matter).

Start from a valid fixture and change one thing per test with 'set' and 'without'.
-}
type Fields = [(String, String)]

-- | The fields as YAML text, one @key: value@ per line
render :: Fields -> String
render fields = unlines [key ++ ": " ++ value | (key, value) <- fields]

-- | The fields as a single-element YAML list (for the list parsers)
one :: Fields -> String
one [] = "- {}"
one ((key, value) : rest) =
    "- " ++ key ++ ": " ++ value ++ concat ["\n  " ++ k ++ ": " ++ v | (k, v) <- rest]

-- | Replaces a field's value, or adds the field
set :: String -> String -> Fields -> Fields
set key value fields
    | key `elem` map fst fields = [(k, if k == key then value else v) | (k, v) <- fields]
    | otherwise = fields ++ [(key, value)]

-- | Drops fields by name
without :: [String] -> Fields -> Fields
without keys = filter ((`notElem` keys) . fst)

-- | A date from year, month and day
day :: Integer -> Int -> Int -> Day
day = fromGregorian

-- | A minimal site-default author for fixtures
mkAuthor :: String -> Author
mkAuthor name =
    Author
        { authorId = "example"
        , authorName = name
        , authorType = Person
        , authorSiteDefault = True
        , authorDisplayName = Nothing
        , authorDescription = Nothing
        , authorProfileImage = Nothing
        , authorLinks = []
        , authorAddCopyrightNotice = False
        , authorExtra = []
        , authorRaw = KeyMap.empty
        }

{- | A complete 'SiteConfig' for specs: the values a test does not override do not
matter, but they must be the same everywhere.

'siteCurrentYear' is pinned so the fixture's output (and the golden files) do not
change every January.
-}
testConfig :: SiteConfig
testConfig =
    SiteConfig
        { siteTitle = "site"
        , siteDescription = ""
        , siteCopyrightYear = 0
        , siteCurrentYear = 2021
        , siteDomain = "example.com"
        , siteLanguage = defaultLanguage
        , siteAlternateNames = []
        , siteLogo = Nothing
        , siteLogoConfigured = Nothing
        , siteBrand = Nothing
        , siteAuthors = [mkAuthor ""]
        , siteDefaultAuthor = mkAuthor ""
        , mathjaxVersion = ""
        , highlightStyle = Pygments
        , contentDir = "content"
        , assetsDir = "assets"
        , templatesDir = "templates"
        , contentTemplatesDir = "content/templates"
        , contentCssDir = "content/css"
        , contentTemplateNames = []
        , siteEnv = Dev
        , siteRubyData = Nothing
        , siteJaRubyCheck = CheckError
        }

-- | Front matter with string values, as Hakyll stores it
metadata :: [(Text, Text)] -> Metadata
metadata = KeyMap.fromList . map (bimap AesonKey.fromText String)

-- | Front matter with typed values, as Hakyll stores it
metadataJson :: [(Text, Value)] -> Metadata
metadataJson = KeyMap.fromList . map (first AesonKey.fromText)

-- | Parses a front-matter YAML fragment into the 'Metadata' the contexts read
metadataFromYaml :: String -> Metadata
metadataFromYaml yaml = case (decodeYaml yaml :: Either [String] Metadata) of
    Right parsed -> parsed
    Left problems -> error (unlines problems)

-- | Parses rendered fields as a YAML document
parseFields :: (String -> Either [String] a) -> Fields -> Either [String] a
parseFields parse = parse . render

-- | Parses fields as a single-element YAML list
parseListFields :: (String -> Either [String] a) -> Fields -> Either [String] a
parseListFields parse = parse . one

{- | A @site:@ block with the four keys the @Site@ parser requires, plus @extra@

The preamble's values are placeholders: the specs that use it only assert on the
keys they add.
-}
siteYaml :: [String] -> String
siteYaml extra =
    unlines
        [ "title: Example"
        , "description: An example site"
        , "copyrightYear: 2020"
        , "domain: example.com"
        ]
        ++ unlines extra

-- | Asserts that a string occurs in another, naming the needle on failure
assertContains :: String -> String -> Assertion
assertContains needle haystack =
    assertBool ("expected " ++ show needle ++ " in " ++ haystack) (needle `isInfixOf` haystack)

-- | Asserts that a string does not occur in another
assertNotContains :: String -> String -> Assertion
assertNotContains needle haystack =
    assertBool ("did not expect " ++ show needle ++ " in " ++ haystack) (not (needle `isInfixOf` haystack))

{- | Asserts that a UTF-8 file contains a string, naming the path on failure

The file is read as bytes and the needle is encoded as UTF-8, so non-ASCII
needles work regardless of the locale.
-}
assertFileContains :: FilePath -> String -> Assertion
assertFileContains path needle = do
    contents <- BS.readFile path
    assertBool
        ("expected " ++ path ++ " to contain " ++ show needle)
        (encodeUtf8 (T.pack needle) `BS.isInfixOf` contents)

-- | Asserts that a UTF-8 file does not contain a string
assertFileNotContains :: FilePath -> String -> Assertion
assertFileNotContains path needle = do
    contents <- BS.readFile path
    assertBool
        ("expected " ++ path ++ " not to contain " ++ show needle)
        (not (encodeUtf8 (T.pack needle) `BS.isInfixOf` contents))

-- | Asserts that a parse or validation failed
assertFails :: (Show e) => Either e a -> Assertion
assertFails = \case
    Left _ -> pure ()
    Right _ -> assertFailure "expected parsing to fail"

-- | Asserts that a parse failed with a problem mentioning @text@
assertFailsWith :: String -> Either [String] a -> Assertion
assertFailsWith text = \case
    Left problems ->
        assertBool
            ("expected a problem mentioning " ++ show text ++ ", got " ++ show problems)
            (any (text `isInfixOf`) problems)
    Right _ -> assertFailure "expected parsing to fail"

{- | Replaces the first occurrence of @needle@ in a file, then pushes its mtime
past the filesystem's resolution so the next build sees the edit.

The files are read and written as raw bytes and the needle is encoded as UTF-8,
so non-ASCII values can be edited too.
-}
replaceInFile :: FilePath -> String -> String -> IO ()
replaceInFile path needle replacement = do
    let needle' = encodeUtf8 (T.pack needle)
        replacement' = encodeUtf8 (T.pack replacement)
    bytes <- BS.readFile path
    let (before, rest) = BS.breakSubstring needle' bytes
    if BS.null rest
        then assertFailure ("expected " ++ path ++ " to contain \"" ++ needle ++ "\"")
        else do
            BS.writeFile path (before <> replacement' <> BS.drop (BS.length needle') rest)
            modified <- getModificationTime path
            setModificationTime path (addUTCTime 2 modified)
