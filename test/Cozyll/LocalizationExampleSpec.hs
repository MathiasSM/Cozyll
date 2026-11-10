{- | Guards the localization example against template drift: every
@$t("id")$@ id used by the shipped templates must have an entry in
@schema\/example.localization.yaml@.
-}
module Cozyll.LocalizationExampleSpec (tests) where

import Data.Aeson (Value (..))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.List (isSuffixOf)
import Data.Yaml (ParseException, decodeFileEither)
import System.Directory (getCurrentDirectory, listDirectory)
import System.FilePath ((</>))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, assertFailure, testCase)

tests :: TestTree
tests =
    testGroup
        "Localization example"
        [ testCase "defines every id the templates consume" $ do
            root <- getCurrentDirectory
            used <- templateTranslationIds (root </> "templates")
            defined <- exampleTranslationIds (root </> "schema" </> "example.localization.yaml")
            let missing = filter (`notElem` defined) used
            assertBool
                ("missing from schema/example.localization.yaml: " ++ show missing)
                (null missing)
        , testCase "defines the reserved og:locale key" $ do
            root <- getCurrentDirectory
            defined <- exampleTranslationIds (root </> "schema" </> "example.localization.yaml")
            assertBool
                "_ogLocaleDefaultRegion is missing from schema/example.localization.yaml"
                ("_ogLocaleDefaultRegion" `elem` defined)
        ]

-- | Every @$t("id")$@ id in the top-level @templates/*.html@ and @templates/*.xml@ files.
templateTranslationIds :: FilePath -> IO [String]
templateTranslationIds dir = do
    names <- listDirectory dir
    concat <$> mapM (fmap translationIds . readFile . (dir </>)) (filter isTemplate names)
  where
    isTemplate name = ".html" `isSuffixOf` name || ".xml" `isSuffixOf` name

-- | Extract the id from the exact @$t("id")$@ syntax used by the templates.
translationIds :: String -> [String]
translationIds = go
  where
    go [] = []
    go ('$' : 't' : '(' : '"' : rest) =
        case break (== '"') rest of
            (textId, '"' : ')' : '$' : more) -> textId : go more
            _ -> go rest
    go (_ : rest) = go rest

-- | The top-level ids of the example localization file.
exampleTranslationIds :: FilePath -> IO [String]
exampleTranslationIds path = do
    parsed <- (decodeFileEither path :: IO (Either ParseException Value))
    case parsed of
        Left err -> assertFailure ("cannot parse " ++ path ++ ": " ++ show err) >> pure []
        Right (Object ids) -> pure (map Key.toString (KeyMap.keys ids))
        Right _ -> assertFailure (path ++ " is not an object") >> pure []
