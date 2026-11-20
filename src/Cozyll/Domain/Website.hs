{- | The site configuration read from @website.yaml@ in the content repo.

The @funding:@ section is optional. A site without one publishes neither
@funding.json@ nor @.well-known/funding-manifest-urls@.
-}
module Cozyll.Domain.Website (
    -- * Main logic
    loadWebsite,
    validateSecurityExpiration,

    -- * @website.yaml@ parsing

    -- ** website:
    Website (..),

    -- ** site:
    Site (..),

    -- ** contact:
    Contact (..),

    -- ** manifest:
    Manifest (..),

    -- ** mathjax:
    Mathjax (..),

    -- ** highlight:
    Highlight (..),
    HighlightStyle (..),
    highlightStyleName,
    parseHighlightStyle,
    toPandocStyle,

    -- ** feed:
    FeedConfig (..),

    -- ** security:
    Security (..),

    -- ** ruby:
    CheckMode (..),
    checkModeName,
    parseCheckMode,

    -- ** robots:
    Robots (..),

    -- ** trust:
    Trust (..),

    -- ** funding:
    Funding (..),
    FundingEntity (..),
    FundingProject (..),
    FundingChannel (..),
    FundingPlan (..),
) where

import Control.Monad (when)
import Cozyll.Domain.Language (Language)
import Cozyll.Yaml (enumFromJSON, lookupEnum, readYamlFile, typeOptions)
import Data.Aeson (FromJSON (parseJSON), genericParseJSON, withObject, (.!=), (.:), (.:?))
import Data.Time (getCurrentTime, utctDay)
import Data.Time.Calendar (Day, addDays)
import Data.Time.Format (defaultTimeLocale, parseTimeM)
import GHC.Generics (Generic)
import System.Exit (die)
import System.FilePath.Posix ((</>))
import Text.Pandoc.Highlighting (Style, breezeDark, espresso, haddock, kate, monochrome, pygments, tango, zenburn)

-- | The @site:@ section: the site's identity
data Site = Site
    { siteTitle :: String
    , siteDescription :: String
    , siteCopyrightYear :: Int
    , siteDomain :: String
    , siteLanguage :: Maybe Language
    , siteAlternateNames :: [String]
    , siteLogo :: Maybe String
    }
    deriving (Eq, Show)

-- | The @contact:@ section: how to reach the site owner
data Contact = Contact
    { contactEmail :: String
    , contactPage :: String
    }
    deriving (Eq, Show, Generic)

-- | The @manifest:@ section: web app manifest colours
data Manifest = Manifest
    { manifestBackgroundColor :: String
    , manifestThemeColor :: String
    }
    deriving (Eq, Show, Generic)

-- | The @mathjax:@ section: which MathJax CDN version renders the site's math
data Mathjax = Mathjax
    { mathjaxVersion :: String
    }
    deriving (Eq, Show, Generic)

-- | The @highlight:@ section: which pandoc style renders code blocks
data Highlight = Highlight
    { highlightStyle :: HighlightStyle
    }
    deriving (Eq, Show, Generic)

-- | Severity of the ruby coverage check
data CheckMode = CheckOff | CheckWarn | CheckError
    deriving (Eq, Show, Enum, Bounded)

-- | How a check mode is spelled
checkModeName :: CheckMode -> String
checkModeName CheckOff = "off"
checkModeName CheckWarn = "warn"
checkModeName CheckError = "error"

instance FromJSON CheckMode where
    parseJSON = enumFromJSON "ruby check mode" checkModeName

-- | Resolves a 'CheckMode' from its spelling, if known
parseCheckMode :: String -> Maybe CheckMode
parseCheckMode = lookupEnum checkModeName

-- | A pandoc syntax-highlighting style, as spelled in @highlight.style@
data HighlightStyle = Pygments | Espresso | Zenburn | Tango | Kate | Monochrome | BreezeDark | Haddock
    deriving (Eq, Show, Enum, Bounded)

-- | How a highlight style is spelled
highlightStyleName :: HighlightStyle -> String
highlightStyleName Pygments = "pygments"
highlightStyleName Espresso = "espresso"
highlightStyleName Zenburn = "zenburn"
highlightStyleName Tango = "tango"
highlightStyleName Kate = "kate"
highlightStyleName Monochrome = "monochrome"
highlightStyleName BreezeDark = "breezeDark"
highlightStyleName Haddock = "haddock"

instance FromJSON HighlightStyle where
    parseJSON = enumFromJSON "highlight style" highlightStyleName

-- | Resolves a 'HighlightStyle' from its @highlight.style@ spelling, if known
parseHighlightStyle :: String -> Maybe HighlightStyle
parseHighlightStyle = lookupEnum highlightStyleName

-- | The pandoc 'Style' backing a 'HighlightStyle'
toPandocStyle :: HighlightStyle -> Style
toPandocStyle Pygments = pygments
toPandocStyle Espresso = espresso
toPandocStyle Zenburn = zenburn
toPandocStyle Tango = tango
toPandocStyle Kate = kate
toPandocStyle Monochrome = monochrome
toPandocStyle BreezeDark = breezeDark
toPandocStyle Haddock = haddock

instance FromJSON Highlight where
    parseJSON = genericParseJSON (typeOptions "highlight")

-- | The @funding:@ section: data behind @funding.json@
data Funding = Funding
    { fundingEntity :: FundingEntity
    , fundingProjects :: [FundingProject]
    , fundingChannels :: [FundingChannel]
    , fundingPlans :: [FundingPlan]
    }
    deriving (Eq, Show, Generic)

-- | The entity being funded (the @funding.entity@ section)
data FundingEntity = FundingEntity
    { fundingEntityEmail :: String
    , fundingEntityDescription :: String
    }
    deriving (Eq, Show, Generic)

-- | A project listed in @funding.json@
data FundingProject = FundingProject
    { fundingProjectGuid :: String
    , fundingProjectName :: String
    , fundingProjectDescription :: String
    , fundingProjectRepositoryUrl :: String
    , fundingProjectRepositoryWellKnown :: String
    , fundingProjectLicenses :: [String]
    , fundingProjectTags :: [String]
    }
    deriving (Eq, Show, Generic)

-- | A funding channel in @funding.json@
data FundingChannel = FundingChannel
    { fundingChannelGuid :: String
    , fundingChannelType :: String
    , fundingChannelAddress :: String
    , fundingChannelDescription :: String
    }
    deriving (Eq, Show, Generic)

-- | A funding plan in @funding.json@
data FundingPlan = FundingPlan
    { fundingPlanGuid :: String
    , fundingPlanStatus :: String
    , fundingPlanName :: String
    , fundingPlanDescription :: String
    , fundingPlanAmount :: Int
    , fundingPlanCurrency :: String
    , fundingPlanFrequency :: String
    , fundingPlanChannels :: [String]
    }
    deriving (Eq, Show, Generic)

-- | The @security:@ section: data behind @.well-known/security.txt@
data Security = Security
    { securityPreferredLanguages :: String
    , securityExpires :: String
    , securityExpirationMarginDays :: Int
    }
    deriving (Eq, Show, Generic)

-- | The @robots:@ section: data behind @robots.txt@
data Robots = Robots {robotsDisallow :: [String]}
    deriving (Eq, Show, Generic)

-- | The @trust:@ section: data behind @.well-known/trust.txt@
data Trust = Trust {trustTrainingAllowed :: String}
    deriving (Eq, Show, Generic)

-- | The @feed:@ section: data behind @atom.xml@ files
data FeedConfig = FeedConfig {feedSize :: Int}
    deriving (Eq, Show, Generic)

-- | Everything @website.yaml@ describes
data Website = Website
    { websiteSite :: Site
    , websiteContact :: Contact
    , websiteManifest :: Manifest
    , websiteMathjax :: Mathjax
    , websiteHighlight :: Highlight
    , websiteFunding :: Maybe Funding
    , websiteSecurity :: Security
    , websiteRobots :: Robots
    , websiteTrust :: Trust
    , websiteFeed :: FeedConfig
    , websiteJaRubyCheck :: CheckMode
    }
    deriving (Eq, Show)

instance FromJSON Site where
    parseJSON = withObject "site" $ \o ->
        Site
            <$> o .: "title"
            <*> o .: "description"
            <*> o .: "copyrightYear"
            <*> o .: "domain"
            <*> o .:? "language"
            <*> o .:? "alternateName" .!= []
            <*> o .:? "logo"

instance FromJSON Contact where
    parseJSON = genericParseJSON (typeOptions "contact")

instance FromJSON Manifest where
    parseJSON = genericParseJSON (typeOptions "manifest")

instance FromJSON Mathjax where
    parseJSON = genericParseJSON (typeOptions "mathjax")

instance FromJSON Funding where
    parseJSON = genericParseJSON (typeOptions "funding")

instance FromJSON FeedConfig where
    parseJSON = genericParseJSON (typeOptions "feed")

instance FromJSON FundingEntity where
    parseJSON = genericParseJSON (typeOptions "fundingEntity")

instance FromJSON FundingProject where
    parseJSON = genericParseJSON (typeOptions "fundingProject")

instance FromJSON FundingChannel where
    parseJSON = genericParseJSON (typeOptions "fundingChannel")

instance FromJSON FundingPlan where
    parseJSON = genericParseJSON (typeOptions "fundingPlan")

instance FromJSON Security where
    parseJSON = genericParseJSON (typeOptions "security")

instance FromJSON Robots where
    parseJSON = genericParseJSON (typeOptions "robots")

instance FromJSON Trust where
    parseJSON = genericParseJSON (typeOptions "trust")

instance FromJSON Website where
    parseJSON = withObject "website" $ \o ->
        Website
            <$> o .: "site"
            <*> o .: "contact"
            <*> o .: "manifest"
            <*> o .: "mathjax"
            <*> o .: "highlight"
            <*> o .:? "funding"
            <*> o .: "security"
            <*> o .: "robots"
            <*> o .: "trust"
            <*> o .: "feed"
            <*> o .:? "jaRubyCheck" .!= CheckError

-- | Reads and parses @<contentDir>/website.yaml@, failing with a clear message
loadWebsite :: FilePath -> IO Website
loadWebsite contentDir = readYamlFile $ contentDir </> "website.yaml"

-- | Fails if the @security.txt@ expiration is within the configured margin (or already passed)
validateSecurityExpiration :: Website -> IO ()
validateSecurityExpiration website = do
    today <- utctDay <$> getCurrentTime
    let security = websiteSecurity website
        margin = securityExpirationMarginDays security
        deadline = addDays (fromIntegral margin) today
    case parseExpiryDate (securityExpires security) of
        Nothing -> die $ "Invalid security.expires date: " ++ securityExpires security
        Just expires ->
            when (expires <= deadline)
                $ die
                $ "security.txt expires on " ++ show expires ++ " (within " ++ show margin ++ " days); renew it"

-- | Parses the leading @YYYY-MM-DD@ of an ISO timestamp
parseExpiryDate :: String -> Maybe Day
parseExpiryDate = parseTimeM True defaultTimeLocale "%Y-%m-%d" . take 10
