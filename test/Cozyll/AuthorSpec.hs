-- | Tests for the authors.yaml parser and author resolution
module Cozyll.AuthorSpec (tests) where

import Cozyll.Config (Env (Dev), SiteConfig (..))
import Cozyll.Context.Author (authoredBy, copyrightYears, resolveAuthors)
import Cozyll.Domain.Author (Author (..), AuthorType (..), authorUrlPath, defaultAuthor, parseAuthorsYaml)
import Cozyll.Domain.Website (CheckMode (..), HighlightStyle (Pygments))
import Cozyll.Metadata qualified as Meta
import Data.Aeson (Value (..), toJSON)
import Data.Aeson.Key qualified as AesonKey
import Data.Aeson.KeyMap qualified as KeyMap
import Data.List (isInfixOf)
import Data.Text (Text)
import Hakyll (Metadata)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, assertFailure, testCase, (@?=))

tests :: TestTree
tests =
    testGroup
        "Author"
        [ parseTests
        , defaultAuthorTests
        , authorUrlPathTests
        , resolveAuthorsTests
        , lookupKeyListTests
        , copyrightYearsTests
        , postCopyrightTests
        , authoredByTests
        ]

parseTests :: TestTree
parseTests =
    testGroup
        "parseAuthorsYaml"
        [ testCase "parses a full author" $ do
            author <- oneAuthor happyAuthor
            authorId author @?= "example"
            authorName author @?= "Example Author"
            authorType author @?= Person
            authorSiteDefault author @?= True
            authorDisplayName author @?= Just "Example"
            authorDescription author @?= Just "A bio"
            authorProfileImage author @?= Just "images/a.png"
            authorLinks author @?= ["https://example.com"]
            authorAddCopyrightNotice author @?= True
            authorExtra author @?= [("jobTitle", "Engineer")]
        , testCase "defaults the optional fields" $ do
            author <- oneAuthor "example:\n  name: Example Author\n  siteDefault: true\n"
            authorType author @?= Person
            authorDisplayName author @?= Nothing
            authorDescription author @?= Nothing
            authorProfileImage author @?= Nothing
            authorLinks author @?= []
            authorAddCopyrightNotice author @?= False
            authorExtra author @?= []
        , testCase "parses an organization" $ do
            author <- oneAuthor "example:\n  name: Example Labs\n  type: organization\n  siteDefault: true\n"
            authorType author @?= Organization
        , testCase "rejects a missing name" $
            failsWith "name: missing" "example:\n  siteDefault: true\n"
        , testCase "rejects an empty name" $
            failsWith "name: empty" "example:\n  name: \"\"\n  siteDefault: true\n"
        , testCase "rejects an unknown type" $
            failsWith "type: unknown" "example:\n  name: A\n  type: robot\n  siteDefault: true\n"
        , testCase "rejects an empty profileImage" $
            failsWith "profileImage: empty" "example:\n  name: A\n  siteDefault: true\n  profileImage: \"\"\n"
        , testCase "rejects a non-string link" $
            failsWith "links[0]: expected a non-empty string" "example:\n  name: A\n  siteDefault: true\n  links:\n    - 42\n"
        , testCase "rejects an uppercase id" $
            failsWith "invalid id" "Foo:\n  name: A\n  siteDefault: true\n"
        , testCase "rejects an id with an underscore" $
            failsWith "invalid id" "a_b:\n  name: A\n  siteDefault: true\n"
        , testCase "rejects an id starting with a hyphen" $
            failsWith "invalid id" "-a:\n  name: A\n  siteDefault: true\n"
        , testCase "rejects a non-map document" $
            failsWith "expected a map" "- name: A\n"
        , testCase "rejects an empty map" $
            failsWith "non-empty map" "{}\n"
        , testCase "reports every problem at once" $
            case parseAuthorsYaml "example:\n  type: robot\n  links:\n    - 42\n" of
                Left problems -> do
                    assertBool "type problem" (any ("type: unknown" `isInfixOf`) problems)
                    assertBool "name problem" (any ("name: missing" `isInfixOf`) problems)
                    assertBool "links problem" (any ("links[0]:" `isInfixOf`) problems)
                Right _ -> assertFailure "expected parsing to fail"
        ]

defaultAuthorTests :: TestTree
defaultAuthorTests =
    testGroup
        "defaultAuthor"
        [ testCase "returns the site-default author" $
            case parseAuthorsYaml "a:\n  name: A\n  siteDefault: true\nb:\n  name: B\n" of
                Left problems -> assertFailure (unlines problems)
                Right [] -> assertFailure "Expected non-empty list of authors, but got empty list"
                Right authors@(author : _) -> defaultAuthor authors @?= Right author
        , testCase "rejects zero defaults" $
            failsWith "found none" "a:\n  name: A\n"
        , testCase "rejects two defaults" $
            failsWith "found 2" "a:\n  name: A\n  siteDefault: true\nb:\n  name: B\n  siteDefault: true\n"
        ]

authorUrlPathTests :: TestTree
authorUrlPathTests =
    testGroup
        "authorUrlPath"
        [ testCase "is the author page path" $ do
            author <- oneAuthor happyAuthor
            authorUrlPath author @?= "/authors/example"
        ]

-- | Parses a single-author document and returns the author
oneAuthor :: String -> IO Author
oneAuthor yaml = case parseAuthorsYaml yaml of
    Left problems -> assertFailure (unlines problems)
    Right [author] -> pure author
    Right authors -> assertFailure ("expected one author, got " ++ show (length authors))

-- | Asserts the parse fails with a problem mentioning the given text
failsWith :: String -> String -> IO ()
failsWith text yaml = case parseAuthorsYaml yaml of
    Left problems ->
        assertBool
            ("expected a problem mentioning " ++ show text ++ ", got " ++ show problems)
            (any (text `isInfixOf`) problems)
    Right _ -> assertFailure "expected parsing to fail"

happyAuthor :: String
happyAuthor =
    unlines
        [ "example:"
        , "  name: Example Author"
        , "  type: person"
        , "  siteDefault: true"
        , "  displayName: Example"
        , "  description: A bio"
        , "  profileImage: images/a.png"
        , "  links:"
        , "    - https://example.com"
        , "  addCopyrightNotice: true"
        , "  jobTitle: Engineer"
        ]

resolveAuthorsTests :: TestTree
resolveAuthorsTests =
    testGroup
        "resolveAuthors"
        [ testCase "resolves a list of ids in order" $
            map authorId (resolveAuthors cfg (metadataOf [("author", stringList ["example", "example-org"])]))
                @?= ["example", "example-org"]
        , testCase "resolves a scalar id" $
            map authorId (resolveAuthors cfg (metadataOf [("author", String "example-org")]))
                @?= ["example-org"]
        , testCase "falls back to the site-default author" $
            map authorId (resolveAuthors cfg (metadataOf []))
                @?= ["example"]
        , testCase "skips unknown ids" $
            map authorId (resolveAuthors cfg (metadataOf [("author", stringList ["example", "nobody"])]))
                @?= ["example"]
        , testCase "deduplicates repeated ids" $
            map authorId (resolveAuthors cfg (metadataOf [("author", stringList ["example", "example"])]))
                @?= ["example"]
        ]

lookupKeyListTests :: TestTree
lookupKeyListTests =
    testGroup
        "lookupKeyList"
        [ testCase "reads a list" $
            Meta.lookupKeyList Meta.Author (metadataOf [("author", stringList ["a", "b"])]) @?= Just ["a", "b"]
        , testCase "reads a scalar as a single-element list" $
            Meta.lookupKeyList Meta.Author (metadataOf [("author", String "a")]) @?= Just ["a"]
        , testCase "is Nothing when absent" $
            Meta.lookupKeyList Meta.Author (metadataOf []) @?= Nothing
        ]

-- | A list of strings as a JSON array
stringList :: [String] -> Value
stringList = toJSON

copyrightYearsTests :: TestTree
copyrightYearsTests =
    testGroup
        "copyrightYears"
        [ testCase "is a single year without lastModifiedAt" $
            copyrightYears (metadataOf [("date", String "2024-02-20")]) @?= "2024"
        , testCase "is a single year when lastModifiedAt matches" $
            copyrightYears (metadataOf [("date", String "2024-02-20"), ("lastModifiedAt", String "2024-02-20")]) @?= "2024"
        , testCase "is a range when lastModifiedAt differs" $
            copyrightYears (metadataOf [("date", String "2024-02-20"), ("lastModifiedAt", String "2026-03-01")]) @?= "2024–2026"
        , testCase "is empty without a date" $
            copyrightYears (metadataOf []) @?= ""
        ]

postCopyrightTests :: TestTree
postCopyrightTests =
    testGroup
        "postCopyright"
        [ testCase "names only the opted-in authors" $
            map authorName (filter authorAddCopyrightNotice (resolveAuthors cfg (metadataOf [("author", stringList ["example", "example-org"])])))
                @?= ["Example Author"]
        , testCase "is false when no author opts in" $
            any authorAddCopyrightNotice (resolveAuthors cfg (metadataOf [("author", String "example-org")]))
                @?= False
        ]

authoredByTests :: TestTree
authoredByTests =
    testGroup
        "authoredBy"
        [ testCase "accepts an explicitly listed author" $
            authoredBy cfg exampleAuthor (metadataOf [("author", String "example")])
                @?= True
        , testCase "accepts any author of a multi-author post" $
            authoredBy cfg orgAuthor (metadataOf [("author", stringList ["example", "example-org"])])
                @?= True
        , testCase "assigns a post without authors to the site default" $
            authoredBy cfg exampleAuthor (metadataOf []) @?= True
        , testCase "does not assign a post without authors to other authors" $
            authoredBy cfg orgAuthor (metadataOf []) @?= False
        , testCase "rejects an author the post does not list" $
            authoredBy cfg orgAuthor (metadataOf [("author", String "example")])
                @?= False
        ]

-- | Front matter with string values, as Hakyll stores it
metadataOf :: [(Text, Value)] -> Metadata
metadataOf = KeyMap.fromList . map (\(key, value) -> (AesonKey.fromText key, value))

-- | A 'SiteConfig' with two authors (example is the default)
cfg :: SiteConfig
cfg =
    SiteConfig
        { siteTitle = "site"
        , siteDescription = ""
        , siteCopyrightYear = 0
        , siteCurrentYear = 2021
        , siteDomain = "example.com"
        , siteAlternateNames = []
        , siteLogo = Nothing
        , siteAuthors = [exampleAuthor, orgAuthor]
        , siteDefaultAuthor = exampleAuthor
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
        , siteRubyCheck = CheckError
        }

exampleAuthor :: Author
exampleAuthor = (author' "example" "Example Author" True){authorAddCopyrightNotice = True}

orgAuthor :: Author
orgAuthor = author' "example-org" "Example Labs" False

author' :: String -> String -> Bool -> Author
author' id' name siteDefault =
    Author
        { authorId = id'
        , authorName = name
        , authorType = Person
        , authorSiteDefault = siteDefault
        , authorDisplayName = Nothing
        , authorDescription = Nothing
        , authorProfileImage = Nothing
        , authorLinks = []
        , authorAddCopyrightNotice = False
        , authorExtra = []
        , authorRaw = KeyMap.empty
        }
