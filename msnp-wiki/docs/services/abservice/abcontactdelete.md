# Introduction
`ABContactDelete` is one of the SOAP actions the [Address Book Service](../abservice.md) provides.

Removes a contact from the Forward List (FL).
For removing a member from any other list, read the [`DeleteMember`](../sharingservice/deletemember.md) article.

# Client/Request
The template used in this action is described on the [Address Book Service](../abservice.md) main page.

## ABContactDelete
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
This element only contains the GUID of the contact you would like to remove.

# Server/Response
The template used in this action is described on the [Address Book Service](../abservice.md) main page.

## ABContactDeleteResponse
This empty element has only one attribute:
* `xmlns`: Is always set to `http://www.msn.com/webservices/AddressBook`.

# Examples

## Client/Request
```http
POST /abservice/abservice.asmx HTTP/1.1
SOAPAction: http://www.msn.com/webservices/AddressBook/ABContactDelete
Cache-Control: no-cache
Content-Type: text/xml; charset=utf-8
Content-Length: 1136

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
		<ABContactDelete
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
		</ABContactDelete>
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
			<CacheKey>12r1;MjAyNC0xMS0xOVQxNzo0ODowOS44MDNa</CacheKey>
			<CacheKeyChanged>true</CacheKeyChanged>
			<PreferredHostName>contacts.example.com</PreferredHostName>
			<SessionId>ecfaf8c7-e388-4571-8641-b061a0ac4bdc</SessionId>
		</ServiceHeader>
	</soap:Header>
	<soap:Body>
		<ABContactDeleteResponse
			xmlns="http://www.msn.com/webservices/AddressBook"
		/>
	</soap:Body>
</soap:Envelope>
```
