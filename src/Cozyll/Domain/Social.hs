{- | A social account, read from the single list in @socials.yaml@ (required).

== Schema

  [@icon@] icon name under @content/media/icons/social/@, without the @.svg@
      extension (required).
  [@href@] URL the account links to (required).
  [@username@] handle shown on the link (required).
  [@_show@] whether to include the account (default @true@; @_show: false@
      hides it).

See also @schema/socials.schema.json@.
-}
module Cozyll.Domain.Social (
    Social (..),
    parseSocial,
    parseSocialsYaml,
) where

import Cozyll.Metadata qualified as K
import Cozyll.Yaml (Check (runCheck), optional, parseYamlList, required)
import Data.Aeson (Object)
import Data.Maybe (fromMaybe)

-- | What a social account needs to be listed
data Social = Social
    { socialIcon :: String
    , socialHref :: String
    , socialUsername :: String
    , socialShow :: Bool
    }
    deriving (Eq, Show)

-- | Parses a social account, reporting every problem (not just the first)
parseSocial :: Object -> Either [String] Social
parseSocial o =
    runCheck
        ( Social
            <$> required o K.Icon
            <*> required o K.Href
            <*> required o K.Username
            <*> (fromMaybe True <$> optional o K.Show)
        )

-- | 'parseSocial' on the contents of the socials file (a list of accounts)
parseSocialsYaml :: String -> Either [String] [Social]
parseSocialsYaml = parseYamlList "social" parseSocial
