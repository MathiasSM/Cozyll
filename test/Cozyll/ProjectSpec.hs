-- | Tests for the project YAML parser and showcase ordering
module Cozyll.ProjectSpec (tests) where

import Cozyll.Content (showcaseKey)
import Cozyll.Domain.Project (Project (..), Status (..), parseProjectYaml, statusName)
import Cozyll.TestUtils
import Data.Either (fromRight, isLeft)
import Data.List (sortOn)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))

tests :: TestTree
tests =
    testGroup
        "Project"
        [ statusTests
        , projectTests
        , showcaseTests
        ]

-- Status ---------------------------------------------------------------------

statusTests :: TestTree
statusTests =
    testGroup
        "Status"
        [ testCase "has a name for each status" $
            map statusName [Alpha, Finished, Ongoing, Unmaintained]
                @?= ["alpha", "finished", "ongoing", "unmaintained"]
        ]

-- Projects -------------------------------------------------------------------

-- | A project with every field filled in
sutori :: Fields
sutori =
    [ ("title", "Sutori")
    , ("href", "https://example.org/sutori")
    , ("status", "alpha")
    , ("startDate", "2018-05-02")
    , ("endDate", "2018-12-12")
    , ("shortDescription", "A language")
    , ("longDescription", "A language to tell stories")
    , ("team", "[Ana, Luis]")
    , ("priority", "2")
    ]

projectTests :: TestTree
projectTests =
    testGroup
        "parseProjectYaml"
        [ testCase "reads a full project" $
            parse sutori
                @?= Right
                    Project
                        { projectTitle = "Sutori"
                        , projectHref = "https://example.org/sutori"
                        , projectStatus = Alpha
                        , projectStart = day 2018 5 2
                        , projectEnd = Just (day 2018 12 12)
                        , projectShortDescription = "A language"
                        , projectLongDescription = "A language to tell stories"
                        , projectTeam = ["Ana", "Luis"]
                        , projectPriority = Just 2
                        }
        , testCase "leaves endDate, team and priority out when absent" $
            fmap
                (\p -> (projectEnd p, projectTeam p, projectPriority p))
                (parse $ without ["endDate", "team", "priority"] sutori)
                @?= Right (Nothing, [], Nothing)
        , testGroup "requires" $
            [ testCase key $ parse (without [key] sutori) @?= Left [key ++ ": missing"]
            | key <- ["title", "href", "status", "startDate", "shortDescription", "longDescription"]
            ]
        , testCase "rejects an unknown status" $
            parse (set "status" "wip" sutori)
                @?= Left ["status: unknown status \"wip\" (expected alpha, finished, ongoing, unmaintained)"]
        , testCase "accepts an end date on or after the start date" $
            fmap projectEnd (parse $ set "endDate" "2018-05-02" sutori) @?= Right (Just (day 2018 5 2))
        , testCase "rejects an end date before the start date" $
            parse (set "endDate" "2018-05-01" sutori)
                @?= Left ["endDate: 2018-05-01 is before startDate 2018-05-02"]
        , testCase "rejects text that isn't YAML" $
            assertBool "expected parsing to fail" (isLeft (parseProjectYaml "title: ["))
        ]
  where
    parse = parseFields parseProjectYaml

-- Showcase order -------------------------------------------------------------

showcaseTests :: TestTree
showcaseTests =
    testGroup
        "showcaseKey"
        [ testCase "puts projects with a priority first (lowest first), then the newest start" $
            map projectTitle (sortOn showcaseKey [old, second, new, first])
                @?= ["first", "second", "new", "old"]
        ]
  where
    old = project "old" "2015-01-01" Nothing
    new = project "new" "2020-01-01" Nothing
    first = project "first" "2012-01-01" (Just "1")
    second = project "second" "2010-01-01" (Just "2")

    project :: String -> String -> Maybe String -> Project
    project name start priority =
        fromRight (error $ "invalid fixture " ++ name) . parseFields parseProjectYaml
            $ maybe id (set "priority") priority
            $ set "startDate" start
            $ set "title" name
            $ without ["endDate", "team", "priority"] sutori
