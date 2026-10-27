{-# LANGUAGE OverloadedStrings #-}

-- | Pure schema.org JSON-LD building blocks, depending on aeson alone
module Cozyll.JsonLd (
    Node,
    context,
    graph,
    idRef,
    websiteId,
    organizationId,
    authorId,
    articleId,
    render,
) where

import Data.Aeson (Value, object, (.=))
import Data.Aeson.Encoding (Series, encodingToLazyByteString, list, pair, pairs)
import Data.Text.Lazy qualified as LT
import Data.Text.Lazy.Encoding qualified as LTE

-- | A JSON-LD node, ready to be placed in a graph
type Node = Series

-- | The schema.org context
context :: Series
context = "@context" .= ("https://schema.org" :: String)

-- | A document whose nodes live in @\@graph@
graph :: [Node] -> Series
graph nodes = context <> pair "@graph" (list pairs nodes)

-- | A reference to a node by its identifier
idRef :: String -> Value
idRef ref = object ["@id" .= ref]

{- | The identifier of the site's @WebSite@ node

The base URL is expected to end with a slash (e.g. @https://example.com/@).
-}
websiteId :: String -> String
websiteId base = base ++ "#website"

-- | The identifier of the site's @Organization@ node (see 'websiteId')
organizationId :: String -> String
organizationId base = base ++ "#organization"

-- | The identifier of an author's @Person@ node (see 'websiteId')
authorId :: String -> String -> String
authorId base author = base ++ "authors/" ++ author ++ "/#person"

-- | The identifier of a page's @Article@ node
articleId :: String -> String
articleId pageUrl = pageUrl ++ "#article"

{- | Renders a series as a JSON string, escaping the angle brackets and the
ampersand so the result can be embedded in an HTML script element
-}
render :: Series -> String
render = escapeJson . encode
  where
    encode = LT.unpack . LTE.decodeUtf8 . encodingToLazyByteString . pairs

    escapeJson = concatMap escapeJsonChar

    escapeJsonChar '<' = "\\u003c"
    escapeJsonChar '>' = "\\u003e"
    escapeJsonChar '&' = "\\u0026"
    escapeJsonChar character = [character]
