# Introduction
`ABFindAll` is one of the SOAP actions the [Address Book Service](../abservice.md) provides.

Returns the full list of contacts in the Forward List (FL).
For retrieving information about other lists,
read the [`FindMembership`](../sharingservice/findmembership.md) article.

# Client/Request
The template used in this action is described on the [Address Book Service](../abservice.md) main page.

## ABFindAll
This element has only one attribute:
* `xmlns`: Is always set to `http://www.msn.com/webservices/AddressBook`.

### abId
This element contains your [Address Book Service](../abservice.md) GUID.

### abView
Always set to `Full`.

### deltasOnly
If set to `true`, the `<lastChange>` value is compared against the server to
only provide the updates since the timestamp provided.

### lastChange
This is a ISO 8601 timestamp which denotes the last time you retrieved the
Forward List (FL), comes from the response's
`<createDate>` element inside the `<ab>` element.

# Server/Response

## ABFindAllResponse
This element has only one attribute:
* `xmlns`: Is always set to `http://www.msn.com/webservices/AddressBook`.

This element only contains the `<ABFindAllResult>` element.

### ABFindAllResult

#### groups
This element contains any amount of `<Group>` elements.

##### Group
This element contains five children:
* `<groupId>`: The group's GUID.
* `<groupInfo>`: Described [below](#groupinfo).
* `<propertiesChanged>`: Contains a space delimited list of changed elements in `<groupInfo>`:
	* `GroupName`
* `<fDeleted>`: Is this group deleted? (`true` or `false`).
* `<lastChange>`: The ISO 8601 timestamp of the time this group was last modified.

###### groupInfo
This element contains six children:
* `<annotations>`: This element contains multiple `<Annotation>` elements.
* `<groupType>`: Only known to be set to `c8529ce2-6ead-434d-881f-341e17db3ff8`.
* `<name>`: The group's name
* `<IsNotMobileVisible>`: If this is set to `true`, this group is not shown to mobile clients.
  Otherwise, it is set to `false`.
* `<IsPrivate>`: If this is set to `true`, this group is private. Otherwise, it is set to `false`.
* `<IsFavorite>`: If this is set to `true`, this group is the Favorites group. Otherwise, it is set to `false`.

`<Annotation>` elements contain two children:
* `<Name>`: The key of this annotation:
	* `MSN.IM.Display`: Is this group shown to the Official Client? (`1` or `0`)
* `<Value>`: The value of this annotation.

#### contacts
This element contains any amount of `<Contact>` elements.

##### Contact
This element contains five children:
* `<contactId>`: The GUID of this contact.
* `<contactInfo`: Described on it's [own page](contactinfo.md).
* `<propertiesChanged>`: Contains a space delimited list of changed elements in `<contactInfo>`:
	* `DisplayName`
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
* `<fDeleted>`: Is this contact deleted? (`true` or `false`)
* `<lastChange>`: The ISO 8601 timestamp of the time this contact was last modified.

#### ab
This element contains seven children:
* `<abId>`: Your [Address Book Service](../abservice.md) GUID.
* `<abInfo>`: Described [below](#abinfo).
* `<lastChange>`: The ISO 8601 timestamp of the time a change was last made to the Address Book.
* `<DynamicItemLastChanged>`: The ISO 8601 timestamp of the time any dynamic item was last modified.
* `<RecentActivityItemLastChanged>`: The ISO 8601 timestamp of the time a "recent activity item" was last modified.
* `<createDate>`: The ISO 8601 timestamp of the time this Address Book was created.
* `<propertiesChanged>`: Contains a space delimited list of changed elements in an unknown location.

##### abInfo
This element contains ten children:
* `<ownerPuid>`: This is always `0`.
* `<OwnerCID>`: Your Common ID, an signed 64-bit integer.
* `<ownerEmail>`: Your user handle.
* `<fDefault>`: unknown (`true` or `false`)
* `<joinedNamespace>`: unknown (`true` or `false`)
* `<IsBot>`: Is this account provisioned? (`true` or `false`)
* `<IsParentManaged>`: Is this a children's account? (`true` or `false`)
* `<SubscribeExternalPartner>`: unknown (`true` or `false`)
* `<NotifyExternalPartner>`: unknown (`true` or `false`)
* `<AddressBookType>`: Is always set to `Individual`.

# Examples

## Client/Request
```http
POST /abservice/abservice.asmx HTTP/1.1
SOAPAction: http://www.msn.com/webservices/AddressBook/ABFindAll
Cache-Control: no-cache
Content-Type: text/xml; charset=utf-8
Content-Length: 1066

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
		<ABFindAll
			xmlns="http://www.msn.com/webservices/AddressBook"
		>
			<abId>00000000-0000-0000-0000-000000000000</abId>
			<abView>Full</abView>
			<deltasOnly>false</deltasOnly>
			<lastChange>0001-01-01T00:00:00.0000000-08:00</lastChange>
		</ABFindAll>
	</soap:Body>
</soap:Envelope>
```

## Server/Response
```http
HTTP/1.1 200 OK
Content-Type: text/xml; charset=utf-8
Content-Length: 6511

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
			<CacheKey>12r1;MjAyNC0xMS0yMFQxMToyMDoyNy43MTVa</CacheKey>
			<CacheKeyChanged>true</CacheKeyChanged>
			<PreferredHostName>contacts.example.com</PreferredHostName>
			<SessionId>ecfaf8c7-e388-4571-8641-b061a0ac4bdc</SessionId>
		</ServiceHeader>
	</soap:Header>
	<soap:Body>
		<ABFindAllResponse
			xmlns="http://www.msn.com/webservices/AddressBook"
		>
			<ABFindAllResult>
				<groups>
					<Group>
						<groupId>f60efbe7-94af-4b16-b926-e4e10878d329</groupId>
						<groupInfo>
							<annotations>
								<Annotation>
									<Name>MSN.IM.Display</Name>
								</Annotation>
							</annotations>
							<groupType>c8529ce2-6ead-434d-881f-341e17db3ff8</groupType>
							<name>Friends</name>
							<IsNotMobileVisible>false</IsNotMobileVisible>
							<IsPrivate>false</IsPrivate>
							<IsFavorite>false</IsFavorite>
						</groupInfo>
					</Group>
				</groups>
				<contacts>
					<Contact>
						<contactId>c1f9a363-4ee9-4a33-a434-b056a4c55b98</contactId>
						<contactInfo>
							<contactType>Regular</contactType>
							<quickName>anotheruser</quickName>
							<passportName>anotheruser@hotmail.com</passportName>
							<IsPassportNameHidden>false</IsPassportNameHidden>
							<displayName>another user</displayName>
							<puid>0</puid>
							<groupIds>
								<guid>f60efbe7-94af-4b16-b926-e4e10878d329</guid>
							</groupIds>
							<CID>4388220788362762</CID>
							<IsNotMobileVisible>false</IsNotMobileVisible>
							<isMobileIMEnabled>false</isMobileIMEmabled>
							<isMessengerUser>true</isMessengerUser>
							<isFavorite>false</isFavorite>
							<isSmtp>false</isSmtp>
							<hasSpace>false</hasSpace>
							<spotWatchState>NoDevice</spotWatchState>
							<birthdate>0001-01-01T00:00:00</birthdate>
							<primaryEmailType>ContactEmailPersonal</primaryEmailType>
							<PrimaryLocation>ContactLocationPersonal</PrimaryLocation>
							<PrimaryPhone>ContactPhonePersonal</PrimaryPhone>
							<IsPrivate>false</IsPrivate>
							<Gender>Unspecified</Gender>
							<TimeZone>None</TimeZone>
						</contactInfo>
						<propertiesChanged />
						<fDeleted>false</fDeleted>
						<lastChange>2024-11-20T11:43:00.1230000-08:00</lastChange>
					</Contact>
					<Contact>
						<contactId>a47e39cf-312c-4100-94a6-f2b33adf5b68</contactId>
						<contactInfo>
							<phones>
								<ContactPhone>
									<contactPhoneType>ContactPhoneMobile</contactPhoneType>
									<number>15551111222</number>
									<isMessengerEnabled>true</isMessengerEnabled>
									<propertiesChanged />
								</ContactPhone>
							</phones>
							<contactType>Regular</contactType>
							<quickName>john</quickName>
							<IsPassportNameHidden>false</IsPassportNameHidden>
							<displayName>john</displayName>
							<puid>0</puid>
							<CID>0</CID>
							<IsNotMobileVisible>false</IsNotMobileVisible>
							<isMobileIMEnabled>true</isMobileIMEnabled>
							<isMessengerUser>false</isMessengerUser>
							<isFavorite>false</isFavorite>
							<isSmtp>false</isSmtp>
							<hasSpace>false</hasSpace>
							<spotWatchState>NoDevice</spotWatchState>
							<birthdate>0001-01-01T00:00:00</birthdate>
							<primaryEmailType>ContactEmailPersonal</primaryEmailType>
							<PrimaryLocation>ContactLocationPersonal</PrimaryLocation>
							<PrimaryPhone>ContactPhoneMobile</PrimaryPhone>
							<IsPrivate>false</IsPrivate>
							<Gender>Unspecified</Gender>
							<TimeZone>None</TimeZone>
						</contactInfo>
						<propertiesChanged />
						<fDeleted>false</fDeleted>
						<lastChange>2024-11-20T11:44:40.4560000-08:00</lastChange>
					</Contact>
					<Contact>
						<contactId>c867a811-089f-4c4c-a601-e983881f003a</contactId>
						<contactInfo>
							<annotations>
								<Annotation>
									<Name>MSN.IM.MBEA</Name>
									<Value>0</Value>
								</Annotation>
								<Annotation>
									<Name>MSN.IM.GTC</Name>
									<Value>1</Value>
								</Annotation>
								<Annotation>
									<Name>MSN.IM.BLP</Name>
									<Value>1</Value>
								</Annotation>
							</annotations>
							<phones>
								<ContactPhone>
									<contactPhoneType>ContactPhonePersonal</contactPhoneType>
									<number>123 (4567)</number>
								</ContactPhone>
							</phones>
							<contactType>Me</contactType>
							<quickName>Q</quickName>
							<passportName>example@hotmail.com</passportName>
							<IsPassportNameHidden>false</IsPassportNameHidden>
							<displayName>example user</displayName>
							<puid>0</puid>
							<CID>4294967298</CID>
							<IsNotMobileVisible>false</IsNotMobileVisible>
							<isMobileIMEnabled>false</isMobileIMEnabled>
							<isMessengerUser>false</isMessengerUser>
							<isFavorite>false</isFavorite>
							<isSmtp>false</isSmtp>
							<hasSpace>false</hasSpace>
							<spotWatchState>NoDevice</spotWatchState>
							<birthdate>0001-01-01T00:00:00</birthdate>
							<primaryEmailType>ContactEmailPersonal</primaryEmailType
							<PrimaryLocation>ContactLocationPersonal</PrimaryLocation>
							<PrimaryPhone>ContactPhonePersonal</PrimaryPhone>
							<IsPrivate>false</IsPrivate>
							<Gender>Unspecified</Gender>
							<TimeZone>None</TimeZone>
						</contactInfo>
						<propertiesChanged />
						<fDeleted>false</fDeleted>
						<lastChange>2024-11-20T11:26:00.4180000-08:00</lastChange>
					</Contact>
				</contacts>
				<ab>
					<abId>00000000-0000-0000-0000-000000000000</abId>
					<abInfo>
						<ownerPuid>0</ownerPuid>
						<OwnerCID>4294967298</OwnerCID>
						<ownerEmail>example@hotmail.com</ownerEmail>
						<fDefault>true</fDefault>
						<joinedNamespace>false</joinedNamespace>
						<IsBot>false</IsBot>
						<IsParentManaged>false</IsParentManaged>
						<SubscribeExternalPartner>false</SubscribeExternalPartner>
						<NotifyExternalPartner>false</NotifyExternalPartner>
						<AddressBookType>Individual</AddressBookType>
					</abInfo>
					<lastChange>2024-11-20T11:26:00.4180000-08:00</lastChange>
					<DynamicItemLastChanged>0001-01-01T00:00:00</DynamicItemLastChanged>
					<createDate>2024-10-10T20:38:51.0000000-08:00</createDate>
				</ab>
			</ABFindAllResult>
		</ABFindAllResponse>
	</soap:Body>
</soap:Envelope>
```
