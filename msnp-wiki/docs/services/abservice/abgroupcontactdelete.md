# Introduction
`ABGroupContactDelete` is one of the SOAP actions the [Address Book Service](../abservice.md) provides.

Removes a contact in the Forward List (FL) from a contact group.

# Client/Request
The template used in this action is described on the [Address Book Service](../abservice.md) main page.

## ABGroupContactDelete
This element has only one attribute:
* `xmlns:` Is always set to `http://www.msn.com/webservices/AddressBook`.

### abId
This element contains your [Address Book Service](../abservice.md) GUID.

### contacts
This element only contains one or multiple `<Contact>` elements.

#### Contact
This element only contains the `<contactId>` element.

##### contactId
This element only contains the contact's GUID that
you would like to remove from the contact group.

### groupFilter
This element only contains the `<groupIds>` element.

#### groupIds
This element only contains one or multiple `<guid>` elements.

##### guid
This element only contains the group GUIDs
that you would like to remove contacts from.

# Server/Response
The template used in this action is described on the [Address Book Service](../abservice.md) main page.

## ABGroupContactDeleteResponse
This empty element has only one attribute:
* `xmlns:` Is always set to `http://www.msn.com/webservices/AddressBook`.

# Examples

## Client/Request
```http
POST /abservice/abservice.asmx HTTP/1.1
SOAPAction: http://www.msn.com/webservices/AddressBook/ABGroupContactDelete
Cache-Control: no-cache
Content-Type: text/xml; charset=utf-8
Content-Length: 1269

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
			<PartnerScenario>GroupSave</PartnerScenario>
		</ABApplicationHeader>
		<ABAuthHeader
			xmlns="http://www.msn.com/webservices/AddressBook"
		>
			<ManagedGroupRequest>false</ManagedGroupRequest>
			<TicketToken>t=ticket&amp;p=profile</TicketToken>
		</ABAuthHeader>
	</soap:Header>
	<soap:Body>
		<ABGroupContactDelete
			xmlns="http://www.msn.com/webservices/AddressBook"
		>
			<abId>00000000-0000-0000-0000-000000000000</abId>
			<contacts>
				<Contact
					xmlns="http://www.msn.com/webservices/AddressBook"
				>
					<contactId>c1f9a363-4ee9-4a33-a434-b056a4c55b98</contactId>
				</Contact>
			</contacts>
			<groupFilter>
				<groupIds>
				<guid>f60efbe7-94af-4b16-b926-e4e10878d329</guid>
				</groupIds>
			</groupFilter>
		</ABGroupContactDelete>
	</soap:Body>
</soap:Envelope>
```

## Server/Response
```http
HTTP/1.1 200 OK
Content-Type: text/xml; charset=utf-8
Content-Length: 741

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
			<CacheKey>12r1;MjAyNC0xMS0xOVQxNDowOTowNi41MzZa</CacheKey>
			<CacheKeyChanged>true</CacheKeyChanged>
			<PreferredHostName>contacts.example.com</PreferredHostName>
			<SessionId>ecfaf8c7-e388-4571-8641-b061a0ac4bdc</SessionId>
		</ServiceHeader>
	</soap:Header>
	<soap:Body>
		<ABGroupContactDeleteResponse
			xmlns="http://www.msn.com/webservices/AddressBook"
		/>
	</soap:Body>
</soap:Envelope>
```
