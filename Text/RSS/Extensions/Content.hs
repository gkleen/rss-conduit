{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE KindSignatures    #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes        #-}
{-# LANGUAGE TypeFamilies      #-}
-- | __Content__ extension for RSS.
-- Cf specification at <http://web.resource.org/rss/1.0/modules/content/>.
--
-- This implementation corresponds to the /updated syntax/ from the specification.
module Text.RSS.Extensions.Content
  ( -- * Types
    ContentModule(..)
  , RssChannelExtension(ContentChannel)
  , RssItemExtension(ContentItem)
    -- * Parsers
  , contentEncoded
    -- * Misc
  , namespacePrefix
  , namespaceURI
  ) where

-- {{{ Imports
import           Text.RSS.Extensions
import           Text.RSS.Types

import           Conduit                hiding (throwM)
import           Control.Exception.Safe as Exception
import           Data.Maybe
import           Data.Singletons
import           Data.Text
import           Data.XML.Types
import           GHC.Generics
import           Text.XML.Stream.Parse
import           URI.ByteString
-- }}}

-- | __Content__ tag type.
data ContentModule :: *

data instance Sing ContentModule = SContentModule

instance SingI ContentModule where sing = SContentModule

instance ParseRssExtension ContentModule where
  parseRssChannelExtension = pure ContentChannel
  parseRssItemExtension    = ContentItem <$> (manyYield' contentEncoded =$= headDefC mempty)


data instance RssChannelExtension ContentModule = ContentChannel deriving(Eq, Generic, Ord, Show)
data instance RssItemExtension ContentModule = ContentItem Text deriving(Eq, Generic, Ord, Show)


-- | XML prefix is @content@.
namespacePrefix :: Text
namespacePrefix = "content"

-- | XML namespace is @http://purl.org/rss/1.0/modules/content/@
namespaceURI :: URIRef Absolute
namespaceURI = uri where Right uri = parseURI laxURIParserOptions "http://purl.org/rss/1.0/modules/content/"

contentName :: Text -> Name
contentName string = Name string (Just "http://purl.org/rss/1.0/modules/content/") (Just namespacePrefix)

-- | Parse a @\<content:encoded\>@ element.
contentEncoded :: MonadThrow m => ConduitM Event o m (Maybe Text)
contentEncoded = tagIgnoreAttrs (matching (== contentName "encoded")) content
