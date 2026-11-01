-- | A showcase project's fields as a template context
module Cozyll.Context.Project (projectContext) where

import Cozyll.Config (SiteConfig)
import Cozyll.Context.Language (languageContext)
import Cozyll.Domain.Project (Project (..), statusName)
import Cozyll.Localization (translationsContext)
import Hakyll (Context, Item (itemBody), field, noResult)

-- | A showcase project's fields, as read by the project templates
projectContext :: SiteConfig -> Context Project
projectContext cfg =
    mconcat
        [ projectField "title" projectTitle
        , projectField "href" projectHref
        , projectField "status" (statusName . projectStatus)
        , projectField "startDate" (show . projectStart)
        , optionalField "endDate" (fmap show . projectEnd)
        , projectField "shortDescription" projectShortDescription
        , projectField "longDescription" projectLongDescription
        , languageContext
        , translationsContext cfg
        ]
  where
    projectField name get = field name (return . get . itemBody)
    optionalField name get = field name (maybe (noResult $ "No " ++ name) return . get . itemBody)
