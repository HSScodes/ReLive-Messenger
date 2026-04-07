# Introduction
`AddMember` is one of the SOAP actions the [Contact Sharing Service](../sharingservice.md) provides.

Adds a user to the Allow List (AL), Block List (BL),
or if the user is in the Pending List (PL), the Reverse List (RL).
For adding a user to the Forward List (FL), read the [`ABContactAdd`](../abservice/abcontactadd.md) article.

# Client/Request
The template used in this action is described on the [Address Book Service](../abservice.md) main page.

## AddMember
This element has only one attribute:
* `xmlns:` Is always set to `http://www.msn.com/webservices/AddressBook`.

### serviceHandle
This element contains three children:
* `<Id>`: This is always set to `0`.
* `<Type>`: The type of this member:
	* `Messenger`: This is a Messenger contact.
	* `Profile`: This is your profile.
* `<ForeignId>`: If `<Type>` is `Profile`, this should be `MyProfile`,
  otherwise leave empty but do not convert to an empty element.

### memberships
This element only contains `<Membership>` elements.

#### Membership
This element contains two children:
* `<MemberRole>`: The type of list:
	* `Allow`: The Allow List (AL).
	* `Block`: The Block List (BL).
	* `Reverse`: The Reverse List (RL).
	* `ProfileExpression`: Your profile.
* `<Members>`: Explained below.

##### Members
This element only contains `<Member>` elements.

###### Member
This element has two attributes:
* `xsi:type`: The type of this `<Member>`:
	* `PassportMember`
	* `EmailMember`
	* `PhoneMember`
	* `RoleMember`: Only valid for `ProfileExpression`.
* `xmlns:xsi`: This is always set to `http://www.w3.org/2001/XMLSchema-instance`.

This element contains two children:
* `<Type>`: The type of this `<Member>`:
	* `Passport`
	* `Email`
	* `Phone`
* `<State>`: This is usually only set to `Accepted`, but `Pending` is a valid value.
* `<Deleted>`: Should this member be deleted? (Only set to `true` in `UpdateMember`?)

This element also contains one of the following mutually exclusive children.
1. `<PassportName>`: The user handle associated with this membership.
2. `<Email>`: The e-mail address associated with this membership.
3. `<PhoneNumber>`: The phone number associated with this membership,
   in the format of the full phone number (including country code) prefixed with a `+`.

This element also contains the following children IF the role is set to `ProfileExpression`:
* `<Id>`: Always `Allow`.
* `<DefiningService>`: Contains the following:
	* `<Id>`: Always `0`.
	* `<Type>`: Always `Messenger`.
	* `<ForeignId>`: Always empty content, but not an empty element.
* `<MaxRoleRecursionDepth>`: Always `0`.
* `<MaxDegreesSeparationDepth>`: Always `0`.

# Server/Response
The template used in this action is described on the [Address Book Service](../abservice.md) main page.

## AddMemberResponse
This empty element has only one attribute:
* `xmlns:` Is always set to `http://www.msn.com/webservices/AddressBook`.

# Examples

## Client/Request
```http
POST /abservice/SharingService.asmx HTTP/1.1
SOAPAction: http://www.msn.com/webservices/AddressBook/AddMember
Cache-Control: no-cache
Content-Type: text/xml; charset=utf-8
Content-Length: 1352

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
		<AddMember
			xmlns="http://www.msn.com/webservices/AddressBook"
		>
			<serviceHandle>
				<Id>0</Id>
				<Id>Messenger</Id>
				<ForeignId></ForeignId>
			</serviceHandle>
			<memberships>
				<Membership>
					<MemberRole>Allow</MemberRole>
					<Members>
						<Member
							xsi:type="PassportMember"
						>
							<Type>Passport</Type>
							<State>Accepted</State>
							<Deleted>false</Deleted>
							<PassportName>anotheruser@hotmail.com</PassportName>
						</Member>
					</Members>
				</Membership>
			</memberships>
		</AddMember>
	</soap:Body>
</soap:Envelope>
```

## Server/Response
```http
HTTP/1.1 200 OK
Content-Type: text/xml; charset=utf-8
Content-Length: 730

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
		<AddMemberResponse
			xmlns="http://www.msn.com/webservices/AddressBook"
		/>
	</soap:Body>
</soap:Envelope>
```
