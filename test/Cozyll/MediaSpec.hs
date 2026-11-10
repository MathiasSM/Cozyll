-- | Tests for the media and static-file routes
module Cozyll.MediaSpec (tests) where

import Cozyll.Rules.Assets (mediaTarget, staticTarget)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

-- | The media and static-file route tests
tests :: TestTree
tests =
    testGroup
        "Media"
        [ testGroup
            "mediaTarget"
            [ testCase "keeps a photo under its category" $
                mediaTarget media "content/media/photos/x.png" @?= "images/photos/x.png"
            , testCase "keeps a nested icon under its category" $
                mediaTarget media "content/media/icons/x.svg" @?= "images/icons/x.svg"
            , testCase "flattens a raster branding file to the images root" $
                mediaTarget media "content/media/branding/logo.png" @?= "images/logo.png"
            , testCase "flattens the branding SVG to the images root" $
                mediaTarget media "content/media/branding/logo.svg" @?= "images/logo.svg"
            , testCase "publishes a depth-one media file at the images root" $
                mediaTarget media "content/media/logo.png" @?= "images/logo.png"
            , testCase "publishes an unknown extension under its category" $
                mediaTarget media "content/media/foo/bar.pdf" @?= "images/foo/bar.pdf"
            ]
        , testGroup
            "staticTarget"
            [ testCase "puts a root file at the site root" $
                staticTarget static "content/static/CNAME" @?= Right "CNAME"
            , testCase "keeps a hidden root file" $
                staticTarget static "content/static/.nojekyll" @?= Right ".nojekyll"
            , testCase "keeps the path of a nested file" $
                staticTarget static "content/static/assets/x.css" @?= Right "assets/x.css"
            , testCase "rejects a parent-directory segment" $
                staticTarget static "content/static/../secret" @?= Left "contains a parent-directory (..) segment"
            , testCase "rejects an absolute path" $
                staticTarget static "content/static//etc/passwd" @?= Left "would be published at an absolute path"
            , testCase "rejects a file outside the static directory" $
                staticTarget static "content/media/logo.png" @?= Left "is not under the static directory"
            ]
        ]
  where
    media = "content/media"
    static = "content/static"
