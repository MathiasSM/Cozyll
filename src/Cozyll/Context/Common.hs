-- | Small builders shared by the context modules
module Cozyll.Context.Common (maybeField, itemField) where

import Hakyll (Context, Item (itemBody), field, noResult)

-- | A field present only when the accessor yields a value, so @$if()$@ is false otherwise
maybeField :: String -> (a -> Maybe String) -> Context a
maybeField key value = field key $ \item ->
    maybe (noResult $ "no " ++ key) pure (value (itemBody item))

-- | A field read straight off the item body
itemField :: String -> (a -> String) -> Context a
itemField key get = field key (pure . get . itemBody)
