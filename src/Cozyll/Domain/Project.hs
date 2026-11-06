{- | A showcase project, read from one YAML file under @content/projects/@.

== Schema

  [@title@] the project's name (required).
  [@href@] link to the project (required).
  [@status@] one of @alpha@, @finished@, @ongoing@, @unmaintained@ (required).
  [@startDate@] @YYYY-MM-DD@ (required).
  [@endDate@] @YYYY-MM-DD@ (optional; must not precede @startDate@).
  [@shortDescription@] one-line summary (required).
  [@longDescription@] longer prose (required).
  [@team@] list of people (optional, defaults to @[]@).
  [@priority@] integer sort key, lower first (optional; unset sorts last).

Showcase order is @(priority, startDate descending)@; see
@Cozyll.Content.showcaseKey@.

@projectTeam@ is parsed and validated but is not exposed to templates yet.
TODO: expose it in "Cozyll.Context.Project".
-}
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

-- | Parses a project, reporting every problem (not just the first)
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
