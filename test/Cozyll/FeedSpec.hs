-- | Tests for the feed helpers and the site-wide feed
module Cozyll.FeedSpec (tests) where

import Control.Exception (bracket)
import Cozyll.Domain.Feed (absoluteUrl, missingIndexPageMessage)
import Cozyll.Fixture (buildFixture, copyTree)
import Data.Function (on)
import Data.List (intercalate, isInfixOf, isPrefixOf, sort, sortBy)
import Data.Text qualified as T
import Data.Text.IO qualified as TIO
import System.Directory (getCurrentDirectory, removePathForcibly)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))
import Test.Tasty.QuickCheck (testProperty)

-- | The feed tests
tests :: TestTree
tests =
    testGroup
        "Feeds"
        [ absoluteUrlTests
        , missingIndexPageMessageTests
        , siteFeedTests
        ]

absoluteUrlTests :: TestTree
absoluteUrlTests =
    testGroup
        "absoluteUrl"
        [ testCase "makes a root-relative URL absolute" $
            absoluteUrl root "/contact" @?= "https://example.org/contact"
        , testCase "keeps an absolute URL" $
            absoluteUrl root "https://other.net/a" @?= "https://other.net/a"
        , testCase "keeps a protocol-relative URL" $
            absoluteUrl root "//cdn.net/a.js" @?= "//cdn.net/a.js"
        , testCase "keeps an anchor, a mailto link and a relative path" $
            map (absoluteUrl root) ["#top", "mailto:me@example.org", "images/a.png"]
                @?= ["#top", "mailto:me@example.org", "images/a.png"]
        , testProperty "is idempotent" $ \url ->
            absoluteUrl root (absoluteUrl root url) == absoluteUrl root url
        ]
  where
    root = "https://example.org"

missingIndexPageMessageTests :: TestTree
missingIndexPageMessageTests =
    testGroup
        "missingIndexPageMessage"
        [ testCase "explains the group convention and the page to create" $
            missingIndexPageMessage "content" "curiosities"
                @?= intercalate
                    "\n"
                    [ "no index page for the group \"curiosities\": create content/writings/curiosities.md with"
                    , "  index: true"
                    , "  group: curiosities"
                    , "  path: /curiosities"
                    , "(see docs/authoring.md, \"Groups\")"
                    ]
        ]

siteFeedTests :: TestTree
siteFeedTests =
    testGroup
        "site feed"
        [ testCase "aggregates every group's posts newest first, without the showcase group" $ do
            root <- getCurrentDirectory
            bracket (buildFixture root (root </> "example-content")) (removePathForcibly . fst) $ \(_, site) -> do
                siteEntries <- readEntries (site </> "atom.xml")
                groupEntries <- concat <$> mapM (readEntries . (site </>)) groupFeeds
                -- The site feed is capped by `feed.size` (20 in the example content)
                let expected = take 20 (sortBy (flip compare `on` entryDate) groupEntries)
                length siteEntries @?= length expected
                map entryDate siteEntries @?= sortBy (flip compare) (map entryDate siteEntries)
                map entryTitle siteEntries @?= map entryTitle expected
                assertBool "no showcase entries" $
                    not (any (("/showcase" `isInfixOf`) . entryLink) siteEntries)
                html <- readFile (site </> "index.html")
                let firstFeed = dropWhile (== ' ') $ head [line | line <- lines html, "rel=\"alternate\"" `isInfixOf` line]
                assertBool "the site feed is the first feed link" $
                    "<link rel=\"alternate\" type=\"application/atom+xml\" title=\"Example\" href=\"./atom.xml\" />"
                        `isPrefixOf` firstFeed
        , testCase "respects feed.size" $ do
            root <- getCurrentDirectory
            withSystemTempDirectory "cozyll-feed" $ \content -> do
                copyTree (root </> "example-content") content
                setFeedSize content "6"
                bracket (buildFixture root content) (removePathForcibly . fst) $ \(_, site) -> do
                    siteEntries <- readEntries (site </> "atom.xml")
                    length siteEntries @?= 6
                    map entryDate siteEntries @?= sortBy (flip compare) (map entryDate siteEntries)
        ]

-- | The group feeds built from @example-content@
groupFeeds :: [FilePath]
groupFeeds = ["code/atom.xml", "elements/atom.xml", "languages/atom.xml", "prose/atom.xml", "tables/atom.xml"]

-- | Sets @feed.size@ in a content directory's @website.yaml@
setFeedSize :: FilePath -> String -> IO ()
setFeedSize content size = do
    let file = content </> "website.yaml"
    yaml <- TIO.readFile file
    TIO.writeFile file $
        T.unlines
            [ if "  size:" `T.isPrefixOf` line then "  size: " <> T.pack size else line
            | line <- T.lines yaml
            ]

-- | One @<entry>@ of an Atom feed, as the tests read it
data Entry = Entry
    { entryTitle :: String
    , entryDate :: String
    , entryLink :: String
    }
    deriving (Eq, Show)

-- | Reads the entries of a feed, in file order
readEntries :: FilePath -> IO [Entry]
readEntries file = entries <$> readFile file

-- | Parses the @<entry>@ blocks of an Atom feed
entries :: String -> [Entry]
entries = go . lines
  where
    go [] = []
    go ("<entry>" : rest) =
        let (body, remaining) = break (== "</entry>") rest
         in parseEntry body : go remaining
    go (_ : rest) = go rest

parseEntry :: [String] -> Entry
parseEntry body =
    Entry
        { entryTitle = value "    <title><![CDATA[" "]]></title>" body
        , entryDate = value "    <published>" "</published>" body
        , entryLink = value "    <link href=\"" "\" />" body
        }

-- | The value of the first line starting with @prefix@, minus @suffix@
value :: String -> String -> [String] -> String
value prefix suffix body =
    case [drop (length prefix) line | line <- body, prefix `isPrefixOf` line] of
        line : _ -> take (length line - length suffix) line
        [] -> ""
