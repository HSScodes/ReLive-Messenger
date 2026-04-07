# Introduction
`ABContactUpdate` is one of the SOAP actions the [Address Book Service](../abservice.md) provides.

Modifies information about a contact from the Forward List (FL).
For modifying a contact's information from any other list, see the [Contact Sharing Service](../sharingservice.md).

# Client/Request
The template used in this action is described on the [Address Book Service](../abservice.md) main page.

## ABContactUpdate
This element has only one attribute:
* `xmlns`: Is always set to `http://www.msn.com/webservices/AddressBook`.

### abId
This element contains your [Address Book Service](../abservice.md) GUID.

### contacts
This element contains one or multiple `<Contact>` elements.

#### Contact
This element has only one attribute:
* `xmlns`: Is always set to `http://www.msn.com/webservices/AddressBook`.

##### contactId
This element only contains the GUID of the contact you would like to modify.

##### contactInfo
For more information about this element, read the [`<contactInfo>`](contactinfo.md) article.

The most relevant children are:
* `<displayName>`: The new display name for this contact.
* `<isMessengerUser>`: If this is set to `false`, this user is to be treated as a
  e-mail contact instead of an Instant Messaging Contact.

##### propertiesChanged
This element only contains the space delimited list of updated items in `<contactInfo>`.
The valid values are the following:
* `DisplayName`
* `Passport`
* `IsMessengerUser`
* `ContactFirstName`
* `ContactLastName`
* `Comment`
* `MiddleName`
* `ContactPrimaryEmailType`
* `ContactEmail`
* `ContactLocation`
* `ContactPhone`
* `ContactWebSite`
* `Annotation`

# Server/Response
The template used in this action is described on the [Address Book Service](../abservice.md) main page.

## ABContactUpdateResponse
This empty element has only one attribute:
* `xmlns`: Is always set to `http://www.msn.com/webservices/AddressBook`.

# Examples

## Client/Request
```http
POST /abservice/abservice.asmx HTTP/1.1
SOAPAction: http://www.msn.com/webservices/AddressBook/ABContactUpdate
Cache-Control: no-cache
Content-Type: text/xml; charset=utf-8
Content-Length: 1276

<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope
	xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xmlns:xsd="http://www.w3.org/2001/XMLSchema"
	xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"
>
	<soap:Header>
		<ABApplicationHeader
			xmlns="http://www.msn.com/webservices/AddressBook"
		>
			<ApplicationID>996CDE1E-AA53-4477-B943-2BE802EA6166</ApplicationID>
			<IsMigration>false</IsMigration>
			<PartnerScenario>Timer</PartnerScenario>
		</ABApplicationHeader>
		<ABAuthHeader
			xmlns="http://www.msn.com/webservices/AddressBook"
		>
			<ManagedGroupRequest>false</ManagedGroupRequest>
			<TicketToken>t=ticket&amp;p=profile</TicketToken>
		</ABAuthHeader>
	</soap:Header>
	<soap:Body>
		<ABContactUpdate
			xmlns="http://www.msn.com/webservices/AddressBook"
		>
			<abId>00000000-0000-0000-0000-000000000000</abId>
			<contacts>
				<Contact
					xmlns="http://www.msn.com/webservices/AddressBook"
				>
					<contactId>c1f9a363-4ee9-4a33-a434-b056a4c55b98</contactId>
					<contactInfo>
						<displayName>another user</displayName>
					</contactInfo>
					<propertiesChanged>DisplayName <propertiesChanged>
				</Contact>
			</contacts>
		</ABContactUpdate>
	</soap:Body>
</soap:Envelope>
```

## Server/Response
```http
HTTP/1.1 200 OK
Content-Type: text/xml; charset=utf-8
Content-Length: 736

<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope
	xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xmlns:xsd="http://www.w3.org/2001/XMLSchema"
>
	<soap:Header>
		<ServiceHeader
			xmlns="http://www.msn.com/webservices/AddressBook"
		>
			<Version>12.01.1111.0000</Version>
			<CacheKey>12r1;MjAyNC0xMS0xOVQxNzo0Nzo1OS4zMDZa</CacheKey>
			<CacheKeyChanged>true</CacheKeyChanged>
			<PreferredHostName>contacts.example.com</PreferredHostName>
			<SessionId>ecfaf8c7-e388-4571-8641-b061a0ac4bdc</SessionId>
		</ServiceHeader>
	</soap:Header>
	<soap:Body>
		<ABContactUpdateResponse
			xmlns="http://www.msn.com/webservices/AddressBook"
		/>
	</soap:Body>
</soap:Envelope>
```
