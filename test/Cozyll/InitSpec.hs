-- | Tests for the @cozyll init@ scaffold
module Cozyll.InitSpec (tests) where

import Control.Monad (forM_)
import Cozyll.Domain.Author qualified as Author
import Cozyll.Domain.Social qualified as Social
import Cozyll.Domain.Website qualified as Web
import Cozyll.Init (InitOptions (..), defaultInitOptions, initSite)
import Cozyll.Yaml (decodeYaml)
import Data.Aeson (Value (..))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.List (isInfixOf)
import System.Directory (copyFile, createDirectoryIfMissing, doesFileExist, listDirectory)
import System.FilePath.Posix ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, assertFailure, testCase, (@?=))

-- | The files @cozyll init@ promises to create, relative to the target directory
scaffoldPaths :: [FilePath]
scaffoldPaths =
    [ "content" </> "website.yaml"
    , "content" </> "socials.yaml"
    , "content" </> "authors.yaml"
    , "content" </> "localization.yaml"
    , "content" </> "writings" </> "home.md"
    , "content" </> "writings" </> "contact.md"
    , "content" </> ".gitignore"
    ]

-- | The init tests
tests :: TestTree
tests =
    testGroup
        "Init"
        [ testGroup
            "scaffold"
            [ testCase "creates every expected file" $
                withKit $ \temp -> do
                    result <- scaffold temp False
                    case result of
                        Left problem -> assertFailure problem
                        Right files -> do
                            files @?= scaffoldPaths
                            forM_ scaffoldPaths $ \path -> do
                                exists <- doesFileExist (temp </> path)
                                assertBool (path ++ " should exist") exists
            , testCase "refuses a non-empty content/ without --force and leaves it untouched" $
                withKit $ \temp -> do
                    _ <- scaffold temp False
                    let website = temp </> "content" </> "website.yaml"
                        marker = "marker: true\n"
                    writeFile website marker
                    result <- scaffold temp False
                    case result of
                        Left problem -> assertBool "names --force" ("--force" `isInfixOf` problem)
                        Right _ -> assertFailure "init should refuse a non-empty content/"
                    after <- readFile website
                    after @?= marker
            , testCase "overwrites its files with --force and keeps unrelated files" $
                withKit $ \temp -> do
                    _ <- scaffold temp False
                    let content = temp </> "content"
                        unrelated = content </> "notes.txt"
                        website = content </> "website.yaml"
                    writeFile website "marker: true\n"
                    writeFile unrelated "keep me\n"
                    result <- scaffold temp True
                    case result of
                        Left problem -> assertFailure problem
                        Right _ -> pure ()
                    overwritten <- readFile website
                    assertBool "overwrites the scaffold files" (not ("marker" `isInfixOf` overwritten))
                    kept <- doesFileExist unrelated
                    assertBool "keeps files it does not own" kept
            , testCase "fails clearly when schema/ is missing" $
                withSystemTempDirectory "cozyll-init" $ \temp -> do
                    result <- initSite defaultInitOptions{initDir = temp, initSchemaDir = temp </> "schema"}
                    case result of
                        Left problem -> assertBool "names schema/" ("schema" `isInfixOf` problem)
                        Right _ -> assertFailure "init should fail without schema/"
            ]
        , testGroup
            "generated files"
            [ testCase "website.yaml loads with the domain's parser" $
                withKit $ \temp -> do
                    _ <- scaffold temp False
                    website <- Web.loadWebsite (temp </> "content")
                    Web.siteTitle (Web.websiteSite website) @?= "My site"
                    Web.siteDomain (Web.websiteSite website) @?= "example.com"
                    Web.contactPage (Web.websiteContact website) @?= "/contact"
            , testCase "authors.yaml has exactly one site-default author" $
                withKit $ \temp -> do
                    _ <- scaffold temp False
                    authors <- Author.loadAuthors (temp </> "content")
                    map Author.authorSiteDefault authors @?= [True]
                    map Author.authorName authors @?= ["Your Name"]
            , testCase "socials.yaml parses as an empty list" $
                withKit $ \temp -> do
                    _ <- scaffold temp False
                    text <- readFile (temp </> "content" </> "socials.yaml")
                    case Social.parseSocialsYaml text of
                        Left problems -> assertFailure $ unwords problems
                        Right socials -> socials @?= ([] :: [Social.Social])
            , testCase "localization.yaml has every consumed id and the og locale" $
                withKit $ \temp -> do
                    _ <- scaffold temp False
                    text <- readFile (temp </> "content" </> "localization.yaml")
                    case decodeYaml text :: Either [String] Value of
                        Left problems -> assertFailure $ unwords problems
                        Right (Object top) ->
                            forM_
                                ["aside.controls", "post.updated", "project.started", "project.finished", "_ogLocaleDefaultRegion"]
                                $ \key ->
                                    assertBool (key ++ " missing") (KeyMap.member (Key.fromString key) top)
                        Right _ -> assertFailure "localization.yaml should be a map"
            , testCase "home.md is the home page at /" $
                withKit $ \temp -> do
                    _ <- scaffold temp False
                    text <- readFile (temp </> "content" </> "writings" </> "home.md")
                    assertBool "has path: /" ("path: \"/\"" `isInfixOf` text)
                    assertBool "has home: true" ("home: true" `isInfixOf` text)
            ]
        ]

-- | Runs the scaffold against a temp directory holding a copy of the repo's @schema/@
scaffold :: FilePath -> Bool -> IO (Either String [FilePath])
scaffold temp force =
    initSite
        defaultInitOptions
            { initDir = temp
            , initSchemaDir = temp </> "schema"
            , initForce = force
            }

-- | Runs an action in a temp directory with the repo's @schema/@ copied into it
withKit :: (FilePath -> IO a) -> IO a
withKit action = withSystemTempDirectory "cozyll-init" $ \temp -> do
    copySchema (temp </> "schema")
    action temp

-- | Copies @schema/@ into a test temp directory
copySchema :: FilePath -> IO ()
copySchema destination = do
    createDirectoryIfMissing True destination
    files <- listDirectory "schema"
    forM_ files $ \file -> copyFile ("schema" </> file) (destination </> file)
