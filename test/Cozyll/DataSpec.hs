-- | Tests for the generic data-file helpers
module Cozyll.DataSpec (tests) where

import Cozyll.Context.Data (
    IconVariant (..),
    breakOnDot,
    checkAgainstSchema,
    iconName,
    iconVariant,
    isShown,
    lookupLeaf,
    nameToRelPath,
    renderScalar,
    scalarString,
 )
import Cozyll.TestUtils (assertFails)
import Cozyll.Yaml (decodeYaml)
import Data.Either (fromRight)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

-- | The data helpers tests
tests :: TestTree
tests =
    testGroup
        "Data"
        [ testGroup
            "nameToRelPath"
            [ testCase "keeps a flat name" $ nameToRelPath "hobbies" @?= "hobbies"
            , testCase "turns directory separators into dashes" $ nameToRelPath "team-members" @?= "team/members"
            , testCase "handles several levels" $ nameToRelPath "a-b-c" @?= "a/b/c"
            ]
        , testGroup
            "lookupLeaf"
            [ testCase "finds a scalar at the top level" $
                renderScalar <$> lookupLeaf "name" example @?= Just "Drawing"
            , testCase "finds a scalar in a nested map" $
                renderScalar <$> lookupLeaf "nested.city" example @?= Just "Lima"
            , testCase "returns nothing for a missing key" $
                lookupLeaf "missing" example @?= Nothing
            , testCase "returns nothing when a path crosses a scalar" $
                lookupLeaf "name.extra" example @?= Nothing
            ]
        , testGroup
            "isShown"
            [ testCase "keeps an item without a _show field" $
                isShown (doc "name: Drawing") @?= True
            , testCase "keeps an item with _show: true" $
                isShown (doc "name: Drawing\n_show: true") @?= True
            , testCase "hides an item with _show: false" $
                isShown (doc "name: Collecting\n_show: false") @?= False
            , testCase "keeps a non-object item" $
                isShown (doc "Drawing") @?= True
            ]
        , testGroup
            "renderScalar"
            [ testCase "renders strings as-is" $ leaf "name: Drawing" "name" @?= Just "Drawing"
            , testCase "renders integers without a decimal" $ leaf "n: 3" "n" @?= Just "3"
            , testCase "renders booleans as true/false" $ leaf "b: true" "b" @?= Just "true"
            , testCase "renders null as empty" $ leaf "x: null" "x" @?= Just ""
            , testCase "renders true" $ renderScalar (doc "true") @?= "true"
            , testCase "renders false" $ renderScalar (doc "false") @?= "false"
            , testCase "renders a map as empty" $ renderScalar (doc "{a: 1}") @?= ""
            , testCase "renders a list as empty" $ renderScalar (doc "[1]") @?= ""
            ]
        , testGroup
            "scalarString"
            [ testCase "reads a string" $ scalarString (doc "hello") @?= Just "hello"
            , testCase "reads a number" $ scalarString (doc "3") @?= Just "3"
            , testCase "reads true" $ scalarString (doc "true") @?= Just "true"
            , testCase "reads false" $ scalarString (doc "false") @?= Just "false"
            , testCase "reads null as empty" $ scalarString (doc "null") @?= Just ""
            , testCase "rejects a map" $ scalarString (doc "{a: 1}") @?= Nothing
            , testCase "rejects a list" $ scalarString (doc "[1]") @?= Nothing
            ]
        , testGroup
            "iconName"
            [ testCase "reads a string" $ iconName (doc "book") @?= Just "book"
            , testCase "rejects a number" $ iconName (doc "3") @?= Nothing
            , testCase "rejects a boolean" $ iconName (doc "true") @?= Nothing
            , testCase "rejects null" $ iconName (doc "null") @?= Nothing
            ]
        , testGroup
            "breakOnDot"
            [ testCase "keeps a flat name whole" $ breakOnDot "hobbies" @?= ("hobbies", "")
            , testCase "splits a map field at the first dot" $ breakOnDot "foo.bar" @?= ("foo", "bar")
            , testCase "keeps the remaining dotted path together" $ breakOnDot "foo.bar.baz" @?= ("foo", "bar.baz")
            ]
        , testGroup
            "iconVariant"
            [ testCase "detects an icon href field" $ iconVariant "iconHref" @?= Just ("icon", Href)
            , testCase "detects an icon raw field" $ iconVariant "iconRaw" @?= Just ("icon", Raw)
            , testCase "keeps the base name before the suffix" $ iconVariant "faviconHref" @?= Just ("favicon", Href)
            , testCase "handles the Raw suffix on a prefixed field" $ iconVariant "faviconRaw" @?= Just ("favicon", Raw)
            , testCase "ignores a plain field" $ iconVariant "name" @?= Nothing
            , testCase "ignores a field ending in Href without icon" $ iconVariant "downloadHref" @?= Nothing
            , testCase "ignores an icon field without a suffix" $ iconVariant "icon" @?= Nothing
            , testCase "is case-sensitive" $ iconVariant "IconHref" @?= Nothing
            ]
        , testGroup
            "checkAgainstSchema"
            [ testCase "accepts valid data" $ checkAgainstSchema schema valid @?= Right ()
            , testCase "rejects data missing a required field" $
                assertFails (checkAgainstSchema schema invalid)
            ]
        ]
  where
    example = doc "name: Drawing\nnested:\n  city: Lima"
    schema = doc "type: object\nrequired: [name]\nproperties:\n  name:\n    type: string"
    valid = doc "name: Drawing"
    invalid = doc "{}"

    -- Decodes a YAML document to a JSON value
    doc = fromRight (error "invalid fixture") . decodeYaml

    -- Parses a one-field map and renders that field
    leaf yaml key = renderScalar <$> lookupLeaf key (doc yaml)
