-- | Tests for @website.yaml@ decoding: the optional @funding:@ section and its error text
module Cozyll.WebsiteSpec (tests) where

import Cozyll.Domain.Website (Funding (..), FundingEntity (..), Website (..))
import Cozyll.Rules.WellKnown (fundingFiles)
import Cozyll.Yaml (decodeYaml)
import Data.List (isInfixOf)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))

tests :: TestTree
tests =
    testGroup
        "Website"
        [ parsingTests
        , errorTests
        , fundingFileTests
        ]

parsingTests :: TestTree
parsingTests =
    testGroup
        "websiteFunding"
        [ testCase "is Just when funding is present" $
            fmap websiteFunding (decodeYaml websiteWithFunding :: Either [String] Website)
                @?= Right (Just funding)
        , testCase "is Nothing when funding is omitted" $
            fmap websiteFunding (decodeYaml websiteWithoutFunding :: Either [String] Website)
                @?= Right Nothing
        ]

fundingFileTests :: TestTree
fundingFileTests =
    testGroup
        "fundingFiles"
        [ testCase "emits no files without funding" $
            fundingFiles author url Nothing @?= []
        , testCase "emits both files with funding" $ do
            let files = fundingFiles author url (Just funding)
            map fst files @?= [".well-known/funding-manifest-urls", "funding.json"]
            lookup ".well-known/funding-manifest-urls" files @?= Just (url ++ "/funding.json\n")
            assertBool "funding.json" $
                maybe False ("\"version\": \"v1.0.0\"" `isInfixOf`) (lookup "funding.json" files)
        ]

funding :: Funding
funding =
    Funding
        { fundingEntity =
            FundingEntity
                { fundingEntityEmail = "author@example.com"
                , fundingEntityDescription = "A description."
                }
        , fundingProjects = []
        , fundingChannels = []
        , fundingPlans = []
        }

author :: String
author = "Author"

url :: String
url = "https://example.com"

websiteWithFunding :: String
websiteWithFunding =
    websiteYaml
        [ "funding:"
        , "  entity:"
        , "    email: author@example.com"
        , "    description: A description."
        , "  projects: []"
        , "  channels: []"
        , "  plans: []"
        ]

websiteWithoutFunding :: String
websiteWithoutFunding = websiteYaml []

{- | The decode errors are user-facing, so pin the three shapes: a missing
required key, a wrong type, and a non-object where an object is expected
-}
errorTests :: TestTree
errorTests =
    testGroup
        "errorMessages"
        [ testCase "names a missing required key and its section" $
            withoutLine "  title: Example"
                @?= Left ["Aeson exception:\nError in $.site: key \"title\" not found"]
        , testCase "names a wrong-typed value by its path" $
            withLine "  size: 20" "  size: nope"
                @?= Left ["Aeson exception:\nError in $.feed.size: parsing Int failed, expected Number, but encountered String"]
        , testCase "reports a non-object where an object is expected" $
            (decodeYaml (websiteYaml ["funding: 3"]) :: Either [String] Website)
                @?= Left ["Aeson exception:\nError in $.funding: parsing funding failed, expected Object, but encountered Number"]
        ]

-- | @websiteYaml []@ without one of its lines
withoutLine :: String -> Either [String] Website
withoutLine dropped = decodeYaml . unlines . filter (/= dropped) . lines $ websiteYaml []

-- | @websiteYaml []@ with one of its lines replaced
withLine :: String -> String -> Either [String] Website
withLine old new = decodeYaml . unlines . map replace . lines $ websiteYaml []
  where
    replace line = if line == old then new else line

websiteYaml :: [String] -> String
websiteYaml extra =
    unlines $
        [ "site:"
        , "  title: Example"
        , "  description: An example site"
        , "  copyrightYear: 2020"
        , "  domain: example.com"
        , "contact:"
        , "  email: author@example.com"
        , "  page: /contact"
        , "manifest:"
        , "  backgroundColor: \"#fff\""
        , "  themeColor: \"#000\""
        , "mathjax:"
        , "  version: \"4.1.3\""
        , "highlight:"
        , "  style: pygments"
        , "feed:"
        , "  size: 20"
        , "security:"
        , "  preferredLanguages: en"
        , "  expires: \"2027-12-31T22:59:00.000Z\""
        , "  expirationMarginDays: 90"
        , "robots:"
        , "  disallow: []"
        , "trust:"
        , "  trainingAllowed: \"no\""
        ]
            ++ extra
