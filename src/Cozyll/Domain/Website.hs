-- | The site configuration read from @website.yaml@ in the content repo
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

import Control.Monad (unless, when)
import Cozyll.Yaml (enumFromJSON)
import Data.Aeson (FromJSON (parseJSON), withObject, (.:), (.:?))
import Data.Time (getCurrentTime, utctDay)
import Data.Time.Calendar (Day, addDays)
import Data.Time.Format (defaultTimeLocale, parseTimeM)
import Data.Yaml (decodeFileEither, prettyPrintParseException)
import System.Directory (doesFileExist)
import System.Exit (die)
import System.FilePath.Posix ((</>))
import Text.Pandoc.Highlighting (Style, breezeDark, espresso, haddock, kate, monochrome, pygments, tango, zenburn)

-- | The @site:@ section: the site's identity
data Site = Site
    { siteName :: String
    , siteDescription :: String
    , siteAuthor :: String
    , siteCopyrightYear :: Int
    , siteDomain :: String
    , siteTwitterHandle :: String
    , siteAuthorUrl :: Maybe String
    }
    deriving (Eq, Show)

-- | The @contact:@ section: how to reach the site owner
data Contact = Contact
    { contactEmail :: String
    , contactPage :: String
    }
    deriving (Eq, Show)

-- | The @manifest:@ section: web app manifest colours
data Manifest = Manifest
    { manifestBackgroundColor :: String
    , manifestThemeColor :: String
    }
    deriving (Eq, Show)

-- | The @mathjax:@ section: which MathJax CDN version renders the site's math
data Mathjax = Mathjax
    { mathjaxVersion :: String
    }
    deriving (Eq, Show)

-- | The @highlight:@ section: which pandoc style renders code blocks
data Highlight = Highlight
    { highlightStyle :: HighlightStyle
    }
    deriving (Eq, Show)

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
parseHighlightStyle name = lookup name [(highlightStyleName style, style) | style <- [minBound .. maxBound]]

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
    parseJSON = withObject "highlight" $ \o ->
        Highlight <$> o .: "style"

-- | The @funding:@ section: data behind @funding.json@
data Funding = Funding
    { fundingEntity :: FundingEntity
    , fundingProjects :: [FundingProject]
    , fundingChannels :: [FundingChannel]
    , fundingPlans :: [FundingPlan]
    }
    deriving (Eq, Show)

-- | The entity being funded (the @funding.entity@ section)
data FundingEntity = FundingEntity
    { fundingEntityEmail :: String
    , fundingEntityDescription :: String
    }
    deriving (Eq, Show)

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
    deriving (Eq, Show)

-- | A funding channel in @funding.json@
data FundingChannel = FundingChannel
    { fundingChannelGuid :: String
    , fundingChannelType :: String
    , fundingChannelAddress :: String
    , fundingChannelDescription :: String
    }
    deriving (Eq, Show)

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
    deriving (Eq, Show)

-- | The @security:@ section: data behind @.well-known/security.txt@
data Security = Security
    { securityPreferredLanguages :: String
    , securityExpires :: String
    , securityExpirationMarginDays :: Int
    }
    deriving (Eq, Show)

-- | The @robots:@ section: data behind @robots.txt@
data Robots = Robots {robotsDisallow :: [String]}
    deriving (Eq, Show)

-- | The @trust:@ section: data behind @.well-known/trust.txt@
data Trust = Trust {trustTrainingAllowed :: String}
    deriving (Eq, Show)

-- | The @feed:@ section: data behind @atom.xml@ files
data FeedConfig = FeedConfig {feedSize :: Int}
    deriving (Eq, Show)

-- | Everything @website.yaml@ describes
data Website = Website
    { websiteSite :: Site
    , websiteContact :: Contact
    , websiteManifest :: Manifest
    , websiteMathjax :: Mathjax
    , websiteHighlight :: Highlight
    , websiteFunding :: Funding
    , websiteSecurity :: Security
    , websiteRobots :: Robots
    , websiteTrust :: Trust
    , websiteFeed :: FeedConfig
    }
    deriving (Eq, Show)

instance FromJSON Site where
    parseJSON = withObject "site" $ \o ->
        Site
            <$> o .: "name"
            <*> o .: "description"
            <*> o .: "author"
            <*> o .: "copyrightYear"
            <*> o .: "domain"
            <*> o .: "twitterHandle"
            <*> o .:? "authorUrl"

instance FromJSON Contact where
    parseJSON = withObject "contact" $ \o ->
        Contact <$> o .: "email" <*> o .: "page"

instance FromJSON Manifest where
    parseJSON = withObject "manifest" $ \o ->
        Manifest <$> o .: "backgroundColor" <*> o .: "themeColor"

instance FromJSON Mathjax where
    parseJSON = withObject "mathjax" $ \o ->
        Mathjax <$> o .: "version"

instance FromJSON Funding where
    parseJSON = withObject "funding" $ \o ->
        Funding
            <$> o .: "entity"
            <*> o .: "projects"
            <*> o .: "channels"
            <*> o .: "plans"

instance FromJSON FeedConfig where
    parseJSON = withObject "feed" $ \o ->
        FeedConfig <$> o .: "size"

instance FromJSON FundingEntity where
    parseJSON = withObject "funding.entity" $ \o ->
        FundingEntity <$> o .: "email" <*> o .: "description"

instance FromJSON FundingProject where
    parseJSON = withObject "funding.project" $ \o ->
        FundingProject
            <$> o .: "guid"
            <*> o .: "name"
            <*> o .: "description"
            <*> o .: "repositoryUrl"
            <*> o .: "repositoryWellKnown"
            <*> o .: "licenses"
            <*> o .: "tags"

instance FromJSON FundingChannel where
    parseJSON = withObject "funding.channel" $ \o ->
        FundingChannel
            <$> o .: "guid"
            <*> o .: "type"
            <*> o .: "address"
            <*> o .: "description"

instance FromJSON FundingPlan where
    parseJSON = withObject "funding.plan" $ \o ->
        FundingPlan
            <$> o .: "guid"
            <*> o .: "status"
            <*> o .: "name"
            <*> o .: "description"
            <*> o .: "amount"
            <*> o .: "currency"
            <*> o .: "frequency"
            <*> o .: "channels"

instance FromJSON Security where
    parseJSON = withObject "security" $ \o ->
        Security
            <$> o .: "preferredLanguages"
            <*> o .: "expires"
            <*> o .: "expirationMarginDays"

instance FromJSON Robots where
    parseJSON = withObject "robots" $ \o -> Robots <$> o .: "disallow"

instance FromJSON Trust where
    parseJSON = withObject "trust" $ \o -> Trust <$> o .: "trainingAllowed"

instance FromJSON Website where
    parseJSON = withObject "website" $ \o ->
        Website
            <$> o .: "site"
            <*> o .: "contact"
            <*> o .: "manifest"
            <*> o .: "mathjax"
            <*> o .: "highlight"
            <*> o .: "funding"
            <*> o .: "security"
            <*> o .: "robots"
            <*> o .: "trust"
            <*> o .: "feed"

-- | Reads and parses @<contentDir>/website.yaml@, failing with a clear message
loadWebsite :: FilePath -> IO Website
loadWebsite contentDir = do
    let path = contentDir </> "website.yaml"
    exists <- doesFileExist path
    unless exists $ die $ path ++ " not found"
    result <- decodeFileEither path
    either (\e -> die $ "Invalid " ++ path ++ ":\n" ++ prettyPrintParseException e) pure result

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
