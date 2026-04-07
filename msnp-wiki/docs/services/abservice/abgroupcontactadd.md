# Introduction
`ABGroupContactAdd` is one of the SOAP actions the [Address Book Service](../abservice.md) provides.

Adds a contact from the Forward List (FL) to a contact group.

# Client/Request
The template used in this action is described on the [Address Book Service](../abservice.md) main page.

## ABGroupContactAdd
This element has only one attribute:
* `xmlns:` Is always set to `http://www.msn.com/webservices/AddressBook`.

### abId
This element contains your [Address Book Service](../abservice.md) GUID.

### groupFilter
This element only contains the `<groupIds>` element.

#### groupIds
This element only contains one or multiple `<guid>` element(s).

##### guid
The GUID of the group you'd like to add a contact to.

### contacts
This element only contains the `<Contact>` element.

#### Contact
This element only contains the [`<contactInfo>`](contactinfo.md) element.

This element has one optional child:
* `<contactId>`: Used to add an existing contact to a group.

##### contactInfo
*NOTE: This element is only used when adding a new contact to a group.*

For more information about this element, read the [`<contactInfo>`](contactinfo.md) article.

The relevant elements are:
* `<isSmtp>`: Used with `<phones>` or `<emails>` if this is a new contact
  outside of the Messenger Network.
* `<emails>`: Used with `<isSmtp>` if this is a new email-only contact.
* `<phones>`: Used with `<isSmtp>` if this is a new phone-only contact.


### groupContactAddOptions
This element has two children:
* `<fGenerateMissingQuickName>`: Should this action generate the `<quickName>`
  in the `<contactInfo>` element (`true` or `false`).
* `<EnableAllowListManagement>`: Usually only set to `true`.

# Server/Response
The template used in this action is described on the [Address Book Service](../abservice.md) main page.

## ABGroupContactAddResponse
This element has only one attribute:
* `xmlns:` Is always set to `http://www.msn.com/webservices/AddressBook`.

### ABGroupContactAddResult
This element only contains the `<guid>` element.

#### guid
This element contains the GUID of the contact that was added to the group.

# Examples

## Client/Request
```http
POST /abservice/abservice.asmx HTTP/1.1
SOAPAction: http://www.msn.com/webservices/AddressBook/ABGroupContactAdd
Cache-Control: no-cache
Content-Type: text/xml; charset=utf-8
Content-Length: 1264

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
		<ABGroupContactAdd
			xmlns="http://www.msn.com/webservices/AddressBook"
		>
			<abId>00000000-0000-0000-0000-000000000000</abId>
			<groupFilter>
				<groupIds>
				<guid>f60efbe7-94af-4b16-b926-e4e10878d329</guid>
				</groupIds>
			</groupFilter>
			<contacts>
				<Contact
					xmlns="http://www.msn.com/webservices/AddressBook"
				>
					<contactId>c1f9a363-4ee9-4a33-a434-b056a4c55b98</contactId>
				</Contact>
			</contacts>
		</ABGroupContactAdd>
	</soap:Body>
</soap:Envelope>
```

## Server/Response
```http
HTTP/1.1 200 OK
Content-Type: text/xml; charset=utf-8
Content-Length: 881

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
		<ABGroupContactAddResponse
			xmlns="http://www.msn.com/webservices/AddressBook"
		>
			<ABGroupContactAddResult>
				<guid>c1f9a363-4ee9-4a33-a434-b056a4c55b98</guid>
			</ABGroupContactAddResult>
		</ABGroupContactAddResponse>
	</soap:Body>
</soap:Envelope>
```
