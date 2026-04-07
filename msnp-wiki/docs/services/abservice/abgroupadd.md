# Introduction
`ABGroupAdd` is one of the SOAP actions the [Address Book Service](../abservice.md) provides.

Creates a contact group.

# Client/Request
The template used in this action is described on the [Address Book Service](../abservice.md) main page.

## ABGroupAdd
This element has only one attribute:
* `xmlns:` Is always set to `http://www.msn.com/webservices/AddressBook`.

### abId
This element contains your [Address Book Service](../abservice.md) GUID.

### groupAddOptions
This element has only one child:
* `<fRenameOnMsgrConflict>`: Should this group be renamed if it conflicts with
  a group that already exists in the Messenger Service (`true` or `false`)?

### groupInfo
This element only contains the `<GroupInfo>` element.

#### GroupInfo
This element contains four children:
* `<name>`: The name of the group.
* `<groupType>`: The GUID type of group:
	* `C8529CE2-6EAD-434d-881F-341E17DB3FF8`: A contact group.
* `<fMessenger>`: Unknown purpose (`true` or `false`).

##### annotations
This element only contains one or multiple `<Annotation>` element(s).

###### Annotation
This element only has two children:
* `<Name>`: The key of this annotation.
* `<Value>`: The value of this annotation.

Usually only used to set `MSN.IM.Display` to `1`.

# Server/Response
The template used in this action is described on the [Address Book Service](../abservice.md) main page.

## ABGroupAddResponse
This element has only one attribute:
* `xmlns:` Is always set to `http://www.msn.com/webservices/AddressBook`.

### ABGroupAddResult
This element only contains the `<guid>` element.

#### guid
This element only contains the GUID of the newly created group.

# Examples

## Client/Request
```http
POST /abservice/abservice.asmx HTTP/1.1
SOAPAction: http://www.msn.com/webservices/AddressBook/ABGroupAdd
Cache-Control: no-cache
Content-Type: text/xml; charset=utf-8
Content-Length: 1369

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
		<ABGroupAdd
			xmlns="http://www.msn.com/webservices/AddressBook"
		>
			<abId>00000000-0000-0000-0000-000000000000</abId>
			<groupAddOptions>
				<fRenameOnMsgrConflict>false</fRenameOnMsgrConflict>
			</groupAddOptions>
			<groupInfo>
				<GroupInfo>
					<name>Friends</name>
					<groupType>C8529CE2-6EAD-434d-881F-341E17DB3FF8</groupType>
					<fMessenger>false</fMessenger>
					<annotations>
					<Annotation>
						<Name>MSN.IM.Display</Name>
						<Value>1</Value>
					</Annotation>
					</annotations>
				</GroupInfo>
			</groupInfo>
		</ABGroupAdd>
	</soap:Body>
</soap:Envelope>
```

## Server/Response
```http
HTTP/1.1 200 OK
Content-Type: text/xml; charset=utf-8
Content-Length: 853

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
			<CacheKey>12r1;MjAyNC0xMS0xOVQxNzo1NTo1Ni45NDla</CacheKey>
			<CacheKeyChanged>true</CacheKeyChanged>
			<PreferredHostName>contacts.example.com</PreferredHostName>
			<SessionId>ecfaf8c7-e388-4571-8641-b061a0ac4bdc</SessionId>
		</ServiceHeader>
	</soap:Header>
	<soap:Body>
		<ABGroupAddResponse
			xmlns="http://www.msn.com/webservices/AddressBook"
		>
			<ABGroupAddResult>
				<guid>f60efbe7-94af-4b16-b926-e4e10878d329</guid>
			</ABGroupAddResult>
		</ABGroupAddResponse>
	</soap:Body>
</soap:Envelope>
```
