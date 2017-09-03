{-# LANGUAGE DataKinds           #-}
{-# LANGUAGE FlexibleInstances   #-}
{-# LANGUAGE OverloadedLists     #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
-- {{{ Imports
import           Text.RSS.Conduit.Parse          as Parser
import           Text.RSS.Conduit.Render         as Renderer
import           Text.RSS.Extensions
import           Text.RSS.Extensions.Atom
import           Text.RSS.Extensions.Content
import           Text.RSS.Extensions.DublinCore
import           Text.RSS.Extensions.Syndication
import           Text.RSS.Lens
import           Text.RSS.Types
import           Text.RSS1.Conduit.Parse         as Parser

import           Arbitrary
import           Conduit
import           Control.Exception.Safe          as Exception
import           Control.Monad
import           Control.Monad.Trans.Resource
import           Data.Char
import           Data.Conduit
import           Data.Conduit.List
import           Data.Default
import           Data.Singletons.Prelude.List
import           Data.Text                       (Text)
import           Data.Time.Calendar
import           Data.Time.LocalTime
import           Data.Version
import           Data.Vinyl.Core
import           Data.XML.Types
import qualified Language.Haskell.HLint          as HLint (hlint)
import           Lens.Simple
import           System.IO
import           System.Timeout
import           Test.Tasty
import           Test.Tasty.HUnit
import           Test.Tasty.QuickCheck
import           Text.Atom.Conduit.Parse
import           Text.Atom.Types
import           Text.XML.Stream.Parse           as XML hiding (choose)
import           Text.XML.Stream.Render
import           URI.ByteString
-- }}}

main :: IO ()
main = defaultMain $ testGroup "Tests"
  [ unitTests
  , properties
  , hlint
  ]

unitTests :: TestTree
unitTests = testGroup "Unit tests"
  [ skipHoursCase
  , skipDaysCase
  , rss1TextInputCase
  , rss2TextInputCase
  , rss1ImageCase
  , rss2ImageCase
  , categoryCase
  , cloudCase
  , guidCase
  , enclosureCase
  , sourceCase
  , rss1ItemCase
  , rss2ItemCase
  , rss1ChannelItemsCase
  , rss1DocumentCase
  , rss2DocumentCase
  , dublinCoreChannelCase
  , dublinCoreItemCase
  , contentItemCase
  , syndicationChannelCase
  , atomChannelCase
  , multipleExtensionsCase
  ]

properties :: TestTree
properties = testGroup "Properties"
  [ roundtripTextInputProperty
  , roundtripImageProperty
  , roundtripCategoryProperty
  , roundtripEnclosureProperty
  , roundtripSourceProperty
  , roundtripGuidProperty
  , roundtripItemProperty
  ]


skipHoursCase :: TestTree
skipHoursCase = testCase "<skipHours> element" $ do
  result <- runResourceT . runConduit $ sourceList input =$= XML.parseText' def =$= force "ERROR" rssSkipHours
  result @?= [Hour 0, Hour 9, Hour 18, Hour 21]
  where input = [ "<skipHours>"
                , "<hour>21</hour>"
                , "<hour>9</hour>"
                , "<hour>0</hour>"
                , "<hour>18</hour>"
                , "<hour>9</hour>"
                , "</skipHours>"
                ]

skipDaysCase :: TestTree
skipDaysCase = testCase "<skipDays> element" $ do
  result <- runResourceT . runConduit $ sourceList input =$= XML.parseText' def =$= force "ERROR" rssSkipDays
  result @?= [Monday, Saturday, Friday]
  where input = [ "<skipDays>"
                , "<day>Monday</day>"
                , "<day>Monday</day>"
                , "<day>Friday</day>"
                , "<day>Saturday</day>"
                , "</skipDays>"
                ]

rss1TextInputCase :: TestTree
rss1TextInputCase = testCase "RSS1 <textinput> element" $ do
  result <- runResourceT . runConduit $ sourceList input =$= XML.parseText' def =$= force "ERROR" rss1TextInput
  result^.textInputTitleL @?= "Search XML.com"
  result^.textInputDescriptionL @?= "Search XML.com's XML collection"
  result^.textInputNameL @?= "s"
  result^.textInputLinkL @=? RssURI (URI (Scheme "http") (Just (Authority Nothing (Host "search.xml.com") Nothing)) "" (Query []) Nothing)
  where input = [ "<textinput xmlns=\"http://purl.org/rss/1.0/\" xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\" rdf:about=\"http://search.xml.com\">"
                , "<title>Search XML.com</title>"
                , "<description>Search XML.com's XML collection</description>"
                , "<name>s</name>"
                , "<link>http://search.xml.com</link>"
                , "</textinput>"
                ]

rss2TextInputCase :: TestTree
rss2TextInputCase = testCase "RSS2 <textInput> element" $ do
  result <- runResourceT . runConduit $ sourceList input =$= XML.parseText' def =$= force "ERROR" rssTextInput
  result^.textInputTitleL @?= "Title"
  result^.textInputDescriptionL @?= "Description"
  result^.textInputNameL @?= "Name"
  result^.textInputLinkL @=? RssURI (URI (Scheme "http") (Just (Authority Nothing (Host "link.ext") Nothing)) "" (Query []) Nothing)
  where input = [ "<textInput>"
                , "<title>Title</title>"
                , "<description>Description</description>"
                , "<name>Name</name>"
                , "<link>http://link.ext</link>"
                , "</textInput>"
                ]

rss1ImageCase :: TestTree
rss1ImageCase = testCase "RSS1 <image> element" $ do
  result <- runResourceT . runConduit $ sourceList input =$= XML.parseText' def =$= force "ERROR" rss1Image
  result^.imageUriL @?= RssURI (URI (Scheme "http") (Just (Authority Nothing (Host "xml.com") Nothing)) "/universal/images/xml_tiny.gif" (Query []) Nothing)
  result^.imageTitleL @?= "XML.com"
  result^.imageLinkL @?= RssURI (URI (Scheme "http") (Just (Authority Nothing (Host "www.xml.com") Nothing)) "" (Query []) Nothing)
  where input = [ "<image xmlns=\"http://purl.org/rss/1.0/\" xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\" rdf:about=\"http://xml.com/universal/images/xml_tiny.gif\">"
                , "<url>http://xml.com/universal/images/xml_tiny.gif</url>"
                , "<title>XML.com</title>"
                , "<ignored>Ignored</ignored>"
                , "<link>http://www.xml.com</link>"
                , "<ignored>Ignored</ignored>"
                , "</image>"
                ]

rss2ImageCase :: TestTree
rss2ImageCase = testCase "RSS2 <image> element" $ do
  result <- runResourceT . runConduit $ sourceList input =$= XML.parseText' def =$= force "ERROR" rssImage
  result^.imageUriL @?= RssURI (URI (Scheme "http") (Just (Authority Nothing (Host "image.ext") Nothing)) "" (Query []) Nothing)
  result^.imageTitleL @?= "Title"
  result^.imageLinkL @?= RssURI (URI (Scheme "http") (Just (Authority Nothing (Host "link.ext") Nothing)) "" (Query []) Nothing)
  result^.imageWidthL @?= Just 100
  result^.imageHeightL @?= Just 200
  result^.imageDescriptionL @?= "Description"
  where input = [ "<image>"
                , "<url>http://image.ext</url>"
                , "<title>Title</title>"
                , "<ignored>Ignored</ignored>"
                , "<link>http://link.ext</link>"
                , "<width>100</width>"
                , "<height>200</height>"
                , "<description>Description</description>"
                , "<ignored>Ignored</ignored>"
                , "</image>"
                ]

categoryCase :: TestTree
categoryCase = testCase "<category> element" $ do
  result <- runResourceT . runConduit $ sourceList input =$= XML.parseText' def =$= force "ERROR" rssCategory
  result @?= RssCategory "Domain" "Name"
  where input = [ "<category domain=\"Domain\">"
                , "Name"
                , "</category>"
                ]

cloudCase :: TestTree
cloudCase = testCase "<cloud> element" $ do
  result1:result2:_ <- runResourceT . runConduit $ sourceList input =$= XML.parseText' def =$= XML.many rssCloud
  result1 @?= RssCloud uri "pingMe" ProtocolSoap
  result2 @?= RssCloud uri "myCloud.rssPleaseNotify" ProtocolXmlRpc
  where input = [ "<cloud domain=\"rpc.sys.com\" port=\"80\" path=\"/RPC2\" registerProcedure=\"pingMe\" protocol=\"soap\"/>"
                , "<cloud domain=\"rpc.sys.com\" port=\"80\" path=\"/RPC2\" registerProcedure=\"myCloud.rssPleaseNotify\" protocol=\"xml-rpc\" />"
                ]
        uri = RssURI (RelativeRef (Just (Authority Nothing (Host "rpc.sys.com") (Just $ Port 80))) "/RPC2" (Query []) Nothing)

guidCase :: TestTree
guidCase = testCase "<guid> element" $ do
  result <- runResourceT . runConduit $ sourceList input =$= XML.parseText' def =$= XML.many rssGuid
  result @?= [GuidUri uri, GuidText "1", GuidText "2"]
  where input = [ "<guid isPermaLink=\"true\">//guid.ext</guid>"
                , "<guid isPermaLink=\"false\">1</guid>"
                , "<guid>2</guid>"
                ]
        uri = RssURI (RelativeRef (Just (Authority Nothing (Host "guid.ext") Nothing)) "" (Query []) Nothing)

enclosureCase :: TestTree
enclosureCase = testCase "<enclosure> element" $ do
  result <- runResourceT . runConduit $ sourceList input =$= XML.parseText' def =$= force "ERROR" rssEnclosure
  result @?= RssEnclosure uri 12216320 "audio/mpeg"
  where input = [ "<enclosure url=\"http://www.scripting.com/mp3s/weatherReportSuite.mp3\" length=\"12216320\" type=\"audio/mpeg\" />"
                ]
        uri = RssURI (URI (Scheme "http") (Just (Authority Nothing (Host "www.scripting.com") Nothing)) "/mp3s/weatherReportSuite.mp3" (Query []) Nothing)

sourceCase :: TestTree
sourceCase = testCase "<source> element" $ do
  result <- runResourceT . runConduit $ sourceList input =$= XML.parseText' def =$= force "ERROR" rssSource
  result @?= RssSource uri "Tomalak's Realm"
  where input = [ "<source url=\"http://www.tomalak.org/links2.xml\">Tomalak's Realm</source>"
                ]
        uri = RssURI (URI (Scheme "http") (Just (Authority Nothing (Host "www.tomalak.org") Nothing)) "/links2.xml" (Query []) Nothing)

rss1ItemCase :: TestTree
rss1ItemCase = testCase "RSS1 <item> element" $ do
  Just result <- runResourceT $ runConduit $ sourceList input =$= XML.parseText' def =$= rss1Item
  result^.itemTitleL @?= "Processing Inclusions with XSLT"
  result^.itemLinkL @?= Just link
  result^.itemDescriptionL @?= "Processing document inclusions with general XML tools can be problematic. This article proposes a way of preserving inclusion information through SAX-based processing."
  result^.itemExtensionsL @?= RssItemExtensions RNil
  where input = [ "<item xmlns=\"http://purl.org/rss/1.0/\""
                , "xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\""
                , "xmlns:dc=\"http://purl.org/dc/elements/1.1/\""
                , "rdf:about=\"http://xml.com/pub/2000/08/09/xslt/xslt.html\" >"
                , "<title>Processing Inclusions with XSLT</title>"
                , "<description>Processing document inclusions with general XML tools can be"
                , " problematic. This article proposes a way of preserving inclusion"
                , " information through SAX-based processing."
                , "</description>"
                , "<link>http://xml.com/pub/2000/08/09/xslt/xslt.html</link>"
                , "<sometag>Some content in unknown tag, should be ignored.</sometag>"
                , "</item>"
                ]
        link = RssURI (URI (Scheme "http") (Just (Authority Nothing (Host "xml.com") Nothing)) "/pub/2000/08/09/xslt/xslt.html" (Query []) Nothing)

rss2ItemCase :: TestTree
rss2ItemCase = testCase "RSS2 <item> element" $ do
  result <- runResourceT . runConduit $ sourceList input =$= XML.parseText' def =$= force "ERROR" rssItem
  result^.itemTitleL @?= "Example entry"
  result^.itemLinkL @?= Just link
  result^.itemDescriptionL @?= "Here is some text containing an interesting description."
  result^.itemGuidL @?= Just (GuidText "7bd204c6-1655-4c27-aeee-53f933c5395f")
  result^.itemExtensionsL @?= RssItemExtensions RNil
  -- isJust (result^.itemPubDate_) @?= True
  where input = [ "<item>"
                , "<title>Example entry</title>"
                , "<description>Here is some text containing an interesting description.</description>"
                , "<link>http://www.example.com/blog/post/1</link>"
                , "<guid isPermaLink=\"false\">7bd204c6-1655-4c27-aeee-53f933c5395f</guid>"
                , "<pubDate>Sun, 06 Sep 2009 16:20:00 +0000</pubDate>"
                , "<sometag>Some content in unknown tag, should be ignored.</sometag>"
                , "</item>"
                ]
        link = RssURI (URI (Scheme "http") (Just (Authority Nothing (Host "www.example.com") Nothing)) "/blog/post/1" (Query []) Nothing)


rss1ChannelItemsCase :: TestTree
rss1ChannelItemsCase = testCase "RSS1 <items> element" $ do
  result <- runResourceT . runConduit $ sourceList input =$= XML.parseText' def =$= force "ERROR" rss1ChannelItems
  result @?= [resource1, resource2]
  where input = [ "<items xmlns=\"http://purl.org/rss/1.0/\" xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\">"
                , "<rdf:Seq>"
                , "<rdf:li rdf:resource=\"http://xml.com/pub/2000/08/09/xslt/xslt.html\" />"
                , "<rdf:li rdf:resource=\"http://xml.com/pub/2000/08/09/rdfdb/index.html\" />"
                , "</rdf:Seq>"
                , "</items>"
                ]
        resource1 = "http://xml.com/pub/2000/08/09/xslt/xslt.html"
        resource2 = "http://xml.com/pub/2000/08/09/rdfdb/index.html"

rss1DocumentCase :: TestTree
rss1DocumentCase = testCase "<rdf> element" $ do
  Just result <- runResourceT . runConduit $ sourceList input =$= XML.parseText' def =$= rss1Document
  result^.documentVersionL @?= Version [1] []
  result^.channelTitleL @?= "XML.com"
  result^.channelDescriptionL @?= "XML.com features a rich mix of information and services for the XML community."
  result^.channelLinkL @?= link
  result^?channelImageL._Just.imageTitleL @?= Just "XML.com"
  result^?channelImageL._Just.imageLinkL @?= Just imageLink
  result^?channelImageL._Just.imageUriL @?= Just imageUri
  length (result^..channelItemsL) @?= 2
  result^?channelTextInputL._Just.textInputTitleL @?= Just "Search XML.com"
  result^?channelTextInputL._Just.textInputDescriptionL @?= Just "Search XML.com's XML collection"
  result^?channelTextInputL._Just.textInputNameL @?= Just "s"
  result^?channelTextInputL._Just.textInputLinkL @?= Just textInputLink
  result^.channelExtensionsL @?= RssChannelExtensions RNil
  where input = [ "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"
                , "<rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\" xmlns=\"http://purl.org/rss/1.0/\">"
                , "<channel rdf:about=\"http://www.xml.com/xml/news.rss\">"
                , "<title>XML.com</title>"
                , "<link>http://xml.com/pub</link>"
                , "<description>XML.com features a rich mix of information and services for the XML community.</description>"
                , "<image rdf:resource=\"http://xml.com/universal/images/xml_tiny.gif\" />"
                , "<items>"
                , "<rdf:Seq>"
                , "<rdf:li rdf:resource=\"http://xml.com/pub/2000/08/09/xslt/xslt.html\" />"
                , "<rdf:li rdf:resource=\"http://xml.com/pub/2000/08/09/rdfdb/index.html\" />"
                , "</rdf:Seq>"
                , "</items>"
                , "</channel>"
                , "<image rdf:about=\"http://xml.com/universal/images/xml_tiny.gif\">"
                , "<title>XML.com</title>"
                , "<link>http://www.xml.com</link>"
                , "<url>http://xml.com/universal/images/xml_tiny.gif</url>"
                , "</image>"
                , "<item rdf:about=\"http://xml.com/pub/2000/08/09/xslt/xslt.html\">"
                , "<title>Processing Inclusions with XSLT</title>"
                , "<link>http://xml.com/pub/2000/08/09/xslt/xslt.html</link>"
                , "<description>Processing document inclusions with general XML tools can be problematic. This article proposes a way of preserving inclusion information through SAX-based processing.</description>"
                , "</item>"
                , "<item rdf:about=\"http://xml.com/pub/2000/08/09/xslt/xslt.html\">"
                , "<title>Putting RDF to Work</title>"
                , "<link>http://xml.com/pub/2000/08/09/rdfdb/index.html</link>"
                , "<description>Tool and API support for the Resource Description Framework is slowly coming of age. Edd Dumbill takes a look at RDFDB, one of the most exciting new RDF toolkits.</description>"
                , "</item>"
                , "<textinput rdf:about=\"http://search.xml.com\">"
                , "<title>Search XML.com</title>"
                , "<description>Search XML.com's XML collection</description>"
                , "<name>s</name>"
                , "<link>http://search.xml.com</link>"
                , "</textinput>"
                , "</rdf:RDF>"
                ]
        link = RssURI (URI (Scheme "http") (Just (Authority Nothing (Host "xml.com") Nothing)) "/pub" (Query []) Nothing)
        imageLink = RssURI (URI (Scheme "http") (Just (Authority Nothing (Host "www.xml.com") Nothing)) "" (Query []) Nothing)
        imageUri = RssURI (URI (Scheme "http") (Just (Authority Nothing (Host "xml.com") Nothing)) "/universal/images/xml_tiny.gif" (Query []) Nothing)
        textInputLink = RssURI (URI (Scheme "http") (Just (Authority Nothing (Host "search.xml.com") Nothing)) "" (Query []) Nothing)


rss2DocumentCase :: TestTree
rss2DocumentCase = testCase "<rss> element" $ do
  Just result <- runResourceT . runConduit $ sourceList input =$= XML.parseText' def =$= rssDocument
  result^.documentVersionL @?= Version [2] []
  result^.channelTitleL @?= "RSS Title"
  result^.channelDescriptionL @?= "This is an example of an RSS feed"
  result^.channelLinkL @?= link
  result^.channelTtlL @?= Just 1800
  result^.channelExtensionsL @?= RssChannelExtensions RNil
  length (result^..channelItemsL) @?= 1
  where input = [ "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"
                , "<rss version=\"2.0\">"
                , "<channel>"
                , "<title>RSS Title</title>"
                , "<description>This is an example of an RSS feed</description>"
                , "<link>http://www.example.com/main.html</link>"
                , "<lastBuildDate>Mon, 06 Sep 2010 00:01:00 +0000 </lastBuildDate>"
                , "<pubDate>Sun, 06 Sep 2009 16:20:00 +0000</pubDate>"
                , "<ttl>1800</ttl>"
                , "<item>"
                , "<title>Example entry</title>"
                , "<description>Here is some text containing an interesting description.</description>"
                , "<link>http://www.example.com/blog/post/1</link>"
                , "<guid isPermaLink=\"true\">7bd204c6-1655-4c27-aeee-53f933c5395f</guid>"
                , "<pubDate>Sun, 06 Sep 2009 16:20:00 +0000</pubDate>"
                , "</item>"
                , "</channel>"
                , "</rss>"
                ]
        link = RssURI (URI (Scheme "http") (Just (Authority Nothing (Host "www.example.com") Nothing)) "/main.html" (Query []) Nothing)


dublinCoreChannelCase :: TestTree
dublinCoreChannelCase = testCase "Dublin Core <channel> extension" $ do
  Just result <- runResourceT . runConduit $ sourceList input =$= XML.parseText' def =$= rssDocument
  result^.channelExtensionsL @?= RssChannelExtensions (DublinCoreChannel dublinCoreElement :& RNil)
  where input = [ "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"
                , "<rss xmlns:dc=\"http://purl.org/dc/elements/1.1/\" version=\"2.0\">"
                , "<channel>"
                , "<title>RSS Title</title>"
                , "<link>http://xml.com/pub/2000/08/09/xslt/xslt.html</link>"
                , "<dc:publisher>The O'Reilly Network</dc:publisher>"
                , "<dc:creator>Rael Dornfest (mailto:rael@oreilly.com)</dc:creator>"
                , "<dc:date>2000-01-01T12:00:00+00:00</dc:date>"
                , "<dc:language>EN</dc:language>"
                , "<dc:rights>Copyright © 2000 O'Reilly &amp; Associates, Inc.</dc:rights>"
                , "<dc:subject>XML</dc:subject>"
                , "</channel>"
                , "</rss>"
                ]
        dublinCoreElement = mkDcMetaData
          { elementCreator = "Rael Dornfest (mailto:rael@oreilly.com)"
          , elementDate = Just date
          , elementLanguage = "EN"
          , elementPublisher = "The O'Reilly Network"
          , elementRights = "Copyright © 2000 O'Reilly & Associates, Inc."
          , elementSubject = "XML"
          }
        date = localTimeToUTC utc $ LocalTime (fromGregorian 2000 1 1) (TimeOfDay 12 0 0)

dublinCoreItemCase :: TestTree
dublinCoreItemCase = testCase "Dublin Core <item> extension" $ do
  Just result <- runResourceT . runConduit $ sourceList input =$= XML.parseText' def =$= rssItem
  result^.itemExtensionsL @?= RssItemExtensions (DublinCoreItem dublinCoreElement :& RNil)
  where input = [ "<item xmlns:dc=\"http://purl.org/dc/elements/1.1/\">"
                , "<title>Example entry</title>"
                , "<dc:description>XML is placing increasingly heavy loads on the existing technical "
                , "infrastructure of the Internet.</dc:description>"
                , "<dc:language>EN</dc:language>"
                , "<dc:publisher>The O'Reilly Network</dc:publisher>"
                , "<dc:creator>Simon St.Laurent (mailto:simonstl@simonstl.com)</dc:creator>"
                , "<dc:date>2000-01-01T12:00:00+00:00</dc:date>"
                , "<dc:rights>Copyright © 2000 O'Reilly &amp; Associates, Inc.</dc:rights>"
                , "<dc:subject>XML</dc:subject>"
                , "</item>"
                ]
        dublinCoreElement = mkDcMetaData
          { elementCreator = "Simon St.Laurent (mailto:simonstl@simonstl.com)"
          , elementDate = Just date
          , elementLanguage = "EN"
          , elementDescription = "XML is placing increasingly heavy loads on the existing technical infrastructure of the Internet."
          , elementPublisher = "The O'Reilly Network"
          , elementRights = "Copyright © 2000 O'Reilly & Associates, Inc."
          , elementSubject = "XML"
          }
        date = localTimeToUTC utc $ LocalTime (fromGregorian 2000 1 1) (TimeOfDay 12 0 0)

contentItemCase :: TestTree
contentItemCase = testCase "Content <item> extension" $ do
  Just result <- runResourceT . runConduit $ sourceList input =$= XML.parseText' def =$= rssItem
  result^.itemExtensionsL @?= RssItemExtensions (ContentItem "<p>What a <em>beautiful</em> day!</p>" :& RNil)
  where input = [ "<item xmlns:content=\"http://purl.org/rss/1.0/modules/content/\">"
                , "<title>Example entry</title>"
                , "<content:encoded><![CDATA[<p>What a <em>beautiful</em> day!</p>]]></content:encoded>"
                , "</item>"
                ]

syndicationChannelCase :: TestTree
syndicationChannelCase = testCase "Syndication <channel> extension" $ do
  Just result <- runResourceT . runConduit $ sourceList input =$= XML.parseText' def =$= rssDocument
  result^.channelExtensionsL @?= RssChannelExtensions (SyndicationChannel syndicationInfo :& RNil)
  where input = [ "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"
                , "<rss xmlns:sy=\"http://purl.org/rss/1.0/modules/syndication/\" version=\"2.0\">"
                , "<channel>"
                , "<title>RSS Title</title>"
                , "<link>http://xml.com/pub/2000/08/09/xslt/xslt.html</link>"
                , "<sy:updatePeriod>hourly</sy:updatePeriod>"
                , "<sy:updateFrequency>2</sy:updateFrequency>"
                , "<sy:updateBase>2000-01-01T12:00:00+00:00</sy:updateBase>"
                , "</channel>"
                , "</rss>"
                ]
        syndicationInfo = mkSyndicationInfo
          { updatePeriod = Just Hourly
          , updateFrequency = Just 2
          , updateBase = Just date
          }
        date = localTimeToUTC utc $ LocalTime (fromGregorian 2000 1 1) (TimeOfDay 12 0 0)

atomChannelCase :: TestTree
atomChannelCase = testCase "Atom <channel> extension" $ do
  Just result <- runResourceT . runConduit $ sourceList input =$= XML.parseText' def =$= rssDocument
  result^.channelExtensionsL @?= RssChannelExtensions (AtomChannel (Just link) :& RNil)
  where input = [ "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"
                , "<rss xmlns:atom=\"http://www.w3.org/2005/Atom\" version=\"2.0\">"
                , "<channel>"
                , "<title>RSS Title</title>"
                , "<link>http://xml.com/pub/2000/08/09/xslt/xslt.html</link>"
                , "<atom:link href=\"http://dallas.example.com/rss.xml\" rel=\"self\" type=\"application/rss+xml\" />"
                , "</channel>"
                , "</rss>"
                ]
        uri = AtomURI (URI (Scheme "http") (Just (Authority Nothing (Host "dallas.example.com") Nothing)) "/rss.xml" (Query []) Nothing)
        link = AtomLink uri "self" "application/rss+xml" mempty mempty mempty

multipleExtensionsCase :: TestTree
multipleExtensionsCase = testCase "Multiple extensions" $ do
  Just result <- runResourceT . runConduit $ sourceList input =$= XML.parseText' def =$= rssItem
  result^.itemExtensionsL @?= RssItemExtensions (ContentItem "<p>What a <em>beautiful</em> day!</p>" :& AtomItem (Just link) :& RNil)
  where input = [ "<item xmlns:content=\"http://purl.org/rss/1.0/modules/content/\""
                , " xmlns:atom=\"http://www.w3.org/2005/Atom\">"
                , "<title>Example entry</title>"
                , "<atom:link href=\"http://dallas.example.com/rss.xml\" rel=\"self\" type=\"application/rss+xml\" />"
                , "<content:encoded><![CDATA[<p>What a <em>beautiful</em> day!</p>]]></content:encoded>"
                , "</item>"
                ]
        uri = AtomURI (URI (Scheme "http") (Just (Authority Nothing (Host "dallas.example.com") Nothing)) "/rss.xml" (Query []) Nothing)
        link = AtomLink uri "self" "application/rss+xml" mempty mempty mempty


hlint :: TestTree
hlint = testCase "HLint check" $ do
  result <- HLint.hlint [ "test/", "Text/" ]
  Prelude.null result @?= True


roundtripTextInputProperty :: TestTree
roundtripTextInputProperty = testProperty "parse . render = id (RssTextInput)" $ \t -> either (const False) (t ==) (runConduit $ renderRssTextInput t =$= force "ERROR" rssTextInput)

roundtripImageProperty :: TestTree
roundtripImageProperty = testProperty "parse . render = id (RssImage)" $ \t -> either (const False) (t ==) (runConduit $ renderRssImage t =$= force "ERROR" rssImage)

roundtripCategoryProperty :: TestTree
roundtripCategoryProperty = testProperty "parse . render = id (RssCategory)" $ \t -> either (const False) (t ==) (runConduit $ renderRssCategory t =$= force "ERROR" rssCategory)

roundtripEnclosureProperty :: TestTree
roundtripEnclosureProperty = testProperty "parse . render = id (RssEnclosure)" $ \t -> either (const False) (t ==) (runConduit $ renderRssEnclosure t =$= force "ERROR" rssEnclosure)

roundtripSourceProperty :: TestTree
roundtripSourceProperty = testProperty "parse . render = id (RssSource)" $ \t -> either (const False) (t ==) (runConduit $ renderRssSource t =$= force "ERROR" rssSource)

roundtripGuidProperty :: TestTree
roundtripGuidProperty = testProperty "parse . render = id (RssGuid)" $ \t -> either (const False) (t ==) (runConduit $ renderRssGuid t =$= force "ERROR" rssGuid)

roundtripItemProperty :: TestTree
roundtripItemProperty = testProperty "parse . render = id (RssItem)" $ \(t :: RssItem '[]) -> either (const False) (t ==) (runConduit $ renderRssItem t =$= force "ERROR" rssItem)


letter = choose ('a', 'z')
digit = arbitrary `suchThat` isDigit
alphaNum = oneof [letter, digit]
