# Introduction
The Passport SOAP (RST) service, or "Passport 3.0" as it's sometimes called,
is a HTTP-based authentication system that was introduced with Messenger 7.5.0160.

The protocol itself is based on [WS-Trust](https://specs.xmlsoap.org/ws/2005/02/trust/WS-Trust.pdf), however it adds proprietary extensions (the `ps` and `psf` namespaces). It is unclear what the official name of this extended protocol is, but "Passport SOAP" seems likely.

The endpoint is called `RST.srf`, residing on either the `login.passport.net` or the `login.live.com` domain.

Messenger versions from 5.0.0537 until 7.5.0160 use the [Passport SSI 1.4](passport14.md) service.  
For [MSNP18](../versions/msnp18.md) and above, read the Request Security Token service, version 2 article. (TODO: Write this, and did I get this right?)

# Client/Request
The following sub-headers are XML elements for the client's request.

## soap:Envelope
This element has eight attributes:
* `xmlns:soap`: Is always set to `http://schemas.xmlsoap.org/soap/envelope/`.
* `xmlns:wsse`: Is always set to `http://schemas.xmlsoap.org/ws/2003/06/secext`.
* `xmlns:saml`: Is always set to `urn:oasis:names:tc:SAML:1.0:assertion`.
* `xmlns:wsp`: Is always set to `http://schemas.xmlsoap.org/ws/2002/12/policy`.
* `xmlns:wsu`: Is always set to `http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd`.
* `xmlns:wsa`: Is always set to `http://schemas.xmlsoap.org/ws/2004/03/addressing`.
* `xmlns:wssc`: Is always set to `http://schemas.xmlsoap.org/ws/2004/04/sc`.
* `xmlns:wst`: Is always seto to `http://schemas.xmlsoap.org/ws/2004/04/trust`.

### soap:Header
This element only contains both the `<ps:AuthInfo>` and `<wsse:Security>` children.

#### ps:AuthInfo
This element has two attributes:
* `xmlns:ps`: Is always set to `http://schemas.microsoft.com/Passport/SoapServices/PPCRL`.
* `Id`: Is always set to `PPAuthInfo`.

This element has five children:
* `<ps:HostingApp>`: The GUID (with braces) of the client that is authenticating.
* `<ps:BinaryVersion>`: A number, usually `4`, but can be higher, or lowered to `3`.
* `<ps:UIVersion>`: Is always set to `1`.
* `<ps:Cookies>`: This element is always empty.
* `<ps:RequestParams>`: A base64-encoded binary structure that seems to be in
  the format of a 32-bit little endian integer of the amount of parameters,
  then an 32-bit little endian integer length and character data for the side of the pair,
  with there being a key side of the pair, and a value side of the pair.

#### wsse:Security
This element only contains the `<wsse:UsernameToken>` element.

##### wsse:UsernameToken
This element has only one attribute:
* `Id`: Is always set to `user`.

This element has two children:
* `<wsse:Username>`: The XML-encoded user handle of the user authenticating.
* `<wsse:Password>`: The XML-encoded password of the user authenticating.

### soap:Body
This element only contains the `<ps:RequestMultipleSecurityTokens>` element.

If there is only one [`<wst:RequestSecurityToken>`](#wst-requestsecuritytoken) element,
it may replace the `<ps:RequestMultipleSecurityTokens>` element.

#### ps:RequestMultipleSecurityTokens
This element has two attributes:
* `xmlns:ps`: Is always set to `http://schemas.microsoft.com/Passport/SoapServices/PPCRL`.
* `Id`: Is always set to `RSTS`.

This element contains one or multiple
[`<wst:RequestSecurityToken>`](#wst-requestsecuritytoken) elements.

# wst:RequestSecurityToken
This element has only one attribute:
* `Id`: Is set to `RST#`, with `#` incrementing every use of this element, starting from `0`.

## wst:RequestType
This element always contains the value `http://schemas.xmlsoap.org/ws/2004/04/security/trust/Issue`.

## wsp:AppliesTo
This element only contains the `<wsa:EndpointReference>` element.

### wsa:EndpointReference
This element only contains one of two mutually exclusive elements:
1. `<wsa:Address>`: By URL or domain name
2. `<wsa:ServiceName>`: By service name

#### wsa:Address
This element contains the target domain for this security token:
* `http://Passport.NET/tb`: Legacy authentication, One of these is always required (usually as `RST0`). Does not set a `<wsse:PolicyReference>`.
* `messengerclear.live.com`: The domain used for authenticating to the Messenger service using the [SSO](../authschemes/sso.md) scheme. Uses a policy challenge defined by the MSNP server, which is usually `MBI_KEY_OLD`.
* `messenger.msn.com`: The domain used for authenticating to the Messenger service using the [TWN](../authschemes/twn.md) scheme. Uses an authentication ticket (`?...`)
  defined by the MSNP server, or `?id=507` if using the [SSO](../authschemes/sso.md) scheme to authenticate.
* `contacts.msn.com`: Used for the [Address Book Service](abservice.md). Uses an authentication ticket (`?...`) or `MBI`
  (since [MSNP15](../versions/msnp15.md)). Required since [MSNP13](../versions/msnp13.md).
* `messengersecure.live.com`: A secure version of `messenger.msn.com`, with unknown use. Uses `MBI_SSL`.
* `spaces.msn.com`: The blog service. Uses `MBI`.
* `spaces.live.com`: The blog service. Uses `MBI`.
* `livecontacts.live.com`: The Live Contacts ABI, apparently a simplified version of the [Address Book Service](abservice.md).
* `storage.msn.com`: The user storage service. Uses `MBI_SSL`. Required for [MSNP15](../versions/msnp15.md)'s roaming user content support.

#### wsa:ServiceName
This element contains the target service name for this security token:
* `p2pslc.messenger.msn.com`: The peer-to-peer "slc" service. Uses `MBI_X509_CID`.

## wst:Supporting
This optional element only exists if the [`<wsse:PolicyReference>`](#wsse-policyreference) requires it.

### wsse:BinarySecurityToken
This element has two attributes:
* `ValueType`: Usually only seen set to `http://schemas.microsoft.com/Passport/SoapServices/PPCRL#PKCS10`.
* `EncodingType`: Usually only seen set to `wsse:Base64Binary`.

This element's value is the binary token, which has only been observed to be a PKCS#10 certificate request
in SHA1-RSA format (1024 bits), with the Common Name (CN) set to `MSIDCRL`.

## wsse:PolicyReference
This optional element has only one attribute:
* `URI`: The security policy of this security token:
	* `MBI_KEY_OLD`: Calculate a challenge with the server's `<wst:BinarySecret>`.
	* `MBI_KEY`: Unknown, but probably not unlike `MBI_KEY_OLD`?
	* `MBI`: No special parameters.
	* `MBI_SSL`: No special parameters and encrypted transport only.
	* `MBI_X509_CID`: Unknown, but based on user certificates. Only used with `p2pslc.messenger.msn.com`.
	* (any policy starting with `?`): Authenticate using an authentication ticket. Used for the [TWN](../authschemes/twn.md) authentication scheme.

# Server/Response
The following sub-headers are XML elements for the server's response.

## soap:Envelope
This element has only one attribute:
* `xmlns:soap`: Is always set to `http://schemas.xmlsoap.org/soap/envelope/`.

### soap:Header
This element only contains the `<psf:pp>` element.

#### psf:pp
This element has only one attribute:
* `xmlns:psf`: Is always set to `http://schemas.microsoft.com/Passport/SoapServices/SOAPFault`.

This element has nine children:
* `<psf:serverVersion>`: Only observed to be `1`.
* `<psf:PUID>`: The user's Passport Unique ID, expressed as a 16-bit capitalized hexadecimal stream.
* `<psf:configVersion>`: The configuration version expressed as a quadruplet.
* `<psf:uiVersion>`: The user interface version expressed as a quadruplet.
* `<psf:authstate>`: This is always `0x48803` (`PPCRL_AUTHSTATE_S_AUTHENTICATED_PASSWORD`) for successful authentications.
* `<psf:regstatus>`: This is always `0x0` for successful authentications.
* `<psf:serverInfo>`: This element has the server's identification string and the following four attributes:
	* `Path`: Always set to `Live1`.
	* `RollingUpgradeState`: Always set to `ExclusiveNew`.
	* `LocVersion`: Always set to `0`.
	* `ServerTime`: A ISO 8601 timestamp that specifies the time this response was generated.
* `<psf:cookies>`: This element is always empty.
* `<psf:response>`: This element is always empty.

### soap:Body
This element only contains the `<wst:RequestSecurityTokenResponseCollection>` element.

#### wst:RequestSecurityTokenResponseCollection
This element has six attributes:
* `xmlns:wst`: Is always set to `http://schemas.xmlsoap.org/ws/2004/04/trust`.
* `xmlns:wsse`: Is always set to `http://schemas.xmlsoap.org/ws/2003/06/secext`.
* `xmlns:wsu`: Is always set to `http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd`.
* `xmlns:saml`: Is always set to `urn:oasis:names:tc:SAML:1.0:assertion`.
* `xmlns:wsp`: Is always set to `http://schemas.xmlsoap.org/ws/2002/12/policy`.
* `xmlns:psf`: Is always set to `http://schemas.microsoft.com/Passport/SoapServices/SOAPFault`.

This element contains one or multiple
[`<wst:RequestSecurityTokenResponse>`](#wst-requestsecuritytokenresponse) elements.

# wst:RequestSecurityTokenResponse
This element has four required children and one optional child:
* `<wst:TokenType>`: The type of security token this `<wst:RequestSecurityTokenResponse>` is.
* `<wsp:AppliesTo>`: Defines what can use this security token.
* `<wst:RequestedSecurityToken>`: The security token itself.
* `<wst:RequestedTokenReference>`: The reference location of where the security token is stored.
* `<wst:RequestedProofToken>` (Optional): The proof token used for `urn:passport:legacy` tokens or `MBI_KEY_OLD` policies.

## wst:TokenType
This element only contains either the value `urn:passport:legacy` or `urn:passport:compact`.

## wsp:AppliesTo
This element has only one attribute:
* `xmlns:wsa`: Is always set to `http://schemas.xmlsoap.org/ws/2004/03/addressing`.

This element only contains the `<wsa:EndpointReference>` element.

### wsa:EndpointReference
This element only contains the `<wsa:Address>` element.

#### wsa:Address
This element contains the target domain for this security token:
* `http://Passport.NET/tb`: Legacy authentication, One of these is always required (usually as `RST0`). Does not set a `<wsse:PolicyReference>`.
* `messengerclear.live.com`: The domain used for authenticating to the Messenger service using the [SSO](../authschemes/sso.md) scheme. Uses a policy challenge defined by the MSNP server, which is usually `MBI_KEY_OLD`.
* `messenger.msn.com`: The domain used for authenticating to the Messenger service using the [TWN](../authschemes/twn.md) scheme. Uses an authentication ticket (`?...`)
  defined by the MSNP server, or `?id=507` if using the [SSO](../authschemes/sso.md) scheme to authenticate.
* `contacts.msn.com`: Used for the [Address Book Service](abservice.md). Uses an authentication ticket (`?...`) or `MBI`
  (since [MSNP15](../versions/msnp15.md)). Required since [MSNP13](../versions/msnp13.md).
* `messengersecure.live.com`: A secure version of `messenger.msn.com`, with unknown use. Uses `MBI_SSL`.
* `spaces.msn.com`: The blog service. Uses `MBI`.
* `spaces.live.com`: The blog service. Uses `MBI`.
* `livecontacts.live.com`: The Live Contacts ABI, apparently a simplified version of the [Address Book Service](abservice.md).
* `storage.msn.com`: The user storage service. Uses `MBI_SSL`. Required for [MSNP15](../versions/msnp15.md)'s roaming user content support.

## wst:LifeTime
This element has two children:
* `<wsu:Created>`: The ISO 8601 timestamp of when this security token was generated.
* `<wsu:Expires>`: The ISO 8601 timestamp of when this security token expires.

## wst:RequestedSecurityToken
This element has different children based on the value of the
[`<wst:TokenType>`](#wst-tokentype) element.

### [urn:passport:legacy children]
These elements are only included in `<wst:RequestedSecurityToken>` if the value of
[`<wst:TokenType>`](#wst-tokentype) element is set to `urn:passport:legacy`.

#### EncryptedData
This element has three attributes:
* `xmlns`: This is always `http://www.w3.org/2001/04/xmlenc#`.
* `Id`: This is always set to `BinaryDAToken#`, with the `#` being incremented every use of the
  `<wst:RequestSecurityTokenResponse>` element starting from `0`.
* `Type`: This is always set to `http://www.w3.org/2001/04/xmlenc#Element`.

##### EncryptionMethod
This empty element has only one attribute:
* `Algorithm`: This is always set to `http://www.w3.org/2001/04/xmlenc#tripledes-cbc`.

##### ds:KeyInfo
This element has only one attribute:
* `xmlns:ds`: This is always set to `http://www.w3.org/2000/09/xmldsig#`.

This element only has one child:
* `<ds:KeyName>`: Only observed to be `http://Passport.NET/STS`

##### CipherData
This element has only one child:
* `<CipherValue>`: A XML element
  (with unknown properties and children, likely has a Passport Token somewhere), just 3DES encrypted.
  (If you know how to decrypt this element, please contact me!)

### [urn:passport:compact children]
These elements are only included in `<wst:RequestedSecurityToken>` if the value of
[`<wst:TokenType>`](#wst-tokentype) element is set to `urn:passport:compact`.

#### wsse:BinarySecurityToken
This element has only one attribute:
* `Id`: This is always set to `Compact#`, with the `#` being incremented every use of the
  `<wst:RequestSecurityTokenResponse>` element starting from `0`.

This element contains the Passport Compact Token, which consists of an authentication token and profile parameters as a XML-encoded value.
(`t=token&amp;p=profile`)

## wst:RequestedTokenReference
This element has two children:
* `<wsse:KeyIdentifier>`: This empty element has only one attribute:
	* `ValueType`: This is either `urn:passport` or `urn:passport:compact`.
* `<wsse:Reference>`: This empty element has only one attribute:
	* `URI`: The URI that has the contents of the security token.
	  Usually refers to the first child of the `<wst:RequestedSecurityToken>` element
	  via it's `Id` attribute, using the `#` prefix followed by the value of the `Id` attribute.

## wst:RequestedProofToken
This optional element only has one child:
* `<wst:BinarySecret>`: The binary secret for this token

# RST.srf

## Basic Request
*Only in [MSNP12](../versions/msnp12.md).*

### Client/Request
```http
POST /RST.srf HTTP/1.1
Cache-Control: no-cache
Content-Type: text/xml; charset=utf-8
Content-Length: {data-length}

<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope
	xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
	xmlns:wsse="http://schemas.xmlsoap.org/ws/2003/06/secext"
	xmlns:saml="urn:oasis:names:tc:SAML:1.0:assertion"
	xmlns:wsp="http://schemas.xmlsoap.org/ws/2002/12/policy"
	xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
	xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/03/addressing"
	xmlns:wssc="http://schemas.xmlsoap.org/ws/2004/04/sc"
	xmlns:wst="http://schemas.xmlsoap.org/ws/2004/04/trust"
>
	<soap:Header>
		<ps:AuthInfo
			xmlns:ps="http://schemas.microsoft.com/Passport/SoapServices/PPCRL"
			Id="PPAuthInfo"
		>
			<ps:HostingApp>{7108E71A-9926-4FCB-BCC9-9A9D3F32E423}</ps:HostingApp>
			<ps:BinaryVersion>4</ps:BinaryVersion>
			<ps:UIVersion>1</ps:UIVersion>
			<ps:Cookies></ps:Cookies>
			<ps:RequestParams>AQAAAAIAAABsYwQAAAAyMDU3</ps:RequestParams>
		</ps:AuthInfo>
		<wsse:Security>
			<wsse:UsernameToken
				Id="user"
			>
				<wsse:Username>{user-handle}</wsse:Username>
				<wsse:Password>{password}</wsse:Password>
			</wsse:UsernameToken>
		</wsse:Security>
	</soap:Header>
	<soap:Body>
		<ps:RequestMultipleSecurityTokens
			xmlns:ps="http://schemas.microsoft.com/Passport/SoapServices/PPCRL"
			Id="RSTS"
		>
			<wst:RequestSecurityToken
				Id="RST0"
			>
				<wst:RequestType>http://schemas.xmlsoap.org/ws/2004/04/security/trust/Issue</wst:RequestType>
				<wsp:AppliesTo>
					<wsa:EndpointReference>
						<wsa:Address>http://Passport.NET/tb</wsa:Address>
					</wsa:EndpointReference>
				</wsp:AppliesTo>
			</wst:RequestSecurityToken>
			<wst:RequestSecurityToken
				Id="RST1"
			>
				<wst:RequestType>http://schemas.xmlsoap.org/ws/2004/04/security/trust/Issue</wst:RequestType>
				<wsp:AppliesTo>
					<wsa:EndpointReference>
						<wsa:Address>messenger.msn.com</wsa:Address>
					</wsa:EndpointReference>
				</wsp:AppliesTo>
				<wsse:PolicyReference
					URI="?{server-args}"
				/>
			</wst:RequestSecurityToken>
		</ps:RequestMultipleSecurityTokens>
	</soap:Body>
</soap:Envelope>
```
Where `data-length` is the total size of the XML document with the placeholders changed to their correct values.

Where `user-handle` is the XML-encoded user handle of the user to authenticate.

Where `password` is the XML-encoded password of the user to authenticate.

Where `server-args` is the parameter given to the server's response to the initial [USR](../commands/usr.md).

### Server/Response
*NOTE: The legacy Passport token has been removed to prevent issues with scrolling.*
```http
HTTP/1.1 200 OK
Content-Type: text/xml; charset=utf-8
Content-Length: 3557

<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope
	xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
>
	<soap:Header>
		<psf:pp
			xmlns:psf="http://schemas.microsoft.com/Passport/SoapServices/SOAPFault"
		>
			<psf:serverVersion>1</psf:serverVersion>
			<psf:PUID>0000000100000002</psf:PUID>
			<psf:configVersion>3.0.869.0</psf:configVersion>
			<psf:uiVersion>3.0.869.0</psf:uiVersion>
			<psf:authstate>0x48803</psf:authstate>
			<psf:reqstatus>0x0</psf:reqstatus>
			<psf:serverInfo
				Path="Live1"
				RollingUpgradeState="ExclusiveNew"
				LocVersion="0"
				ServerTime="2024-11-22T14:45:20Z"
			>yellows111 2024.11.22.14.45.20</psf:serverInfo>
			<psf:cookies/>
			<psf:response/>
		</psf:pp>
	</soap:Header>
	<soap:Body>
		<wst:RequestSecurityTokenResponseCollection
			xmlns:wst="http://schemas.xmlsoap.org/ws/2004/04/trust"
			xmlns:wsse="http://schemas.xmlsoap.org/ws/2003/06/secext"
			xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
			xmlns:saml="urn:oasis:names:tc:SAML:1.0:assertion"
			xmlns:wsp="http://schemas.xmlsoap.org/ws/2002/12/policy"
			xmlns:psf="http://schemas.microsoft.com/Passport/SoapServices/SOAPFault"
		>
			<wst:RequestSecurityTokenResponse>
				<wst:TokenType>urn:passport:legacy</wst:TokenType>
				<wsp:AppliesTo
					xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/03/addressing"
				>
					<wsa:EndpointReference>
						<wsa:Address>http://Passport.NET/tb</wsa:Address>
					</wsa:EndpointReference>
				</wsp:AppliesTo>
				<wst:LifeTime>
					<wsu:Created>2024-11-22T14:45:20Z</wsu:Created>
					<wsu:Expires>2024-11-22T14:45:20Z</wsu:Expires>
				</wst:LifeTime>
				<wst:RequestedSecurityToken>
					<EncryptedData
						xmlns="http://www.w3.org/2001/04/xmlenc#"
						Id="BinaryDAToken0"
						Type="http://www.w3.org/2001/04/xmlenc#Element"
					>
					<EncryptionMethod
						algorithm="http://www.w3.org/2001/04/xmlenc#tripledes-cbc"
					/>
					<ds:KeyInfo
						xmlns:ds="http://www.w3.org/2000/09/xmldsig#"
					>
						<ds:KeyName>http://Passport.NET/STS</ds:KeyName>
					</ds:KeyInfo>
					<CipherData>
						<CipherValue>[[removed intentionally]]</CipherValue>
					</CipherData>
					</EncryptedData>
				</wst:RequestedSecurityToken>
				<wst:RequestedTokenReference>
					<wsse:KeyIdentifier
						ValueType="urn:passport"
					/>
					<wsse:Reference
						URI="#BinaryDAToken0"
					/>
				</wst:RequestedTokenReference>
				<wst:RequestedProofToken>
					<wst:BinarySecret>AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=</wst:BinarySecret>
				</wst:RequestedProofToken>
			</wst:RequestSecurityTokenResponse>
			<wst:RequestSecurityTokenResponse>
				<wst:TokenType>urn:passport:compact</wst:TokenType>
				<wsp:AppliesTo
					xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/03/addressing"
				>
					<wsa:EndpointReference>
						<wsa:Address>messenger.msn.com</wsa:Address>
					</wsa:EndpointReference>
				</wsp:AppliesTo>
				<wst:LifeTime>
					<wsu:Created>2024-11-22T14:45:20Z</wsu:Created>
					<wsu:Expires>2024-11-22T14:45:20Z</wsu:Expires>
				</wst:LifeTime>
				<wst:RequestedSecurityToken>
					<wsse:BinarySecurityToken
						Id="Compact1"
					>t=token&amp;p=profile</wsse:BinarySecurityToken>
				</wst:RequestedSecurityToken>
				<wst:RequestedTokenReference>
					<wsse:KeyIdentifier
						ValueType="urn:passport:compact"
					/>
					<wsse:Reference
						URI="#Compact1"
					/>
				</wst:RequestedTokenReference>
			</wst:RequestSecurityTokenResponse>
		</wst:RequestSecurityTokenResponseCollection>
	</soap:Body>
</soap:Envelope>
```

## With contacts.msn.com
*Only in [MSNP13](../versions/msnp13.md) and [MSNP14](../versions/msnp14.md).*

### Client/Request
```http
POST /RST.srf HTTP/1.1
Cache-Control: no-cache
Content-Type: text/xml; charset=utf-8
Content-Length: {data-length}

<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope
	xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
>
	<soap:Header>
	</soap:Header>
	<soap:Body>
		<ps:RequestMultipleSecurityTokens
			xmlns:ps="http://schemas.microsoft.com/Passport/SoapServices/PPCRL"
			Id="RSTS"
		>
			<wst:RequestSecurityToken
				Id="RST0"
			>
				<wst:RequestType>http://schemas.xmlsoap.org/ws/2004/04/security/trust/Issue</wst:RequestType>
				<wsp:AppliesTo>
					<wsa:EndpointReference>
						<wsa:Address>http://Passport.NET/tb</wsa:Address>
					</wsa:EndpointReference>
				</wsp:AppliesTo>
			</wst:RequestSecurityToken>
			<wst:RequestSecurityToken
				Id="RST1"
			>
				<wst:RequestType>http://schemas.xmlsoap.org/ws/2004/04/security/trust/Issue</wst:RequestType>
				<wsp:AppliesTo>
					<wsa:EndpointReference>
						<wsa:Address>messenger.msn.com</wsa:Address>
					</wsa:EndpointReference>
				</wsp:AppliesTo>
				<wsse:PolicyReference
					URI="?{server-args}"
				/>
			</wst:RequestSecurityToken>
			<wst:RequestSecurityToken
				Id="RST2"
			>
				<wst:RequestType>http://schemas.xmlsoap.org/ws/2004/04/security/trust/Issue</wst:RequestType>
				<wsp:AppliesTo>
					<wsa:EndpointReference>
						<wsa:Address>contacts.msn.com</wsa:Address>
					</wsa:EndpointReference>
				</wsp:AppliesTo>
				<wsse:PolicyReference
					URI="MBI"
				/>
			</wst:RequestSecurityToken>
		</ps:RequestMultipleSecurityTokens>
	</soap:Body>
</soap:Envelope>
```
Where `data-length` is the total size of the XML document with the placeholders changed to their correct values.

Where `user-handle` is the XML-encoded user handle of the user to authenticate.

Where `password` is the XML-encoded password of the user to authenticate.

Where `server-args` is the parameter given to the server's response to the initial [USR](../commands/usr.md).

### Server/Response
*NOTE: The legacy Passport token has been removed to prevent issues with scrolling.*
```http
HTTP/1.1 200 OK
Content-Type: text/xml; charset=utf-8
Content-Length: 4382

<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope
	xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
>
	<soap:Header>
		<psf:pp
			xmlns:psf="http://schemas.microsoft.com/Passport/SoapServices/SOAPFault"
		>
			<psf:serverVersion>1</psf:serverVersion>
			<psf:PUID>0000000100000002</psf:PUID>
			<psf:configVersion>3.0.869.0</psf:configVersion>
			<psf:uiVersion>3.0.869.0</psf:uiVersion>
			<psf:authstate>0x48803</psf:authstate>
			<psf:reqstatus>0x0</psf:reqstatus>
			<psf:serverInfo
				Path="Live1"
				RollingUpgradeState="ExclusiveNew"
				LocVersion="0"
				ServerTime="2024-11-22T14:45:20Z"
			>yellows111 2024.11.22.14.45.20</psf:serverInfo>
			<psf:cookies/>
			<psf:response/>
		</psf:pp>
	</soap:Header>
	<soap:Body>
		<wst:RequestSecurityTokenResponseCollection
			xmlns:wst="http://schemas.xmlsoap.org/ws/2004/04/trust"
			xmlns:wsse="http://schemas.xmlsoap.org/ws/2003/06/secext"
			xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
			xmlns:saml="urn:oasis:names:tc:SAML:1.0:assertion"
			xmlns:wsp="http://schemas.xmlsoap.org/ws/2002/12/policy"
			xmlns:psf="http://schemas.microsoft.com/Passport/SoapServices/SOAPFault"
		>
			<wst:RequestSecurityTokenResponse>
				<wst:TokenType>urn:passport:legacy</wst:TokenType>
				<wsp:AppliesTo
					xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/03/addressing"
				>
					<wsa:EndpointReference>
						<wsa:Address>http://Passport.NET/tb</wsa:Address>
					</wsa:EndpointReference>
				</wsp:AppliesTo>
				<wst:LifeTime>
					<wsu:Created>2024-11-22T14:45:20Z</wsu:Created>
					<wsu:Expires>2024-11-22T14:45:20Z</wsu:Expires>
				</wst:LifeTime>
				<wst:RequestedSecurityToken>
					<EncryptedData
						xmlns="http://www.w3.org/2001/04/xmlenc#"
						Id="BinaryDAToken0"
						Type="http://www.w3.org/2001/04/xmlenc#Element"
					>
					<EncryptionMethod
						algorithm="http://www.w3.org/2001/04/xmlenc#tripledes-cbc"
					/>
					<ds:KeyInfo
						xmlns:ds="http://www.w3.org/2000/09/xmldsig#"
					>
						<ds:KeyName>http://Passport.NET/STS</ds:KeyName>
					</ds:KeyInfo>
					<CipherData>
						<CipherValue>[[removed intentionally]]</CipherValue>
					</CipherData>
					</EncryptedData>
				</wst:RequestedSecurityToken>
				<wst:RequestedTokenReference>
					<wsse:KeyIdentifier
						ValueType="urn:passport"
					/>
					<wsse:Reference
						URI="#BinaryDAToken0"
					/>
				</wst:RequestedTokenReference>
				<wst:RequestedProofToken>
					<wst:BinarySecret>AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=</wst:BinarySecret>
				</wst:RequestedProofToken>
			</wst:RequestSecurityTokenResponse>
			<wst:RequestSecurityTokenResponse>
				<wst:TokenType>urn:passport:compact</wst:TokenType>
				<wsp:AppliesTo
					xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/03/addressing"
				>
					<wsa:EndpointReference>
						<wsa:Address>messenger.msn.com</wsa:Address>
					</wsa:EndpointReference>
				</wsp:AppliesTo>
				<wst:LifeTime>
					<wsu:Created>2024-11-22T14:45:20Z</wsu:Created>
					<wsu:Expires>2024-11-22T14:45:20Z</wsu:Expires>
				</wst:LifeTime>
				<wst:RequestedSecurityToken>
					<wsse:BinarySecurityToken
						Id="Compact1"
					>t=token&amp;p=profile</wsse:BinarySecurityToken>
				</wst:RequestedSecurityToken>
				<wst:RequestedTokenReference>
					<wsse:KeyIdentifier
						ValueType="urn:passport:compact"
					/>
					<wsse:Reference
						URI="#Compact1"
					/>
				</wst:RequestedTokenReference>
			</wst:RequestSecurityTokenResponse>
			<wst:RequestSecurityTokenResponse>
				<wst:TokenType>urn:passport:compact</wst:TokenType>
				<wsp:AppliesTo
					xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/03/addressing"
				>
					<wsa:EndpointReference>
						<wsa:Address>contacts.msn.com</wsa:Address>
					</wsa:EndpointReference>
				</wsp:AppliesTo>
				<wst:LifeTime>
					<wsu:Created>2024-11-22T14:45:20Z</wsu:Created>
					<wsu:Expires>2024-11-22T14:45:20Z</wsu:Expires>
				</wst:LifeTime>
				<wst:RequestedSecurityToken>
					<wsse:BinarySecurityToken
						Id="Compact2"
					>t=token&amp;p=profile</wsse:BinarySecurityToken>
				</wst:RequestedSecurityToken>
				<wst:RequestedTokenReference>
					<wsse:KeyIdentifier
						ValueType="urn:passport:compact"
					/>
					<wsse:Reference
						URI="#Compact2"
					/>
				</wst:RequestedTokenReference>
		</wst:RequestSecurityTokenResponseCollection>
	</soap:Body>
</soap:Envelope>
```

## With MBI\_OLD\_KEY
*Since [MSNP15](../versions/msnp15.md).*

### Client/Request
```http
POST /RST.srf HTTP/1.1
Cache-Control: no-cache
Content-Type: text/xml; charset=utf-8
Content-Length: {data-length}

<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope
	xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
>
	<soap:Header>
	</soap:Header>
	<soap:Body>
		<ps:RequestMultipleSecurityTokens
			xmlns:ps="http://schemas.microsoft.com/Passport/SoapServices/PPCRL"
			Id="RSTS"
		>
			<wst:RequestSecurityToken
				Id="RST0"
			>
				<wst:RequestType>http://schemas.xmlsoap.org/ws/2004/04/security/trust/Issue</wst:RequestType>
				<wsp:AppliesTo>
					<wsa:EndpointReference>
						<wsa:Address>http://Passport.NET/tb</wsa:Address>
					</wsa:EndpointReference>
				</wsp:AppliesTo>
			</wst:RequestSecurityToken>
			<wst:RequestSecuirtyToken
				Id="RST1"
			>
				<wst:RequestType>http://schemas.xmlsoap.org/ws/2004/04/security/trust/Issue</wst:RequestType>
				<wsp:AppliesTo>
					<wsa:EndpointReference>
						<wsa:Address>messengerclear.live.com</wsa:Address>
					</wsa:EndpointReference>
				</wsp:AppliesTo>
				<wsse:PolicyReference
					URI="MBI_KEY_OLD"
				/>
			</wst:RequestSecurityToken>
			<wst:RequestSecurityToken
				Id="RST2"
			>
				<wst:RequestType>http://schemas.xmlsoap.org/ws/2004/04/security/trust/Issue</wst:RequestType>
				<wsp:AppliesTo>
					<wsa:EndpointReference>
						<wsa:Address>messenger.msn.com</wsa:Address>
					</wsa:EndpointReference>
				</wsp:AppliesTo>
				<wsse:PolicyReference
					URI="?id=507"
				/>
			</wst:RequestSecurityToken>
			<wst:RequestSecurityToken
				Id="RST3"
			>
				<wst:RequestType>http://schemas.xmlsoap.org/ws/2004/04/security/trust/Issue</wst:RequestType>
				<wsp:AppliesTo>
					<wsa:EndpointReference>
						<wsa:Address>contacts.msn.com</wsa:Address>
					</wsa:EndpointReference>
				</wsp:AppliesTo>
				<wsse:PolicyReference
					URI="MBI"
				/>
			</wst:RequestSecurityToken>
		</ps:RequestMultipleSecurityTokens>
	</soap:Body>
</soap:Envelope>
```
Where `data-length` is the total size of the XML document with the placeholders changed to their correct values.

Where `user-handle` is the XML-encoded user handle of the user to authenticate.

Where `password` is the XML-encoded password of the user to authenticate.

*NOTE: Technically `MBI_KEY_OLD` is just defined by the server's response to the initial [USR](../commands/usr.md).*

### Server/Response
*NOTE: The legacy Passport token has been removed to prevent issues with scrolling.*
```http
HTTP/1.1 200 OK
Content-Type: text/xml; charset=utf-8
Content-Length: 5420

<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope
	xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
>
	<soap:Header>
		<psf:pp
			xmlns:psf="http://schemas.microsoft.com/Passport/SoapServices/SOAPFault"
		>
			<psf:serverVersion>1</psf:serverVersion>
			<psf:PUID>0000000100000002</psf:PUID>
			<psf:configVersion>3.0.869.0</psf:configVersion>
			<psf:uiVersion>3.0.869.0</psf:uiVersion>
			<psf:authstate>0x48803</psf:authstate>
			<psf:reqstatus>0x0</psf:reqstatus>
			<psf:serverInfo
				Path="Live1"
				RollingUpgradeState="ExclusiveNew"
				LocVersion="0"
				ServerTime="2024-11-22T14:45:20Z"
			>yellows111 2024.11.22.14.45.20</psf:serverInfo>
			<psf:cookies/>
			<psf:response/>
		</psf:pp>
	</soap:Header>
	<soap:Body>
		<wst:RequestSecurityTokenResponseCollection
			xmlns:wst="http://schemas.xmlsoap.org/ws/2004/04/trust"
			xmlns:wsse="http://schemas.xmlsoap.org/ws/2003/06/secext"
			xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
			xmlns:saml="urn:oasis:names:tc:SAML:1.0:assertion"
			xmlns:wsp="http://schemas.xmlsoap.org/ws/2002/12/policy"
			xmlns:psf="http://schemas.microsoft.com/Passport/SoapServices/SOAPFault"
		>
			<wst:RequestSecurityTokenResponse>
				<wst:TokenType>urn:passport:legacy</wst:TokenType>
				<wsp:AppliesTo
					xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/03/addressing"
				>
					<wsa:EndpointReference>
						<wsa:Address>http://Passport.NET/tb</wsa:Address>
					</wsa:EndpointReference>
				</wsp:AppliesTo>
				<wst:LifeTime>
					<wsu:Created>2024-11-22T14:45:20Z</wsu:Created>
					<wsu:Expires>2024-11-22T14:45:20Z</wsu:Expires>
				</wst:LifeTime>
				<wst:RequestedSecurityToken>
					<EncryptedData
						xmlns="http://www.w3.org/2001/04/xmlenc#"
						Id="BinaryDAToken0"
						Type="http://www.w3.org/2001/04/xmlenc#Element"
					>
					<EncryptionMethod
						algorithm="http://www.w3.org/2001/04/xmlenc#tripledes-cbc"
					/>
					<ds:KeyInfo
						xmlns:ds="http://www.w3.org/2000/09/xmldsig#"
					>
						<ds:KeyName>http://Passport.NET/STS</ds:KeyName>
					</ds:KeyInfo>
					<CipherData>
						<CipherValue>[[removed intentionally]]</CipherValue>
					</CipherData>
					</EncryptedData>
				</wst:RequestedSecurityToken>
				<wst:RequestedTokenReference>
					<wsse:KeyIdentifier
						ValueType="urn:passport"
					/>
					<wsse:Reference
						URI="#BinaryDAToken0"
					/>
				</wst:RequestedTokenReference>
				<wst:RequestedProofToken>
					<wst:BinarySecret>AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=</wst:BinarySecret>
				</wst:RequestedProofToken>
			</wst:RequestSecurityTokenResponse>
			<wst:RequestSecurityTokenResponse>
				<wst:TokenType>urn:passport:compact</wst:TokenType>
				<wsp:AppliesTo
					xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/03/addressing"
				>
					<wsa:EndpointReference>
						<wsa:Address>messengerclear.msn.com</wsa:Address>
					</wsa:EndpointReference>
				</wsp:AppliesTo>
				<wst:LifeTime>
					<wsu:Created>2024-11-22T14:45:20Z</wsu:Created>
					<wsu:Expires>2024-11-22T14:45:20Z</wsu:Expires>
				</wst:LifeTime>
				<wst:RequestedSecurityToken>
					<wsse:BinarySecurityToken
						Id="Compact1"
					>t=token&amp;p=</wsse:BinarySecurityToken>
				</wst:RequestedSecurityToken>
				<wst:RequestedTokenReference>
					<wsse:KeyIdentifier
						ValueType="urn:passport:compact"
					/>
					<wsse:Reference
						URI="#Compact1"
					/>
				</wst:RequestedTokenReference>
				<wst:RequestedProofToken>
					<wst:BinarySecret>AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=</wst:BinarySecret>
				</wst:RequestedProofToken>
			</wst:RequestSecurityTokenResponse>
			<wst:RequestSecurityTokenResponse>
				<wst:TokenType>urn:passport:compact</wst:TokenType>
				<wsp:AppliesTo
					xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/03/addressing"
				>
					<wsa:EndpointReference>
						<wsa:Address>messenger.msn.com</wsa:Address>
					</wsa:EndpointReference>
				</wsp:AppliesTo>
				<wst:LifeTime>
					<wsu:Created>2024-11-22T14:45:20Z</wsu:Created>
					<wsu:Expires>2024-11-22T14:45:20Z</wsu:Expires>
				</wst:LifeTime>
				<wst:RequestedSecurityToken>
					<wsse:BinarySecurityToken
						Id="Compact2"
					>t=token&amp;p=profile</wsse:BinarySecurityToken>
				</wst:RequestedSecurityToken>
				<wst:RequestedTokenReference>
					<wsse:KeyIdentifier
						ValueType="urn:passport:compact"
					/>
					<wsse:Reference
						URI="#Compact2"
					/>
				</wst:RequestedTokenReference>
			</wst:RequestSecurityTokenResponse>
			<wst:RequestSecurityTokenResponse>
				<wst:TokenType>urn:passport:compact</wst:TokenType>
				<wsp:AppliesTo
					xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/03/addressing"
				>
					<wsa:EndpointReference>
						<wsa:Address>contacts.msn.com</wsa:Address>
					</wsa:EndpointReference>
				</wsp:AppliesTo>
				<wst:LifeTime>
					<wsu:Created>2024-11-22T14:45:20Z</wsu:Created>
					<wsu:Expires>2024-11-22T14:45:20Z</wsu:Expires>
				</wst:LifeTime>
				<wst:RequestedSecurityToken>
					<wsse:BinarySecurityToken
						Id="Compact3"
					>t=token&amp;p=profile</wsse:BinarySecurityToken>
				</wst:RequestedSecurityToken>
				<wst:RequestedTokenReference>
					<wsse:KeyIdentifier
						ValueType="urn:passport:compact"
					/>
					<wsse:Reference
						URI="#Compact3"
					/>
				</wst:RequestedTokenReference>
			</wst:RequestSecurityTokenResponse>
		</wst:RequestSecurityTokenResponseCollection>
	</soap:Body>
</soap:Envelope>
```
