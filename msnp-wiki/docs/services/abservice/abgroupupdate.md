# Introduction
`ABGroupUpdate` is one of the SOAP actions the [Address Book Service](../abservice.md) provides.

Changes information about a contact group.

# Client/Request
The template used in this action is described on the [Address Book Service](../abservice.md) main page.

## ABGroupUpdate
This element has only one attribute:
* `xmlns:` Is always set to `http://www.msn.com/webservices/AddressBook`.

### abId
This element contains your [Address Book Service](../abservice.md) GUID.

### groups
This element only contains `<Group>` elements

#### Group
This element contains three children:
* `<groupId>`: The GUID of the group to modify.
* `<groupInfo>`: Explained below.
* `<propertiesChanged>`: A space delimited list of changes made in `<groupInfo>`:
	* `GroupName`

##### groupInfo
This element contains only one child:
* `<name>`: The new name of the group.

# Server/Response
The template used in this action is described on the [Address Book Service](../abservice.md) main page.

## ABGroupUpdateResponse
This empty element has only one attribute:
* `xmlns:` Is always set to `http://www.msn.com/webservices/AddressBook`.

# Examples

## Client/Request
```http
POST /abservice/abservice.asmx HTTP/1.1
SOAPAction: http://www.msn.com/webservices/AddressBook/ABGroupUpdate
Cache-Control: no-cache
Content-Type: text/xml; charset=utf-8
Content-Length: 1184

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
		<ABGroupUpdate
			xmlns="http://www.msn.com/webservices/AddressBook"
		>
			<abId>00000000-0000-0000-0000-000000000000</abId>
			<groups>
				<Group>
					<groupId>f60efbe7-94af-4b16-b926-e4e10878d329</groupId>
					<groupInfo>
						<name>Other People</name>
					</groupInfo>
					<propertiesChanged>GroupName </propertiesChanged>
				</Group>
			</groups>
		</ABGroupUpdate>
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
		<ABGroupUpdateResponse
			xmlns="http://www.msn.com/webservices/AddressBook"
		/>
	</soap:Body>
</soap:Envelope>
```
