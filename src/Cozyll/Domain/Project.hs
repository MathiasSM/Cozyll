-- | A showcase project, as read from a project YAML file
module Cozyll.Domain.Project (
    Status (..),
    statusName,
    Project (..),
    parseProject,
    parseProjectYaml,
) where

import Control.Monad ((>=>))
import Cozyll.Metadata qualified as K
import Cozyll.Yaml (Check (runCheck), decodeYaml, enumFromJSON, optional, required)
import Data.Aeson (FromJSON (parseJSON), Object)
import Data.Maybe (fromMaybe)
import Data.Time (Day)

-- | How far along a project is
data Status = Alpha | Finished | Ongoing | Unmaintained
    deriving (Eq, Show, Enum, Bounded)

-- | How a project status is spelled
statusName :: Status -> String
statusName Alpha = "alpha"
statusName Finished = "finished"
statusName Ongoing = "ongoing"
statusName Unmaintained = "unmaintained"

instance FromJSON Status where
    parseJSON = enumFromJSON "status" statusName

-- | What a showcase project needs to be listed
data Project = Project
    { projectTitle :: String
    , projectHref :: String
    , projectStatus :: Status
    , projectStart :: Day
    , projectEnd :: Maybe Day
    , projectShortDescription :: String
    , projectLongDescription :: String
    , projectTeam :: [String]
    , projectPriority :: Maybe Int
    }
    deriving (Eq, Show)

{- | Parses a project, reporting every problem (not just the first).

The parser is tolerant: any key it does not model is ignored rather than rejected, so
extra, unknown fields in a project YAML never break the build. @team@ and @priority@ are
legacy fields, accepted but optional (and not exposed to templates).
-}
parseProject :: Object -> Either [String] Project
parseProject o =
    runCheck
        ( Project
            <$> required o K.Title
            <*> required o K.Href
            <*> required o K.Status
            <*> required o K.StartDate
            <*> optional o K.EndDate
            <*> required o K.ShortDescription
            <*> required o K.LongDescription
            <*> (fromMaybe [] <$> optional o K.Team)
            <*> optional o K.Priority
        )
        >>= endsAfterStart
  where
    endsAfterStart project = case projectEnd project of
        Just end | end < projectStart project -> Left ["endDate: " ++ show end ++ " is before startDate " ++ show (projectStart project)]
        _ -> Right project

-- | 'parseProject' on the contents of a project file
parseProjectYaml :: String -> Either [String] Project
parseProjectYaml = decodeYaml >=> parseProject
