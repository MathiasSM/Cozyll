-- | Generates the site's well-known and metadata files (robots.txt, funding.json, …) from @website.yaml@
module Cozyll.Rules.WellKnown (processWellKnownFiles, fundingFiles, manifestTxt) where

import Cozyll.Brand (SiteIcon (..), brandIcons, iconHref, manifestIcons)
import Cozyll.Config (SiteConfig, baseUrl, siteBrand, siteDefaultAuthor, siteInputFingerprint, siteTitle, socialsFile)
import Cozyll.Content (requireSocials)
import Cozyll.Domain.Author (authorName)
import Cozyll.Domain.Social (Social (..))
import Cozyll.Domain.Website (
    Contact (..),
    Funding (..),
    FundingChannel (..),
    FundingEntity (..),
    FundingPlan (..),
    FundingProject (..),
    Manifest (..),
    Robots (..),
    Security (..),
    Trust (..),
    Website (..),
 )
import Data.List (intercalate)
import Hakyll (
    Compiler,
    Rules,
    compile,
    create,
    fromFilePath,
    idRoute,
    load,
    makeItem,
    route,
 )

-- | Emits the files that the site generates from @website.yaml@ (rather than copies)
processWellKnownFiles :: SiteConfig -> Website -> Rules ()
processWellKnownFiles cfg website = do
    let url = baseUrl cfg
        contact = websiteContact website
        icons = maybe [] brandIcons (siteBrand cfg)
    createFile cfg "robots.txt" (robotsTxt url (robotsDisallow (websiteRobots website)))
    createFile cfg "manifest.webmanifest" (manifestTxt (siteTitle cfg) (websiteManifest website) icons)
    createFile cfg ".well-known/security.txt" (securityTxt url (contactPage contact) (websiteSecurity website))
    mapM_ (uncurry (createFile cfg)) (fundingFiles (authorName (siteDefaultAuthor cfg)) url (websiteFunding website))
    createFileCompiler ".well-known/trust.txt" $ do
        siteInputFingerprint cfg
        socials <- socialHrefs cfg
        pure (trustTxt url (contactPage contact) socials (websiteTrust website))

-- | Creates a routed file whose content is already known
createFile :: SiteConfig -> FilePath -> String -> Rules ()
createFile cfg path content = create [fromFilePath path] $ do
    route idRoute
    compile (siteInputFingerprint cfg >> makeItem content)

-- | Creates a routed file whose content is computed in a 'Compiler'
createFileCompiler :: FilePath -> Compiler String -> Rules ()
createFileCompiler path build = create [fromFilePath path] $ do
    route idRoute
    compile (build >>= makeItem)

-- | The @href@ of every social account, in file order
socialHrefs :: SiteConfig -> Compiler [String]
socialHrefs cfg = do
    file <- load (socialsFile cfg)
    socials <- requireSocials file
    pure (map socialHref socials)

-- Text files ----------------------------------------------------------------

robotsTxt :: String -> [String] -> String
robotsTxt url disallow =
    unlines $
        ["User-Agent: *", ""]
            ++ map ("Disallow: " ++) disallow
            ++ ["", "Sitemap: " ++ url ++ "/sitemap.xml"]

securityTxt :: String -> String -> Security -> String
securityTxt url contactPage security =
    unlines
        [ "# https://www.rfc-editor.org/rfc/rfc9116"
        , ""
        , "Canonical: " ++ url ++ "/.well-known/security.txt"
        , ""
        , "Contact: " ++ url ++ contactPage
        , ""
        , "Preferred-Languages: " ++ securityPreferredLanguages security
        , ""
        , "Expires: " ++ securityExpires security
        ]

fundingManifestUrls :: String -> String
fundingManifestUrls url = url ++ "/funding.json\n"

{- | The files generated from the optional @funding:@ section, in build order.
Empty when @website.yaml@ has no @funding:@ section, so such a site publishes
neither @funding.json@ nor @.well-known/funding-manifest-urls@.
-}
fundingFiles :: String -> String -> Maybe Funding -> [(FilePath, String)]
fundingFiles author url funding =
    case funding of
        Nothing -> []
        Just value ->
            [ (".well-known/funding-manifest-urls", fundingManifestUrls url)
            , ("funding.json", fundingJson author url value)
            ]

trustTxt :: String -> String -> [String] -> Trust -> String
trustTxt url contactPage socials trust =
    unlines $
        [ "# https://journallist.net/reference-document-for-trust-txt-specifications"
        , ""
        , "# Single member: me."
        , "member=" ++ url
        , "contact=" ++ url ++ contactPage
        , ""
        , "# My socials:"
        ]
            ++ map ("social=" ++) socials
            ++ ["", "", "# AI, begone (please):", "datatrainingallowed=" ++ trustTrainingAllowed trust]

-- JSON files ----------------------------------------------------------------

{- | The web app manifest. The @icons@ key mirrors the brand's PNG icons (the
same list the favicon rules generate) and is omitted entirely when there is no
logo.
-}
manifestTxt :: String -> Manifest -> [SiteIcon] -> String
manifestTxt name manifest icons =
    encodePretty
        ( JObject
            ( [ ("name", JString name)
              , ("background_color", JString (manifestBackgroundColor manifest))
              , ("theme_color", JString (manifestThemeColor manifest))
              ]
                ++ iconField
            )
        )
        ++ "\n"
  where
    iconField
        | null manifestEntries = []
        | otherwise =
            [("icons", JArray (map iconJson manifestEntries))]
    manifestEntries = manifestIcons icons

    iconJson icon =
        JObject
            ( ("src", JString (iconHref icon))
                : maybe [] (\typ -> [("type", JString typ)]) (iconType icon)
                ++ maybe [] (\sizes -> [("sizes", JString sizes)]) (iconSizes icon)
            )

fundingJson :: String -> String -> Funding -> String
fundingJson author url funding =
    encodePretty
        ( JObject
            [ ("version", JString "v1.0.0")
            ,
                ( "entity"
                , JObject
                    [ ("type", JString "individual")
                    , ("role", JString "owner")
                    , ("name", JString author)
                    , ("email", JString (fundingEntityEmail (fundingEntity funding)))
                    , ("phone", JString "")
                    , ("description", JString (fundingEntityDescription (fundingEntity funding)))
                    , ("webpageUrl", JObject [("url", JString url)])
                    ]
                )
            , ("projects", JArray (map (projectJson url) (fundingProjects funding)))
            ,
                ( "funding"
                , JObject
                    [ ("channels", JArray (map channelJson (fundingChannels funding)))
                    , ("plans", JArray (map planJson (fundingPlans funding)))
                    , ("history", JArray [])
                    ]
                )
            ]
        )
        ++ "\n"

projectJson :: String -> FundingProject -> Json
projectJson url project =
    JObject
        [ ("guid", JString (fundingProjectGuid project))
        , ("name", JString (fundingProjectName project))
        , ("description", JString (fundingProjectDescription project))
        , ("webpageUrl", JObject [("url", JString url)])
        ,
            ( "repositoryUrl"
            , JObject
                [ ("url", JString (fundingProjectRepositoryUrl project))
                , ("wellKnown", JString (fundingProjectRepositoryWellKnown project))
                ]
            )
        , ("licenses", JArray (map JString (fundingProjectLicenses project)))
        , ("tags", JArray (map JString (fundingProjectTags project)))
        ]

channelJson :: FundingChannel -> Json
channelJson channel =
    JObject
        [ ("guid", JString (fundingChannelGuid channel))
        , ("type", JString (fundingChannelType channel))
        , ("address", JString (fundingChannelAddress channel))
        , ("description", JString (fundingChannelDescription channel))
        ]

planJson :: FundingPlan -> Json
planJson plan =
    JObject
        [ ("guid", JString (fundingPlanGuid plan))
        , ("status", JString (fundingPlanStatus plan))
        , ("name", JString (fundingPlanName plan))
        , ("description", JString (fundingPlanDescription plan))
        , ("amount", JNumber (fundingPlanAmount plan))
        , ("currency", JString (fundingPlanCurrency plan))
        , ("frequency", JString (fundingPlanFrequency plan))
        , ("channels", JArray (map JString (fundingPlanChannels plan)))
        ]

-- | A tiny JSON value with stable key order, rendered with 2-space indentation
data Json
    = JObject [(String, Json)]
    | JArray [Json]
    | JString String
    | JNumber Int

encodePretty :: Json -> String
encodePretty = go 0
  where
    indent n = concat (replicate n "  ")

    go :: Int -> Json -> String
    go _ (JString s) = "\"" ++ escape s ++ "\""
    go _ (JNumber i) = show i
    go _ (JArray []) = "[]"
    go n (JArray xs) =
        "["
            ++ intercalate "," ["\n" ++ indent (n + 1) ++ go (n + 1) x | x <- xs]
            ++ "\n"
            ++ indent n
            ++ "]"
    go _ (JObject []) = "{}"
    go n (JObject fields) =
        "{"
            ++ intercalate "," ["\n" ++ indent (n + 1) ++ "\"" ++ key ++ "\": " ++ go (n + 1) value | (key, value) <- fields]
            ++ "\n"
            ++ indent n
            ++ "}"

    escape = concatMap $ \char -> case char of
        '"' -> "\\\""
        '\\' -> "\\\\"
        '\n' -> "\\n"
        other -> [other]
