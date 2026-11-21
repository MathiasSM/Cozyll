-- | Tests for the authors.yaml parser and author resolution
module Cozyll.AuthorSpec (tests) where

import Cozyll.Config (SiteConfig (..))
import Cozyll.Context.Author (authoredBy, copyrightYears, profileImageUrl, resolveAuthors)
import Cozyll.Domain.Author (Author (..), AuthorType (..), authorUrlPath, decodeAuthorsUtf8, defaultAuthor, parseAuthorsYaml)
import Cozyll.Metadata qualified as Meta
import Cozyll.TestUtils (assertFailsWith, metadataJson, testConfig)
import Data.Aeson (Value (..), toJSON)
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString qualified as BS
import Data.List (isInfixOf, sort)
import Data.Text qualified as T
import Data.Text.Encoding (encodeUtf8)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, assertFailure, testCase, (@?=))

tests :: TestTree
tests =
    testGroup
        "Author"
        [ parseTests
        , decodeTests
        , defaultAuthorTests
        , authorUrlPathTests
        , profileImageUrlTests
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
            assertFailsWith "name: missing" (parseAuthorsYaml "example:\n  siteDefault: true\n")
        , testCase "rejects an empty name" $
            assertFailsWith "name: empty" (parseAuthorsYaml "example:\n  name: \"\"\n  siteDefault: true\n")
        , testCase "rejects an unknown type" $
            assertFailsWith "type: unknown" (parseAuthorsYaml "example:\n  name: A\n  type: robot\n  siteDefault: true\n")
        , testCase "rejects an empty profileImage" $
            assertFailsWith "profileImage: empty" (parseAuthorsYaml "example:\n  name: A\n  siteDefault: true\n  profileImage: \"\"\n")
        , testCase "rejects a non-string link" $
            assertFailsWith "links[0]: expected a non-empty string" (parseAuthorsYaml "example:\n  name: A\n  siteDefault: true\n  links:\n    - 42\n")
        , testCase "rejects an uppercase id" $
            assertFailsWith "invalid id" (parseAuthorsYaml "Foo:\n  name: A\n  siteDefault: true\n")
        , testCase "rejects an id with an underscore" $
            assertFailsWith "invalid id" (parseAuthorsYaml "a_b:\n  name: A\n  siteDefault: true\n")
        , testCase "rejects an id starting with a hyphen" $
            assertFailsWith "invalid id" (parseAuthorsYaml "-a:\n  name: A\n  siteDefault: true\n")
        , testCase "rejects a non-map document" $
            assertFailsWith "expected a map" (parseAuthorsYaml "- name: A\n")
        , testCase "rejects an empty map" $
            assertFailsWith "non-empty map" (parseAuthorsYaml "{}\n")
        , testCase "reports every problem at once" $
            case parseAuthorsYaml "example:\n  type: robot\n  links:\n    - 42\n" of
                Left problems -> do
                    assertBool "type problem" (any ("type: unknown" `isInfixOf`) problems)
                    assertBool "name problem" (any ("name: missing" `isInfixOf`) problems)
                    assertBool "links problem" (any ("links[0]:" `isInfixOf`) problems)
                Right _ -> assertFailure "expected parsing to fail"
        ]

decodeTests :: TestTree
decodeTests =
    testGroup
        "decodeAuthorsUtf8"
        [ testCase "decodes UTF-8 names regardless of the locale" $
            case decodeAuthorsUtf8 (encodeUtf8 (T.pack nonAsciiAuthors)) of
                Left problem -> assertFailure problem
                Right authors -> sort (map authorName authors) @?= sort ["Marta Ibáñez", "山田 太郎"]
        , testCase "rejects invalid UTF-8 bytes" $
            case decodeAuthorsUtf8 ("marta:\n  name: " <> BS.singleton 0xff <> "\n  siteDefault: true\n") of
                Left problem ->
                    assertBool
                        ("expected a problem mentioning UTF-8, got " ++ show problem)
                        ("UTF-8" `isInfixOf` problem)
                Right _ -> assertFailure "expected invalid UTF-8 to fail"
        ]

-- | An @authors.yaml@ with non-ASCII names
nonAsciiAuthors :: String
nonAsciiAuthors =
    unlines
        [ "marta:"
        , "  name: Marta Ibáñez"
        , "  siteDefault: true"
        , "kanji:"
        , "  name: 山田 太郎"
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
            assertFailsWith "found none" (parseAuthorsYaml "a:\n  name: A\n")
        , testCase "rejects two defaults" $
            assertFailsWith "found 2" (parseAuthorsYaml "a:\n  name: A\n  siteDefault: true\nb:\n  name: B\n  siteDefault: true\n")
        ]

authorUrlPathTests :: TestTree
authorUrlPathTests =
    testGroup
        "authorUrlPath"
        [ testCase "is the author page path" $ do
            author <- oneAuthor happyAuthor
            authorUrlPath author @?= "/authors/example"
        ]

profileImageUrlTests :: TestTree
profileImageUrlTests =
    testGroup
        "profileImageUrl"
        [ testCase "makes a site-relative path root-relative" $
            profileImageUrl exampleAuthor{authorProfileImage = Just "images/photos/marta.png"}
                @?= Just "/images/photos/marta.png"
        , testCase "does not double the slash of a root-relative path" $
            profileImageUrl exampleAuthor{authorProfileImage = Just "/images/photos/marta.png"}
                @?= Just "/images/photos/marta.png"
        , testCase "stays Nothing without a profile image" $
            profileImageUrl exampleAuthor @?= Nothing
        ]

-- | Parses a single-author document and returns the author
oneAuthor :: String -> IO Author
oneAuthor yaml = case parseAuthorsYaml yaml of
    Left problems -> assertFailure (unlines problems)
    Right [author] -> pure author
    Right authors -> assertFailure ("expected one author, got " ++ show (length authors))

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
            map authorId (resolveAuthors cfg (metadataJson [("author", stringList ["example", "example-org"])]))
                @?= ["example", "example-org"]
        , testCase "resolves a scalar id" $
            map authorId (resolveAuthors cfg (metadataJson [("author", String "example-org")]))
                @?= ["example-org"]
        , testCase "falls back to the site-default author" $
            map authorId (resolveAuthors cfg (metadataJson []))
                @?= ["example"]
        , testCase "skips unknown ids" $
            map authorId (resolveAuthors cfg (metadataJson [("author", stringList ["example", "nobody"])]))
                @?= ["example"]
        , testCase "deduplicates repeated ids" $
            map authorId (resolveAuthors cfg (metadataJson [("author", stringList ["example", "example"])]))
                @?= ["example"]
        ]

lookupKeyListTests :: TestTree
lookupKeyListTests =
    testGroup
        "lookupKeyList"
        [ testCase "reads a list" $
            Meta.lookupKeyList Meta.Author (metadataJson [("author", stringList ["a", "b"])]) @?= Just ["a", "b"]
        , testCase "reads a scalar as a single-element list" $
            Meta.lookupKeyList Meta.Author (metadataJson [("author", String "a")]) @?= Just ["a"]
        , testCase "is Nothing when absent" $
            Meta.lookupKeyList Meta.Author (metadataJson []) @?= Nothing
        ]

-- | A list of strings as a JSON array
stringList :: [String] -> Value
stringList = toJSON

copyrightYearsTests :: TestTree
copyrightYearsTests =
    testGroup
        "copyrightYears"
        [ testCase "is a single year without lastModifiedAt" $
            copyrightYears (metadataJson [("date", String "2024-02-20")]) @?= "2024"
        , testCase "is a single year when lastModifiedAt matches" $
            copyrightYears (metadataJson [("date", String "2024-02-20"), ("lastModifiedAt", String "2024-02-20")]) @?= "2024"
        , testCase "is a range when lastModifiedAt differs" $
            copyrightYears (metadataJson [("date", String "2024-02-20"), ("lastModifiedAt", String "2026-03-01")]) @?= "2024–2026"
        , testCase "is empty without a date" $
            copyrightYears (metadataJson []) @?= ""
        ]

postCopyrightTests :: TestTree
postCopyrightTests =
    testGroup
        "postCopyright"
        [ testCase "names only the opted-in authors" $
            map authorName (filter authorAddCopyrightNotice (resolveAuthors cfg (metadataJson [("author", stringList ["example", "example-org"])])))
                @?= ["Example Author"]
        , testCase "is false when no author opts in" $
            any authorAddCopyrightNotice (resolveAuthors cfg (metadataJson [("author", String "example-org")]))
                @?= False
        ]

authoredByTests :: TestTree
authoredByTests =
    testGroup
        "authoredBy"
        [ testCase "accepts an explicitly listed author" $
            authoredBy cfg exampleAuthor (metadataJson [("author", String "example")])
                @?= True
        , testCase "accepts any author of a multi-author post" $
            authoredBy cfg orgAuthor (metadataJson [("author", stringList ["example", "example-org"])])
                @?= True
        , testCase "assigns a post without authors to the site default" $
            authoredBy cfg exampleAuthor (metadataJson []) @?= True
        , testCase "does not assign a post without authors to other authors" $
            authoredBy cfg orgAuthor (metadataJson []) @?= False
        , testCase "rejects an author the post does not list" $
            authoredBy cfg orgAuthor (metadataJson [("author", String "example")])
                @?= False
        ]

-- | The shared config with two authors (example is the default)
cfg :: SiteConfig
cfg = testConfig{siteAuthors = [exampleAuthor, orgAuthor], siteDefaultAuthor = exampleAuthor}

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
