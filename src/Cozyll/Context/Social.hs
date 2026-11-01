-- | The socials data file, as the lists read by the social templates
module Cozyll.Context.Social (socialMediaContext) where

import Cozyll.Config (SiteConfig, mediaDir, socialsFile)
import Cozyll.Content (requireSocials)
import Cozyll.Domain.Social (Social (..))
import Data.List (stripPrefix)
import Data.Maybe (fromMaybe)
import Hakyll (
    Compiler,
    Context,
    Identifier,
    Item (Item, itemBody),
    field,
    fromFilePath,
    listField,
    load,
    toFilePath,
 )
import System.FilePath.Posix ((</>))

-- | The social accounts, in the lists read by the social templates
socialMediaContext :: SiteConfig -> Context a
socialMediaContext cfg = socialsField "socials" socialShow
  where
    socialsField name keep =
        listField name (socialContext $ mediaDir cfg) $ listItems (socialsFile cfg) requireSocials keep

-- | A social account's fields, as read by the social templates
socialContext :: FilePath -> Context Social
socialContext mediaDir' =
    iconContext mediaDir' "images/icons/social/" socialIcon
        <> field "href" (return . socialHref . itemBody)
        <> field "username" (return . socialUsername . itemBody)

-- | The SVG named by each item's icon: @iconHref@ is its URL, @iconRaw@ its markup
iconContext :: FilePath -> String -> (a -> String) -> Context a
iconContext mediaDir' prefix getIcon =
    field "iconHref" (return . hrefOf . itemBody)
        <> field "iconRaw" (rawOf . itemBody)
  where
    hrefOf item = prefix ++ getIcon item ++ ".svg"
    sourceOf item = mediaDir' </> fromMaybe (hrefOf item) (stripPrefix "images/" (hrefOf item))
    rawOf item = itemBody <$> load (fromFilePath $ sourceOf item)

-- | Loads a YAML list file as one item per kept element
listItems :: Identifier -> (Item String -> Compiler [a]) -> (a -> Bool) -> Compiler [Item a]
listItems path require keep = do
    file <- load path
    items <- require file
    let kept = filter keep items
    return [Item (fromFilePath $ toFilePath path ++ "#" ++ show n) item | (n, item) <- zip [0 :: Int ..] kept]
