{- | Structural microformats2 checks on the freshly built snapshot.

The site's markup is fully explicit (no implied properties), so these
TagSoup checks assert the class structure a microformats2 parser would read:
an @h-entry@ with its properties on a post page, an @h-feed@ of @h-entry@s on
an index, @rel=\"me\"@ social links, and a representative @h-card@.
-}
module Mf2 (mf2Tests) where

import Data.Maybe (fromMaybe)
import System.FilePath ((</>))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))
import Text.HTML.TagSoup (Tag (TagOpen), parseTags)

-- | One structural check per page type, against the freshly built site
mf2Tests :: FilePath -> TestTree
mf2Tests snapshot =
    testGroup
        "microformats2"
        [ testCase "post permalink is a complete h-entry" $ do
            tags <- tagsOf $ snapshot </> "blog" </> "hello" </> "index.html"
            length (withClass "h-entry" tags) @?= 1
            assertBool "has a p-name" $ hasClass "p-name" tags
            assertBool "has a dt-published" $ hasClass "dt-published" tags
            assertBool "has a p-author h-card" $ hasClassAll ["p-author", "h-card"] tags
            assertBool "has an e-content" $ hasClass "e-content" tags
            assertBool "u-url points at the canonical permalink" $
                "https://example.com/blog/hello" `elem` urlHrefs tags
        , testCase "blog index is an h-feed of h-entries" $ do
            tags <- tagsOf $ snapshot </> "blog" </> "index.html"
            length (withClass "h-feed" tags) @?= 1
            let entries = withClass "h-entry" tags
            assertBool "feed has more than one entry" (length entries > 1)
        , testCase "contact page has rel=me links" $ do
            tags <- tagsOf $ snapshot </> "contact" </> "index.html"
            let meLinks =
                    [ h
                    | TagOpen "a" attrs <- tags
                    , "me" `elem` words (fromMaybe "" (lookup "rel" attrs))
                    , Just h <- [lookup "href" attrs]
                    ]
            assertBool "links to the social profiles with rel=me" $
                all (`elem` meLinks) ["https://x.com/example", "https://github.com/example"]
        , testCase "home page has a representative h-card" $ do
            tags <- tagsOf $ snapshot </> "index.html"
            assertBool "has an h-card with a url" $ hasClassAll ["h-card", "u-url"] tags
        ]

-- | The open tags whose @class@ attribute lists the given token
withClass :: String -> [Tag String] -> [Tag String]
withClass cls = filter (elem cls . tagClasses)

-- | Whether any open tag carries the given class token
hasClass :: String -> [Tag String] -> Bool
hasClass cls = not . null . withClass cls

-- | Whether any open tag carries all the given class tokens
hasClassAll :: [String] -> [Tag String] -> Bool
hasClassAll clss = any (\t -> all (`elem` tagClasses t) clss)

-- | The @class@ tokens of a tag
tagClasses :: Tag String -> [String]
tagClasses (TagOpen _ attrs) = words (fromMaybe "" (lookup "class" attrs))
tagClasses _ = []

-- | Every @href@ on an @a@ carrying the @u-url@ class
urlHrefs :: [Tag String] -> [String]
urlHrefs tags =
    [ h
    | t@(TagOpen "a" attrs) <- tags
    , "u-url" `elem` tagClasses t
    , Just h <- [lookup "href" attrs]
    ]

tagsOf :: FilePath -> IO [Tag String]
tagsOf = fmap parseTags . readFile
