-- | Tests for the optional @funding:@ section of @website.yaml@
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
