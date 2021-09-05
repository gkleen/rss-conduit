{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs             #-}
-- | 'Arbitrary' instances used by RSS types.
module Arbitrary (module Arbitrary) where

-- {{{ Imports
import           Text.RSS.Extensions.Atom
import           Text.RSS.Extensions.Content
import           Text.RSS.Extensions.DublinCore
import           Text.RSS.Extensions.Syndication
import           Text.RSS.Types

import           Data.ByteString                 (ByteString)
import           Data.Char
import           Data.Maybe
import           Data.Text                       (Text, find, pack)
import           Data.Text.Encoding
import           Data.Time.Clock
import           Data.Version
import           GHC.Generics
import           Test.QuickCheck
import           Test.QuickCheck.Instances       ()
import           Text.Atom.Types
import           URI.ByteString
-- }}}


-- | Reasonable enough 'URI' generator.
instance Arbitrary (URIRef Absolute) where
  arbitrary = URI <$> arbitrary <*> arbitrary <*> genPath <*> arbitrary <*> (Just <$> genFragment)
  shrink (URI a b c d e) = URI <$> shrink a <*> shrink b <*> shrink c <*> shrink d <*> shrink e

-- | Reasonable enough 'RelativeRef' generator.
instance Arbitrary (URIRef Relative) where
  arbitrary = RelativeRef <$> arbitrary <*> genPath <*> arbitrary <*> (Just <$> genFragment)
  shrink (RelativeRef a b c d) = RelativeRef <$> shrink a <*> shrink b <*> shrink c <*> shrink d

-- | Reasonable enough 'Authority' generator.
instance Arbitrary Authority where
  arbitrary = Authority <$> arbitrary <*> arbitrary <*> arbitrary
  shrink = genericShrink

genFragment :: Gen ByteString
genFragment = encodeUtf8 . pack <$> listOf1 genAlphaNum

instance Arbitrary Host where
  arbitrary = Host . encodeUtf8 . pack <$> listOf1 genAlphaNum
  shrink = genericShrink

genPath :: Gen ByteString
genPath = encodeUtf8 . pack . ("/" ++) <$> listOf1 genAlphaNum

instance Arbitrary Port where
  arbitrary = do
    Positive port <- arbitrary
    return $ Port port

instance Arbitrary Query where
  arbitrary = do
    a <- listOf1 (encodeUtf8 . pack <$> listOf1 genAlphaNum)
    b <- listOf1 (oneof [pure Nothing, Just . encodeUtf8 . pack <$> listOf1 genAlphaNum])
    return $ Query $ Prelude.zip a b
  shrink = genericShrink

instance Arbitrary Scheme where
  arbitrary = Scheme . encodeUtf8 . pack <$> listOf1 (choose('a', 'z'))
  shrink = genericShrink

instance Arbitrary UserInfo where
  arbitrary = do
    a <- encodeUtf8 . pack <$> listOf1 genAlphaNum
    b <- encodeUtf8 . pack <$> listOf1 genAlphaNum
    return $ UserInfo a b
  shrink = genericShrink


instance Arbitrary RssCategory where
  arbitrary = RssCategory <$> (pack <$> listOf genAlphaNum) <*> (pack <$> listOf genAlphaNum)

instance Arbitrary CloudProtocol where
  arbitrary = oneof $ map pure [ProtocolXmlRpc, ProtocolSoap, ProtocolHttpPost]

instance Arbitrary RssCloud where
  arbitrary = RssCloud <$> arbitrary <*> (pack <$> listOf genAlphaNum) <*> arbitrary

instance Arbitrary RssEnclosure where
  arbitrary = do
    Positive l <- arbitrary
    RssEnclosure <$> arbitrary <*> pure l <*> (pack <$> listOf genAlphaNum)

instance Arbitrary RssGuid where
  arbitrary = oneof [GuidText <$> (pack <$> listOf genAlphaNum), GuidUri <$> arbitrary]

instance Arbitrary RssImage where
  arbitrary = RssImage <$> arbitrary <*> (pack <$> listOf genAlphaNum) <*> arbitrary <*> fmap (fmap abs) arbitrary <*> fmap (fmap abs) arbitrary <*> (pack <$> listOf genAlphaNum)

instance Arbitrary (RssItem NoExtensions) where
  arbitrary = RssItem
    <$> (pack <$> listOf genAlphaNum)
    <*> arbitrary
    <*> (pack <$> listOf genAlphaNum)
    <*> (pack <$> listOf genAlphaNum)
    <*> arbitrary
    <*> arbitrary
    <*> arbitrary
    <*> arbitrary
    <*> oneof [Just <$> genTime, pure Nothing]
    <*> arbitrary
    <*> pure NoItemExtensions

instance Arbitrary RssSource where
  arbitrary = RssSource <$> arbitrary <*> (pack <$> listOf genAlphaNum)

instance Arbitrary RssTextInput where
  arbitrary = RssTextInput <$> (pack <$> listOf genAlphaNum) <*> (pack <$> listOf genAlphaNum) <*> (pack <$> listOf genAlphaNum) <*> arbitrary

instance Arbitrary (RssDocument NoExtensions) where
  arbitrary = RssDocument
    <$> arbitrary
    <*> arbitrary
    <*> arbitrary
    <*> arbitrary
    <*> vectorOf 1 arbitrary
    <*> arbitrary
    <*> arbitrary
    <*> arbitrary
    <*> arbitrary
    <*> oneof [Just <$> genTime, pure Nothing]
    <*> oneof [Just <$> genTime, pure Nothing]
    <*> arbitrary
    <*> arbitrary
    <*> arbitrary
    <*> arbitrary
    <*> arbitrary
    <*> arbitrary
    <*> arbitrary
    <*> arbitrary
    <*> arbitrary
    <*> arbitrary
    <*> pure NoChannelExtensions

instance Arbitrary Day where
  arbitrary = arbitraryBoundedEnum
  shrink = genericShrink

instance Arbitrary Hour where
  arbitrary = Hour <$> suchThat arbitrary (\x -> x >= 0 && x < 24)

-- | Alpha-numeric generator.
genAlphaNum :: Gen Char
genAlphaNum = oneof [choose('a', 'z'), arbitrary `suchThat` isDigit]

-- | Generates 'UTCTime' with rounded seconds.
genTime :: Gen UTCTime
genTime = do
  (UTCTime d s) <- arbitrary
  return $ UTCTime d $ fromIntegral (round s :: Int)

instance Arbitrary RssURI where
  arbitrary = oneof [RssURI <$> (arbitrary :: Gen (URIRef Absolute)), RssURI <$> (arbitrary :: Gen (URIRef Relative))]
  shrink (RssURI a@URI{})         = RssURI <$> shrink a
  shrink (RssURI a@RelativeRef{}) = RssURI <$> shrink a

instance Arbitrary (RssChannelExtension NoExtensions) where
  arbitrary = pure NoChannelExtensions

instance Arbitrary (RssItemExtension NoExtensions) where
  arbitrary = pure NoItemExtensions

instance Arbitrary DcMetaData where
  arbitrary = DcMetaData
    <$> arbitrary
    <*> arbitrary
    <*> arbitrary
    <*> oneof [Just <$> genTime, pure Nothing]
    <*> arbitrary
    <*> arbitrary
    <*> arbitrary
    <*> arbitrary
    <*> arbitrary
    <*> arbitrary
    <*> arbitrary
    <*> arbitrary
    <*> arbitrary
    <*> arbitrary
    <*> arbitrary

instance Arbitrary (RssChannelExtension a) => Arbitrary (RssChannelExtension (DublinCoreModule a)) where
  arbitrary = DublinCoreChannel <$> arbitrary <*> arbitrary

instance Arbitrary SyndicationPeriod where
  arbitrary = arbitraryBoundedEnum
  shrink = genericShrink

instance Arbitrary SyndicationInfo where
  arbitrary = SyndicationInfo
    <$> arbitrary
    <*> arbitrary
    <*> oneof [Just <$> genTime, pure Nothing]

instance Arbitrary (RssChannelExtension a) => Arbitrary (RssChannelExtension (SyndicationModule a)) where
  arbitrary = SyndicationChannel <$> arbitrary <*> arbitrary

instance Arbitrary AtomURI where
  arbitrary = oneof [AtomURI <$> (arbitrary :: Gen (URIRef Absolute)), AtomURI <$> (arbitrary :: Gen (URIRef Relative))]

instance Arbitrary AtomLink where
  arbitrary = AtomLink <$> arbitrary <*> arbitrary <*> arbitrary <*> arbitrary <*> arbitrary <*> arbitrary

instance Arbitrary (RssChannelExtension a) => Arbitrary (RssChannelExtension (AtomModule a)) where
  arbitrary = AtomChannel <$> arbitrary <*> arbitrary

instance Arbitrary (RssItemExtension a) => Arbitrary (RssItemExtension (ContentModule a)) where
  arbitrary = ContentItem <$> arbitrary <*> arbitrary
