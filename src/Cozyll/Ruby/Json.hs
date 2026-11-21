{- | The JSON helpers shared by the ruby modules: one decoder that tolerates a
UTF-8 BOM, and labelled accessors that turn a wrong shape into one message.
-}
module Cozyll.Ruby.Json (
    decodeJson,
    asObject,
    asArray,
    required,
    asText,
    asInt,
    asMaybeInt,
) where

import Data.Aeson (Value (..), eitherDecodeStrict')
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap (KeyMap)
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Bifunctor (first)
import Data.ByteString (ByteString)
import Data.ByteString qualified as BS
import Data.Foldable (toList)
import Data.Scientific (toBoundedInteger)
import Data.Text (Text)
import Data.Text qualified as T

-- | Decodes JSON, tolerating a UTF-8 BOM
decodeJson :: ByteString -> Either String Value
decodeJson = first show . eitherDecodeStrict' . stripBom

-- | Drops a leading UTF-8 BOM
stripBom :: ByteString -> ByteString
stripBom bytes
    | BS.take 3 bytes == BS.pack [0xEF, 0xBB, 0xBF] = BS.drop 3 bytes
    | otherwise = bytes

-- | Requires a JSON object, failing with @label must be an object@
asObject :: String -> Value -> Either String (KeyMap Value)
asObject _ (Object o) = Right o
asObject label _ = Left (label ++ " must be an object")

-- | Requires a JSON array, failing with @label must be an array@
asArray :: String -> Value -> Either String [Value]
asArray _ (Array a) = Right (toList a)
asArray label _ = Left (label ++ " must be an array")

-- | Requires a key of an object, failing with @missing field label@
required :: String -> KeyMap Value -> Either String Value
required name obj = maybe (Left ("missing field " ++ name)) Right (KeyMap.lookup (Key.fromText (T.pack name)) obj)

-- | Requires a JSON string, failing with @label must be a string@
asText :: String -> Value -> Either String Text
asText _ (String t) = Right t
asText label _ = Left (label ++ " must be a string")

-- | Requires a JSON integer, failing with @label must be an integer@
asInt :: String -> Value -> Either String Int
asInt label (Number n) = maybe (Left (label ++ " must be an integer")) Right (toBoundedInteger n)
asInt label _ = Left (label ++ " must be an integer")

-- | An optional JSON integer: @null@ is 'Nothing'
asMaybeInt :: String -> Value -> Either String (Maybe Int)
asMaybeInt _ Null = Right Nothing
asMaybeInt label v = Just <$> asInt label v
