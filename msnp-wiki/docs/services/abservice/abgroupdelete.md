# Introduction
`ABGroupDelete` is one of the SOAP actions the [Address Book Service](../abservice.md) provides.

Deletes a contact group.

# Client/Request
The template used in this action is described on the [Address Book Service](../abservice.md) main page.

## ABGroupDelete
This element has only one attribute:
* `xmlns:` Is always set to `http://www.msn.com/webservices/AddressBook`.

### abId
This element contains your [Address Book Service](../abservice.md) GUID.

### groupFilter
This element only contains the `<groupIds>` element.

#### groupIds
This element only contains one or multiple `<guid>` element(s).

##### guid
This element only contains the GUID of the group you would like to delete.

# Server/Response
The template used in this action is described on the [Address Book Service](../abservice.md) main page.

## ABGroupDeleteResponse
This empty element has only one attribute:
* `xmlns:` Is always set to `http://www.msn.com/webservices/AddressBook`.

# Examples

## Client/Request
```http
POST /abservice/abservice.asmx HTTP/1.1
SOAPAction: http://www.msn.com/webservices/AddressBook/ABGroupDelete
Cache-Control: no-cache
Content-Type: text/xml; charset=utf-8
Content-Length: 1068

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
		<ABGroupDelete
			xmlns="http://www.msn.com/webservices/AddressBook"
		>
			<abId>00000000-0000-0000-0000-000000000000</abId>
			<groupFilter>
				<groupIds>
					<guid>f60efbe7-94af-4b16-b926-e4e10878d329</guid>
				</groupIds>
			</groupFilter>
		</ABGroupDelete>
	</soap:Body>
</soap:Envelope>
```

## Server/Response
```http
HTTP/1.1 200 OK
Content-Type: text/xml; charset=utf-8
Content-Length: 734

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
		<ABGroupDeleteResponse
			xmlns="http://www.msn.com/webservices/AddressBook"
		/>
	</soap:Body>
</soap:Envelope>
```
