{-# LANGUAGE OverloadedStrings #-}
-- | Streaming renderers for the RSS 2.0 standard.
module Text.RSS.Conduit.Render
  ( -- * Top-level
    renderRssDocument
    -- * Elements
  , renderRssItem
  , renderRssSource
  , renderRssEnclosure
  , renderRssGuid
  , renderRssCloud
  , renderRssCategory
  , renderRssImage
  , renderRssTextInput
  , renderRssSkipDays
  , renderRssSkipHours
  ) where

-- {{{ Imports
import           Text.RSS.Extensions
import           Text.RSS.Lens
import           Text.RSS.Types

import           Control.Monad
import           Data.Conduit
import           Data.Monoid
import           Data.Set               (Set)
import qualified Data.Set               as Set
import           Data.Text              as Text hiding (map)
import           Data.Text.Encoding
import           Data.Time.Clock
import           Data.Time.LocalTime
import           Data.Time.RFC822
import           Data.Version
import           Data.XML.Types
import           Lens.Simple
import           Safe
import           Text.XML.Stream.Render
import           URI.ByteString
-- }}}

-- | Render the top-level @\<rss\>@ element.
renderRssDocument :: Monad m => RenderRssExtension e => RssDocument e -> ConduitT () Event m ()
renderRssDocument d = tag "rss" (attr "version" . pack . showVersion $ d^.documentVersionL) $
  tag "channel" mempty $ do
    textTag "title" $ d^.channelTitleL
    textTag "link" $ renderRssURI $ d^.channelLinkL
    textTag "description" $ d^.channelDescriptionL
    optionalTextTag "copyright" $ d^.channelCopyrightL
    optionalTextTag "language" $ d^.channelLanguageL
    optionalTextTag "managingEditor" $ d^.channelManagingEditorL
    optionalTextTag "webMaster" $ d^.channelWebmasterL
    forM_ (d^.channelPubDateL) $ dateTag "pubDate"
    forM_ (d^.channelLastBuildDateL) $ dateTag "lastBuildDate"
    forM_ (d^..channelCategoriesL) renderRssCategory
    optionalTextTag "generator" $ d^.channelGeneratorL
    forM_ (d^.channelDocsL) $ textTag "docs" . renderRssURI
    forM_ (d^.channelCloudL) renderRssCloud
    forM_ (d^.channelTtlL) $ textTag "ttl" . tshow
    forM_ (d^.channelImageL) renderRssImage
    optionalTextTag "rating" $ d^.channelRatingL
    forM_ (d^.channelTextInputL) renderRssTextInput
    renderRssSkipHours $ d^.channelSkipHoursL
    renderRssSkipDays $ d^.channelSkipDaysL
    forM_ (d^..channelItemsL) renderRssItem
    renderRssChannelExtension $ d^.channelExtensionsL

-- | Render an @\<item\>@ element.
renderRssItem :: Monad m => RenderRssExtension e => RssItem e -> ConduitT () Event m ()
renderRssItem i = tag "item" mempty $ do
  optionalTextTag "title" $ i^.itemTitleL
  forM_ (i^.itemLinkL) $ textTag "link" . renderRssURI
  optionalTextTag "description" $ i^.itemDescriptionL
  optionalTextTag "author" $ i^.itemAuthorL
  forM_ (i^..itemCategoriesL) renderRssCategory
  forM_ (i^.itemCommentsL) $ textTag "comments" . renderRssURI
  forM_ (i^..itemEnclosureL) renderRssEnclosure
  forM_ (i^.itemGuidL) renderRssGuid
  forM_ (i^.itemPubDateL) $ dateTag "pubDate"
  forM_ (i^.itemSourceL) renderRssSource
  renderRssItemExtension $ i^.itemExtensionsL

-- | Render a @\<source\>@ element.
renderRssSource :: (Monad m) => RssSource -> ConduitT () Event m ()
renderRssSource s = tag "source" (attr "url" $ renderRssURI $ s^.sourceUrlL) . content $ s^.sourceNameL

-- | Render an @\<enclosure\>@ element.
renderRssEnclosure :: (Monad m) => RssEnclosure -> ConduitT () Event m ()
renderRssEnclosure e = tag "enclosure" attributes mempty where
  attributes = attr "url" (renderRssURI $ e^.enclosureUrlL)
    <> attr "length" (tshow $ e^.enclosureLengthL)
    <> attr "type" (e^.enclosureTypeL)

-- | Render a @\<guid\>@ element.
renderRssGuid :: (Monad m) => RssGuid -> ConduitT () Event m ()
renderRssGuid (GuidUri u) = tag "guid" (attr "isPermaLink" "true") $ content $ renderRssURI u
renderRssGuid (GuidText t) = tag "guid" mempty $ content t


-- | Render a @\<cloud\>@ element.
renderRssCloud :: Monad m => RssCloud -> ConduitT () Event m ()
renderRssCloud c = tag "cloud" attributes $ return () where
  attributes = attr "domain" domain
    <> optionalAttr "port" port
    <> attr "path" (path <> query <> fragment)
    <> attr "registerProcedure" (c^.cloudRegisterProcedureL)
    <> attr "protocol" (describe $ c^.cloudProtocolL)

  renderUserInfo (Just (UserInfo a b)) = decodeUtf8 a <> ":" <> decodeUtf8 b <> "@"
  renderUserInfo _ = ""
  renderHost (Host h) = decodeUtf8 h
  renderQuery (Query query) = case intercalate "&" $ map (\(a,b) -> decodeUtf8 a <> "=" <> decodeUtf8 b) query of
    "" -> ""
    x  -> "?" <> x

  domain = maybe "" (\a -> renderUserInfo (authorityUserInfo a) <> renderHost (authorityHost a)) $ withRssURI (view authorityL) $ c^.cloudUriL
  port = fmap (pack . show . portNumber) $ authorityPort =<< withRssURI (view authorityL) (c^.cloudUriL)
  path = decodeUtf8 $ withRssURI (view pathL) $ c^.cloudUriL
  query = renderQuery $ withRssURI (view queryL) $ c^.cloudUriL
  fragment = maybe "" decodeUtf8 $ withRssURI (view fragmentL) $ c^.cloudUriL

  describe ProtocolXmlRpc   = "xml-rpc"
  describe ProtocolSoap     = "soap"
  describe ProtocolHttpPost = "http-post"

-- | Render a @\<category\>@ element.
renderRssCategory :: (Monad m) => RssCategory -> ConduitT () Event m ()
renderRssCategory c = tag "category" (attr "domain" $ c^.categoryDomainL) . content $ c^.categoryNameL

-- | Render an @\<image\>@ element.
renderRssImage :: (Monad m) => RssImage -> ConduitT () Event m ()
renderRssImage i = tag "image" mempty $ do
  textTag "url" $ renderRssURI $ i^.imageUriL
  textTag "title" $ i^.imageTitleL
  textTag "link" $ renderRssURI $ i^.imageLinkL
  forM_ (i^.imageHeightL) $ textTag "height" . tshow
  forM_ (i^.imageWidthL) $ textTag "width" . tshow
  optionalTextTag "description" $ i^.imageDescriptionL

-- | Render a @\<textInput\>@ element.
renderRssTextInput :: (Monad m) => RssTextInput -> ConduitT () Event m ()
renderRssTextInput t = tag "textInput" mempty $ do
  textTag "title" $ t^.textInputTitleL
  textTag "description" $ t^.textInputDescriptionL
  textTag "name" $ t^.textInputNameL
  textTag "link" $ renderRssURI $ t^.textInputLinkL

-- | Render a @\<skipDays\>@ element.
renderRssSkipDays :: (Monad m) => Set Day -> ConduitT () Event m ()
renderRssSkipDays s = unless (Set.null s) $ tag "skipDays" mempty $ forM_ s $ textTag "day" . tshow

-- | Render a @\<skipHours\>@ element.
renderRssSkipHours :: (Monad m) => Set Hour -> ConduitT () Event m ()
renderRssSkipHours s = unless (Set.null s) $ tag "skipHour" mempty $ forM_ s $ textTag "hour" . tshow


-- {{{ Utils
tshow :: Show a => a -> Text
tshow = pack . show

textTag :: (Monad m) => Name -> Text -> ConduitT () Event m ()
textTag name = tag name mempty . content

optionalTextTag :: Monad m => Name -> Text -> ConduitT () Event m ()
optionalTextTag name value = unless (Text.null value) $ textTag name value

dateTag :: (Monad m) => Name -> UTCTime -> ConduitT () Event m ()
dateTag name = tag name mempty . content . formatTimeRFC822 . utcToZonedTime utc

renderRssURI :: RssURI -> Text
renderRssURI = decodeUtf8 . withRssURI serializeURIRef'
-- }}}
