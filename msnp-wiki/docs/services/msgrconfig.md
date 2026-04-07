# Introduction
The Messenger Config service (MsgrConfig) is a SOAP (XML) and HTTP Web Service.
Introduced with [MSNP9](../versions/msnp9.md).

Defines various configuration options for the Official Client. Replaces `svcs.microsoft.com`.

It's default URL is `http://config.messenger.msn.com/Config/MsgrConfig.asmx`.

This service does not require Passport authentication.

# Actions

## GetClientConfig

### Client/Request

#### As a SOAP Action / POST request
In the HTTP headers, this is defined:

`SOAPAction: "http://www.msn.com/webservices/Messenger/Client/GetClientConfig"`

The main body is the following:
```xml
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xmlns:xsd="http://www.w3.org/2001/XMLSchema"
	xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
>
	<soap:Body>
		<GetClientConfig
			xmlns='http://www.msn.com/webservices/Messenger/Client'
		>
			<clientinfo>
				<Country>US</Country>
				<CLCID>0809</CLCID>
				<PLCID>0409</PLCID>
				<GeoID>242</GeoID>
			</clientinfo>
		</GetClientConfig>
	</soap:Body>
</soap:Envelope>
```

Where `<Country>` is the ISO 3166-1 alpha-2 of the binary you are using.  
Where `<CLCID>` is the system's language code in unprefixed hexadecimal.  
Where `<PLCID>` is the binary's language code in unprefixed hexadecimal.  
Where `<GeoID>` is the system's geographic location in decimal. 

#### As query parameters
```http
GET http://config.messenger.msn.com/Config/MsgrConfig.asmx
	?op=GetClientConfig
	&Country=US
	&CLCID=0809
	&PLCID=0409
	&GeoID=242
	&ver=8.5.1302
	HTTP/1.1
```

Where `op` is always `GetClientConfig`.  
Where `Country` is the ISO 3166-1 alpha-2 of the binary you are using.  
Where `CLCID` is the system's language code in unprefixed hexadecimal.  
Where `PLCID` is the binary's language code in unprefixed hexadecimal.  
Where `GeoID` is the system's geographic location in decimal.  
Where `ver` is the version of the client as a triplet.

### Server/Response

#### As a SOAP envelope
*This only applies if you use a SOAP request.*
```xml
<?xml version="1.0" encoding="utf-8" ?>
<soap:Envelope
	xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xmlns:xsd="http://www.w3.org/2001/XMLSchema"
>
	<soap:Body>
		<GetClientConfigResponse
			xmlns="http://www.msn.com/webservices/Messenger/Client"
		>
			<GetClientConfigResult><![CDATA[<MsgrConfig>...</MsgrConfig>]]></GetClientConfigResult>
		</GetClientConfigResponse>
	</soap:Body>
</soap:Envelope>
```

Where `<GetClientConfigResponse>` contains a `<GetClientConfigResult>`.  
Where `GetClientConfigResult` always contains a Character Data block containing a `<MsgrConfig>` element.  
Where `<MsgrConfig>` (in the CDATA) is the [Configuration Document](#the-configuration-document).

#### As a XML document
*This only applies if you use query parameters.*
```xml
<?xml version="1.0" encoding="utf-8" ?>
<MsgrConfig>
...
</MsgrConfig>
```

Where `<MsgrConfig>` (everything but the declaration) is the [Configuration Document](#the-configuration-document).

# The Configuration Document
`<MsgrConfig>`: The main element, contains everything.

## Simple
Contains multiple shared configuration options, usually.

### Beta
Contains configuration data for the Beta Program.

#### Invite
Manages the configuration data for the Beta Program Invitation service.

* `<URL>`: The URL to the invitation service.
* `<SiteID>`: The Passport Site ID for the invitation service.

### Config
Contains options for the configuration data itself.

* `<ExpiresInDays>`: The amount of days as a number before this expires

### DisablePhoneDialer
If set to 1, the Phone Dialer is disabled.

### Logitech
* `<PremiumAVConfigServer>`: A URL to the premium Spotlife server (`mplocate`).
* `<PreRollEnabled>`: Are pre-roll advertisements enabled for this feature (`1` or `0`)?
* `<WebcamConfigServer>` A URL to the non-premium Spotlife server (`mlocate`).

### MinFlashPlayer
The minimum version of Adobe/Macromedia Flash Player allowed
before the client is allowed to use content that uses the Flash Player software.

This element has no children, but does have the following attributes:
* `BuildNumber`: The minimum build number for this `MinorVersion`.
* `MajorVersion`: The minimum major version for the plugin.
* `MinorVersion`: The minimum minor version for this `MajorVersion`.

### RadUrl
This element contains the advertisement service base URL.

### Relay
Contains configuration data for the Audio/Video relay.

* `<Enabled>`: If set to 1, the relay is enabled.
* `<MaxCallLength>`: The maximum time (in unknown units) before the call is ended.
* `<RegistrationDomain>`: Unknown.
* `<RelayDNS>`: Contains the Fully Qualified Domain Name (FQDN) of the relay service.
* `<TimeoutToFallback>`: The amount of milliseconds before falling back.  
   If you know what the fallback is, please contact me.
   
### TrustedDomains
Contains many `<domain>` elements.

#### domain
This empty element has the `name` attribute, which specifies the
Fully Qualified Domain Name of the trusted domain. Treated as a silent wildcard.

### ErrorResponseTable
This element only contains `<Feature>` elements.

#### Feature
This element only contains `<Entry>` elements.

This element has two attributes:
* `type`: Unknown, but is `0` for `Login`, `2` for `MapFile`, and `3` for P2P.
* `name`: The name of the feature:
	* `Login`: Login Process
	* `MapFile`: Content Cache Map Files
	* `P2P`: Peer-to-peer communications

##### Entry
This empty element has two attributes:
* `hr`: The HRESULT of this entry, as prefixed hexadecimal.
* `action`: What should the Official Client do in this case? (Usually `3`.)

## TabConfig
Replaces the `tabs.asp` service on `svcs.microsoft.com`.

### msntabdata
This element only contains one or multiple `<tab>` element(s).

#### tab
This element has nine children:
* `<image>`: Either a direct URL to a PNG file (36x32 size) or a resource id:
	* `res:mail`: A mail icon. Unused?
	* `res:bell`: A bell icon. Used for the alerts tab.
	* `res:calendar`: A clock icon. Used for the calendar service.
	* `res:money`: A stock chart icon or a icon depicting a stack of coins.  
	  Used for the financial stocks service.
	* `res:expedia`: A plane icon. Used for the travel service.
	* `res:carpoint`: A car icon. Used for the car reselling service.
	* `res:espn`: The ESPN "E". Used for the relevant service.
	* `res:zone`: A joystick icon. Used for the games service.
	* `res:msnbc`: The MSNBC logo. Used for the relevant service.
	* `res:eshop`: A shopping bag icon. Used for the shopping service.
* `<name>`: The name of this tab that is displayed in the Tab Options dialog.
* `<type>`: An all-lowercase unique name for this tab.  
  Setting this to `hotmail` will hide the tab automatically.  
  Setting this to `alerts` makes the "View Alerts History" button go to this tab.
* `<contenturl>`: A URL to the page that is displayed in the tab.
* `<hiturl>`: A URL for a tracking pixel that is requested when this tab is clicked on.
* `<siteid>`: The Passport Site ID of this tab.  
  Any value except `0` will attempt to log into Passport automatically when the tab is shown.
* `<tabid>`: Unknown what this is used for. If you know, please contact me.
* `<notificationid>`: The ID used for opening the alert content in the relevant tab.
* `<hidden>`: If `true`, this tab does not appear in the tab list.

### msntabsettings
Contains options for OEM (Original Equipment Manufacturer) tabs.  
Unknown when this is used. If you know more, feel free to contact me.  
May only be used in Client Version 4.5 back on svcs?

* `<oemdisplaylimit>`: Amount of OEM-defined tabs allowed to be displayed?
* `<oemtotallimit>`: Amount of OEM-defined tabs allowed to be loaded

## AbchCfg
Replaces the `abch_config.asp` service on `svcs.microsoft.com`.

### abchconfig
* `<url>`: The URL to the [Address Book Service](abservice.md).

## AdMainConfig
* `<AdDownloadTimeInMinutes>`: The amount of minutes until downloading the next banner image.
* `<AdMainCfg>`: The URL to the advertisement service. Loaded as a HTML document.

## AdPhoneConfig
Contains a URL to a document of currently undocumented content using the advertisement service.

## LocalizedConfig
Contains a large chunk of special options that can vary wildly between locales.

This element has the attribute `Market`,
which contains the ISO 639-1 language code for this Configuration Document.

### AdMainConfig
* `<AdBanner20URL>`: The URL to the advertisement service that handles banner advertisements.
	* May contain a `Refresh` attribute that specfies the amount of time in seconds
	  before downloading a new banner advertisement.
* `<TextAdRefresh>`: Amount of minutes before downloading a new text advertisement.
* `<TextAdServer>`: The URL to the advertisement service that handles text advertisements.

### AppDirConfig
* `<AppDirPageURL>`: The URL to the page that is displayed that lets you open
  embedded applications from the Application Directory Service.
* `<AppDirSeviceURL>`: [sic], The URL to the Application Directory Sevice, I mean, Service.
* `<AppDirVersionURL>`: The URL to the Application Directory Service's version endpoint.

### AVPrerollAd
This empty element has four attributes:
* `FetchTimeout`: How many milliseconds before the client stops trying to fetch the pre-roll advertisement.
* `IntroLength`: How long the advertisement introduction animation plays for in milliseconds.
* `MinAdLength`: The minimum advertisement length in milliseconds.
* `URL`: The URL to the advertisement service for pre-roll advertisements.

### BuyWebcamLink
This empty element has one attribute named `URL`
that specifies a web page you can buy a webcam from.

### ContactCard
Blog integration configuration options.
* `<AddToMySpaceSiteId>`: The Passport Site ID used in `<AddToMySpaceUrl>`.
* `<AddToMySpaceUrl`>: The URL used for the "Add to my blog" service.
* `<ContactCardDisabled>`: Is the Contact Card Service disabled? (`true` or `false`)
* `<CreateSpaceSiteId>`: The Passport Site ID used in `<CreateSpaceUrl>`.
* `<CreateSpaceUrl>`: The URL used for the "Create a blog" service.
* `<GetItemVerUrl>`: The URL to the storage service that provides the `GetItemVersion` SOAP action.
* `<GetXmlFeedUrl>`: The URL to the Contact Card Service.
* `<MySpaceSiteId>`: The Passport Site ID used in `<MySpaceUrl>`.
* `<MySpaceUrl>`: The URL used for the "Visit my blog" service.
* `<SpaceBaseSiteId>`: The Passport Site ID used in `<SpaceBaseUrl>`.
* `<SpaceBaseUrl>`: The URL used for the blogging service.
* `<SpaceIntegrationEnabled>`: Is this feature enabled? (`true` or `false`).

### DynamicContent
Contains product advertisement configuration data.

#### merchant
Can contain:
* `<bkgrounds>`
* `<emoticons2>`
* `<themepacks>`
* `<winks2>`

##### bkgrounds
Free Background advertisement data. Only contains `<slots>`.

###### slots
Contains one or multiple `<URL>` element(s) that contain a URL to a `msnmenuitem` XML document.
For more information read [this section on `msnmenuitem` documents](#msnmenuitem-xml-document).

The `<URL>` element supports one attribute named `id`
which is the identification number of this slot.

The `<URL>` element supports a formatting string of `$PUID$`,
which is replaced with your Passport User ID in unprefixed lowercase hexadecimal.

##### emoticons2
Free Emoticon Pack advertisement data. Only contains `<slots>`.

Supports attribute `visibleto`, which is the Client Versions allowed to use this content. 
Usually `7.0.729 and greater`.

###### slots
Contains one or multiple `<URL>` element(s) that contain a URL to a `msnmenuitem` XML document.
For more information read [this section on `msnmenuitem` documents](#msnmenuitem-xml-document).

The `<URL>` element supports one attribute named `id`
which is the identification number of this slot.

The `<URL>` element supports a formatting string of `$PUID$`,
which is replaced with your Passport User ID in unprefixed lowercase hexadecimal.

##### themepacks
Free Theme Pack advertisement data. Only contains `<slots>`.

###### slots
Contains one or multiple `<URL>` element(s) that contain a URL to a `msnmenuitem` XML document.
For more information read [this section on `msnmenuitem` documents](#msnmenuitem-xml-document).

The `<URL>` element supports one attribute named `id`
which is the identification number of this slot.

The `<URL>` element supports a formatting string of `$PUID$`,
which is replaced with your Passport User ID in unprefixed lowercase hexadecimal.

##### winks2
Free Winks advertisement data. Only contains `<slots>`.

Supports attribute `visibleto`, which is the Client Versions allowed to use this content. 
Usually `7.0.729 and greater`.

###### slots
Contains one or multiple `<URL>` element(s) that contain a URL to a `msnmenuitem` XML document.
For more information read [this section on `msnmenuitem` documents](#msnmenuitem-xml-document).

The `<URL>` element supports one attribute named `id`
which is the identification number of this slot.

The `<URL>` element supports a formatting string of `$PUID$`,
which is replaced with your Passport User ID in unprefixed lowercase hexadecimal.

#### premium
Premium product advertisement configuration data.

##### bkgrounds
Premium background advertisement configuration data.

* `<providersiteid>`: The Passport Site ID used for `<providerurl>`.
* `<providerurl>`: The product provider URL.
* `<slots>`: Contains one or multiple `<URL>` element(s).

###### slots
Contains one or multiple `<URL>` element(s) that contain a URL to a `msnmenuitem` XML document.
For more information read [this section on `msnmenuitem` documents](#msnmenuitem-xml-document).

The `<URL>` element supports one attribute named `id`
which is the identification number of this slot.

The `<URL>` element supports a formatting string of `$PUID$`,
which is replaced with your Passport User ID in unprefixed lowercase hexadecimal.

##### emoticons2
Premium emoticon pack advertisement configuration data.

Supports attribute `visibleto`, which is the Client Versions allowed to use this content. 
Usually `7.0.729 and greater`.

* `<providersiteid>`: The Passport Site ID used for `<providerurl>`.
* `<providerurl>`: The product provider URL.
* `<slots>`: Contains one or multiple `<URL>` element(s).

###### slots
Contains one or multiple `<URL>` element(s) that contain a URL to a `msnmenuitem` XML document.
For more information read [this section on `msnmenuitem` documents](#msnmenuitem-xml-document).

The `<URL>` element supports one attribute named `id`
which is the identification number of this slot.

The `<URL>` element supports a formatting string of `$PUID$`,
which is replaced with your Passport User ID in unprefixed lowercase hexadecimal.

##### themepacks
Premium Theme Pack advertisement configuration data.

* `<providersiteid>`: The Passport Site ID used for `<providerurl>`.
* `<providerurl>`: The product provider URL.
* `<slots>`: Contains one or multiple `<URL>` element(s).

###### slots
Contains one or multiple `<URL>` element(s) that contain a URL to a `msnmenuitem` XML document.
For more information read [this section on `msnmenuitem` documents](#msnmenuitem-xml-document).

The `<URL>` element supports one attribute named `id`
which is the identification number of this slot.

The `<URL>` element supports a formatting string of `$PUID$`,
which is replaced with your Passport User ID in unprefixed lowercase hexadecimal.

##### winks2
Premium Wink advertisement configuration data.

Supports attribute `visibleto`, which is the Client Versions allowed to use this content. 
Usually `7.0.729 and greater`.

* `<providersiteid>`: The Passport Site ID used for `<providerurl>`.
* `<providerurl>`: The product provider URL.
* `<slots>`: Contains one or multiple `<URL>` element(s).

###### slots
Contains one or multiple `<URL>` element(s) that contain a URL to a `msnmenuitem` XML document.
For more information read [this section on `msnmenuitem` documents](#msnmenuitem-xml-document).

The `<URL>` element supports one attribute named `id`
which is the identification number of this slot.

The `<URL>` element supports a formatting string of `$PUID$`,
which is replaced with your Passport User ID in unprefixed lowercase hexadecimal.
which is the identification number of this slot.

### EditorialConfig
This element contains a URL to a XML document that contains [editorial data](#editorial-document).

### FlashUpgradeURL
This element contains a URL to a web page that tells you how to update Adobe/Macromedia Flash Player,
with the `$VERSION$` in the URL being replaced with the current version of the plugin.

### MessengerBlogURL
This element contains a URL that specifies the official blog of the service.  
Adds the "Open Messenger Blog" option to the Contact List's Tools menu.

### MobileMessaging
This empty element has five attributes:
* `Mode`: Unknown. `RPPNew` works.
* `CrossSell`: Unknown. `1` works.
* `CharMax`: The maximum amount of characters that can be sent using this service.
* `OperatorPage`: The URL to the landing page of this service.
* `ValidRoutes`: A semi-colon delimited list of ISO 3166-1 alpha-2 codes that specify which
  phone numbers this service is allowed to use.

### MSNSearch
Controls the URLs used by search features.
* `<DesktopInstallURL>`: The promotional page that opens when attempting a desktop search without the required software installed.
* `<ImagesURL>`: The image search service URL.
* `<NearMeURL>`: The search service URL for local services.
* `<NewsURL>`: The news search service URL.
* `<SearchKidsURL>`: The search service URL for children's accounts.
* `<SearchURL>`: The search service URL.
* `<SharedSearchURL>`: The search service URL used in the inline search feature.
* `<SharedSearchURL2>`: The other search service URL used in the inline search feature.

All `<...URL>` elements support two formatting strings:
* `$QUERY$`: The search query.
* `$FC$`: The format code.

If the element is `<SharedSearchURL>` or `<SharedSearchURL2>`,
the `$FORMAT$` formatting string is available.

### MsnTodayConfig
* `<MsnTodaySiteID>`: The Passport Site ID that `<MsnTodayURL>` uses.
  Setting this to `0` disables authentication.
* `<MsnTodayURL>`: The URL to the daily news service.

### MusicIntegration
This empty element has two attributes:
* `URL`: The URL to the music search function, supporting the following formatting strings:
	* `$TITLE$`: The title of the song.
	* `$ARTIST$`: The artist of the song.
	* `$ALBUM$`: The album of the song.
	* `$WMID$`: The Windows Media DRM ID of the song (if available).
* `SiteID`: The Passport Site ID that `URL` uses.

### PremiumAV
This empty element has the attribute `Visibility`. `1` likely enables this feature.

### RL
* `<ViewProfileURL>`: The URL used to open the Member Directory for this user.
  Has the following formatting strings:
	* `%1`: Unknown
	* `%2`: Unknown
	* `%3`: Unknown
	* `%4`: Unknown
	* `%5`: Unknown
	* `%6`: The user handle that you want to view.

### TermsOfUse
* `<TermsOfUseSID>`: The Passport Site ID that `<TermsOfUseURL>` uses,
  if this is `0`, no authentication is attempted.
* `<TermsOfUseURL>`: The URL to the Messenger Service Terms of Use.

### UPUX
This element contains many `<Product>` elements.

#### Product
This element has three required attributes and three optional attributes:
* `id`: The ID for this Product Provider
* `PartnerID`: The partner 2 character code.
* `ProductName`: The type of product:
	* `Winks`
	* `Emoticons`
	* `Backgrounds`
	* `Theme Packs`
	* `Dynamic Display Pictures`
* `BrandName` (optional): The display name of this product.
* `DialogMenuString` (optional): What the client shows when promoting this product.
* `IntegrationType` (optional): How the client should promote this product.
  Can either be `medium` or `deep`.

This element contains the following children:
* `<BillingURL>`: The page that provides payment options for this product.
* `<BillingHelpURL>`: The page that provides information on purchasing content.
* `<ProductShopURL>`: The page that provides the marketplace service.
* `<BasePurchaseURL>`: The page that opens when a client uses the "Get this" feature.

##### ...URL
These empty elements have three attributes:
* `LaunchWindowType`: If this is `IE`, open in the default browser,
  otherwise the internal page viewer in the client.
* `SiteID`: The Passport Site ID for `URL`.
* `URL`: The URL to this service. If this element is `<BasePurchaseURL>`, then
  the formatting string `$CONTENTID$` is available.

### VoiceClip
This empty element has one attribute named `Hidden`,
If this is `1`, the feature is hidden.

### WebWatchConfig
* `<SendSiteID>`: The Passport Site ID that `<SendURL>` uses. Unused, always `0`.
* `<SendURL>`: The URL for the unimplemented send function.
* `<SetupSiteID>`: The Passport Site ID that `<SetupURL>` uses.
* `<SetupURL>`: The URL for the Web Watch Setup wizard.

# Other Related documents

## msnmenuitem XML Document
```xml
<?xml version="1.0" encoding="UTF-8"?>
<msnmenuitem version="1.0">
	<thumburl>http://.../.png</thumburl>
	<displaytext>...</displaytext>
	<clickurl>http://...</clickurl>
	<clicktrackurl></clicktrackurl>
	<siteid>0</siteid>
</msnmenuitem>
```

Where `<msnmenudata>` contains:
* `<thumburl>`: The thumbnail for this product (50x50 PNG).
* `<displaytext>`: The display name for this product.
* `<clickurl>`: The URL to the marketplace page for this product.
* `<clicktrackurl>`: The URL for the click tracking service.
* `<siteid>`: The Passport Site ID used for `<clickurl>` (and `<clicktrackurl>`?).

If the item is for a `<premium>` product, `<clickurl>` is opened in the internal page browser.  
If it is for a `<merchant>` product instead, `<clickurl>` is sent to `MessengerContentInstaller.InstallIndirectContent`.  
To create a merchant package, simply create a empty `<package>` element in an empty XML document with the
`contentlocationurl` attribute set to a Messenger Content archive file.

## Editorial document
```xml
<?xml version="1.0" encoding="utf-8" ?>
<msn-data>
	<RefreshLogin>True</RefreshLogin>
	<RefreshInterval>60</RefreshInterval>
	<article-group>
		<article>
			<title>...</title>
			<url>http://...</url>
		</article>
		<article>
			<title>...</title>
			<url>http://...</url>
		</article>
		<article>
			<title>...</title>
			<url>http://...</url>
		</article>
	</article-group>
</msn-data>
```

Where `<RefreshLogin>` specifies if this document should be re-downloaded
every time you log into the Messenger Service.

Where `<RefreshInterval>` specifies in minutes when this document should be
automatically re-downloaded.

Where `<article-group>` contains one or multiple `<article>` element(s):
* `<title>`: The display name of this article.
* `<url>`: The URL to this article.
