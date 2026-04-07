# Introduction
`ABContactAdd` is one of the SOAP actions the [Address Book Service](../abservice.md) provides.

Adds a user to the Forward List (FL).
For adding a user to any other list, read the [`AddMember`](../sharingservice/addmember.md) article.

# Client/Request
The template used in this action is described on the [Address Book Service](../abservice.md) main page.

## ABContactAdd
This element has only one attribute:
* `xmlns`: Is always set to `http://www.msn.com/webservices/AddressBook`.

### abId
This element contains your [Address Book Service](../abservice.md) GUID.

### contacts
This element contains one or multiple `<Contact>` elements.

#### Contact
This element has only one attribute:
* `xmlns`: Is always set to `http://www.msn.com/webservices/AddressBook`.

##### contactInfo
For more information about this element, read the [`<contactInfo>`](contactinfo.md) article.

The relevant elements are:
* `<passportName>`: The user handle that you would like to add.
* `<isMessengerUser>`: Is the user I am adding a part of the Messenger Service Network?
  If they are, set to `true`, otherwise set to `false`.
* `<contactType>`: (Optional?) The type of contact you'd like to add:
	* `LivePending`: A Messenger Service user.
	* `Regular`: A user from another service.
* `<emails>`: Used exclusively if this is a email-only contact.
* `<isSmtp>`: Used with `<phones>` if this is a phone-only contact.
* `<phones>`: Used with `<isSmtp>` if this is a phone-only contact.

### options
This element contains one child:
* `<EnableAllowListManagement>`: Usually only set to `true`.

# Server/Response
The template used in this action is described on the [Address Book Service](../abservice.md) main page.

## ABContactAddResponse
This element has only one attribute:
* `xmlns`: Is always set to `http://www.msn.com/webservices/AddressBook`.

This element only contains the `<ABContactAddResult>` element.

### ABContactAddResult
This element only contains the `<guid>` element.

They may be the same amount of `<guid>` elements as the amount of `<Contact>` elements you specify,
but this behavour is yet to be confirmed.

#### guid
The GUID of the contact you have added.

# Examples

## Client/Request
```http
POST /abservice/abservice.asmx HTTP/1.1
SOAPAction: http://www.msn.com/webservices/AddressBook/ABContactAdd
Cache-Control: no-cache
Content-Type: text/xml; charset=utf-8
Content-Length: 1350

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
			<PartnerScenario>ContactSave</PartnerScenario>
		</ABApplicationHeader>
		<ABAuthHeader
			xmlns="http://www.msn.com/webservices/AddressBook"
		>
			<ManagedGroupRequest>false</ManagedGroupRequest>
			<TicketToken>t=ticket&amp;p=profile</TicketToken>
		</ABAuthHeader>
	</soap:Header>
	<soap:Body>
		<ABContactAdd
			xmlns="http://www.msn.com/webservices/AddressBook"
		>
			<abId>00000000-0000-0000-0000-000000000000</abId>
			<contacts>
				<Contact
					xmlns="http://www.msn.com/webservices/AddressBook"
				>
					<contactInfo>
						<passportName>anotheruser@hotmail.com</passportName>
						<isMessengerUser>true</isMessengerUser>
						<contactType>LivePending</contactType>
					</contactInfo>
				</Contact>
			</contacts>
			<options>
				<EnableAllowListManagement>true</EnableAllowListManagement>
			</options>
		</ABContactAdd>
	</soap:Body>
</soap:Envelope>
```

## Server/Response
```http
HTTP/1.1 200 OK
Content-Type: text/xml; charset=utf-8
Content-Length: 861

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
		<ABContactAddResponse
			xmlns="http://www.msn.com/webservices/AddressBook"
		>
			<ABContactAddResult>
				<guid>c1f9a363-4ee9-4a33-a434-b056a4c55b98</guid>
			</ABContactAddResult>
		</ABContactAddResponse>
	</soap:Body>
</soap:Envelope>
```
