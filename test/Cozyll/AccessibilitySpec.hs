-- | Tests for the accessibility checks
module Cozyll.AccessibilitySpec (tests) where

import Cozyll.Accessibility (checkHtml)
import Data.List (isPrefixOf)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (Assertion, assertBool, testCase, (@?=))

-- | The accessibility checks
tests :: TestTree
tests =
    testGroup
        "Accessibility"
        [ testGroup
            "images"
            [ testCase "reports an image missing its alt" $
                reports "<img>" "image missing an `alt` attribute"
            , testCase "allows a decorative image with an empty alt" $
                notReported "<img alt=\"\">" "image missing an `alt` attribute"
            , testCase "allows an image with alt text" $
                notReported "<img alt=\"the logo\">" "image missing an `alt` attribute"
            ]
        , testGroup
            "title"
            [ testCase "reports a missing title" $ reports "<div></div>" "no <title>"
            , testCase "reports an empty title" $ reports "<title></title>" "empty <title>"
            , testCase "reports multiple titles" $
                reports "<title>a</title><title>b</title>" "multiple <title> elements"
            , testCase "allows a single non-empty title" $
                notReported "<title>Home</title>" "no <title>"
            ]
        , testGroup
            "language"
            [ testCase "reports a missing html element" $ reports "<div></div>" "no <html> element"
            , testCase "reports an empty lang" $ reports "<html lang=\"\"></html>" "missing non-empty `lang` on <html>"
            , testCase "allows a non-empty lang" $
                notReported "<html lang=\"en\"></html>" "missing non-empty `lang` on <html>"
            ]
        , testGroup
            "h1"
            [ testCase "reports a missing h1" $ reports "<div></div>" "no <h1>"
            , testCase "reports multiple h1 elements" $
                reports "<h1>a</h1><h1>b</h1>" "multiple <h1> elements"
            , testCase "allows a single h1" $ notReported "<h1>Title</h1>" "no <h1>"
            ]
        , testGroup
            "heading order"
            [ testCase "allows consecutive levels" $
                notReported "<h1>a</h1><h2>b</h2><h3>c</h3>" "heading level skips"
            , testCase "allows repeating the same level" $
                notReported "<h2>a</h2><h2>b</h2>" "heading level skips"
            , testCase "reports a skipped level" $
                reports "<h1>a</h1><h3>b</h3>" "heading level skips from h1 to h3"
            ]
        , testGroup
            "empty headings"
            [ testCase "reports an empty heading" $ reports "<h2></h2>" "empty <h2>"
            , testCase "allows a heading with text" $ notReported "<h2>Section</h2>" "empty <h2>"
            ]
        , testGroup
            "links"
            [ testCase "reports a link with no accessible name" $
                reports "<a href=\"/x\"></a>" "link has no accessible name"
            , testCase "uses text as the name" $
                notReported "<a href=\"/x\">Home</a>" "link has no accessible name"
            , testCase "uses aria-label as the name" $
                notReported "<a href=\"/x\" aria-label=\"Home\"></a>" "link has no accessible name"
            , testCase "uses title as the name" $
                notReported "<a href=\"/x\" title=\"Home\"></a>" "link has no accessible name"
            , testCase "uses an inner image alt as the name" $
                notReported "<a href=\"/x\"><img alt=\"Home\"></a>" "link has no accessible name"
            , testCase "reports whitespace-only link text" $
                reports "<a href=\"/x\">   </a>" "link has no accessible name"
            ]
        , testGroup
            "inline svg"
            [ testCase "allows an svg hidden via its own aria-hidden" $
                notReported "<svg aria-hidden=\"true\"></svg>" "inline svg has no accessible name"
            , testCase "allows an svg hidden via an ancestor aria-hidden" $
                notReported "<span aria-hidden=\"true\"><svg></svg></span>" "inline svg has no accessible name"
            , testCase "uses role and aria-label as the name" $
                notReported "<svg role=\"img\" aria-label=\"Menu\"></svg>" "inline svg has no accessible name"
            , testCase "uses aria-labelledby as the name" $
                notReported "<svg role=\"img\" aria-labelledby=\"title-1\"></svg>" "inline svg has no accessible name"
            , testCase "uses an inner title as the name" $
                notReported "<svg><title>Menu</title></svg>" "inline svg has no accessible name"
            , testCase "reports a bare svg" $
                reports "<svg></svg>" "inline svg has no accessible name"
            , testCase "reports role without a name" $
                reports "<svg role=\"img\"></svg>" "inline svg has no accessible name"
            , testCase "reports an svg after a closed aria-hidden wrapper" $
                reports "<span aria-hidden=\"true\"></span><svg></svg>" "inline svg has no accessible name"
            , testCase "reports an svg after an aria-hidden void sibling" $
                reports "<img alt=\"\" aria-hidden=\"true\"><svg></svg>" "inline svg has no accessible name"
            ]
        , testGroup
            "ids"
            [ testCase "reports duplicate ids" $
                reports "<h2 id=\"a\"></h2><h2 id=\"a\"></h2>" "duplicate id: a"
            , testCase "allows unique ids" $
                notReported "<h2 id=\"a\"></h2><h2 id=\"b\"></h2>" "duplicate id"
            ]
        , testGroup
            "main"
            [ testCase "reports a missing main" $ reports "<div></div>" "no <main>"
            , testCase "reports multiple main elements" $
                reports "<main></main><main></main>" "multiple <main> elements"
            , testCase "allows a single main" $ notReported "<main></main>" "no <main>"
            ]
        , testCase "passes a fully valid page" $
            checkHtml "<html lang=\"en\"><head><title>Home</title></head><body><main><h1>Title</h1><p>Hello</p></main></body></html>" @?= []
        ]

-- | The problem appears among the page's findings
reports :: String -> String -> Assertion
reports snippet problem =
    assertBool ("expected to report: " ++ problem) (any (problem `isPrefixOf`) (checkHtml snippet))

-- | The problem does not appear among the page's findings
notReported :: String -> String -> Assertion
notReported snippet problem =
    assertBool ("expected not to report: " ++ problem) (not (any (problem `isPrefixOf`) (checkHtml snippet)))
