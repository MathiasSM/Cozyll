{- | A showcase project's fields as a template context.

The available fields are @$title$@, @$href$@, @$status$@, @$startDate$@,
@$endDate$@ (absent when unset, because the field returns 'noResult'),
@$shortDescription$@, @$longDescription$@, and @$slug$@ (the project file's base
name, not a YAML field), plus the language and translation contexts.

@$team$@ and @$priority$@ are not exposed to templates; @priority@ is only used
to order the showcase. TODO: expose @team@ here.
-}
module Cozyll.Context.Project (projectContext) where

import Cozyll.Config (SiteConfig)
import Cozyll.Context.Common (itemField, maybeField)
import Cozyll.Context.Language (languageContext)
import Cozyll.Domain.Project (Project (..), statusName)
import Cozyll.Localization (translationsContext)
import Hakyll (Context, Item (itemIdentifier), field, toFilePath)
import System.FilePath.Posix (takeBaseName)

-- | A showcase project's fields, as read by the project templates
projectContext :: SiteConfig -> Context Project
projectContext cfg =
    mconcat
        [ itemField "title" projectTitle
        , itemField "href" projectHref
        , itemField "status" (statusName . projectStatus)
        , itemField "startDate" (show . projectStart)
        , maybeField "endDate" (fmap show . projectEnd)
        , itemField "shortDescription" projectShortDescription
        , itemField "longDescription" projectLongDescription
        , languageContext cfg
        , translationsContext cfg
        , field "slug" (return . takeBaseName . toFilePath . itemIdentifier)
        ]
