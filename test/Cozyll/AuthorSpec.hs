-- | Tests for the authors.yaml parser
module Cozyll.AuthorSpec (tests) where

import Cozyll.Domain.Author (Author (..), AuthorType (..), authorUrlPath, defaultAuthor, parseAuthorsYaml)
import Data.List (isInfixOf)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, assertFailure, testCase, (@?=))

tests :: TestTree
tests =
    testGroup
        "Author"
        [ parseTests
        , defaultAuthorTests
        , authorUrlPathTests
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
                Right authors -> defaultAuthor authors @?= Right (head authors)
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
            authorUrlPath author @?= "/authors/example/"
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
