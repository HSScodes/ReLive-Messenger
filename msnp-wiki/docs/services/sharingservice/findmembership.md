# Introduction
`FindMembership` is one of the SOAP actions the [Contact Sharing Service](../sharingservice.md) provides.

Returns the full list of members in the Allow List (AL), Block List (BL), Reverse List (RL) and Pending List (PL).
For retrieving information about the Forward List (FL), read the [`ABFindAll`](../abservice/abfindall.md) article.

# Client/Request
The template used in this action is described on the [Address Book Service](../abservice.md) main page.

## FindMembership
This element has only one attribute:
* `xmlns`: Is always set to `http://www.msn.com/webservices/AddressBook`.

### serviceFilter
This element only contains the `<Types>` element.

#### Types
This element contains one or multiple `<ServiceType>` elements.

##### ServiceType
Can be any of the following:
* `Messenger`
* `Invitation`
* `SocialNetwork`
* `Space`
* `Profile`

### View
Always set to `Full`.

### deltasOnly
If set to `true`, the `<lastChange>` value is compared against the server
to only provide the updates since the timestamp provided.

### lastChange
This is a ISO 8601 timestamp which denotes the last time you retrieved the memberships,
comes from the response's `<LastChange>` element inside the `<OwnerNamespace>` element.

# Server/Response
The template used in this action is described on the [Address Book Service](../abservice.md) main page.

## FindMembershipResponse
This element only contains the `<FindMembershipResult>` element.

### FindMembershipResult
This element only contains both the `<Services>` and the `<OwnerNamespace>` element.

#### Services
This element only contains one or multiple `<Service>` elements.

##### Service
This element contains one or multiple [`<Memberships>`](#memberships) elements,
and one [`<Info>`](#info-1) element.

#### OwnerNamespace
This element contains four children:
* `<Info>`: Described [below](#info).
* `<Changes>`: A space delimited list of elements changed in an unknown location.
* `<CreateDate>`: The ISO 8601 timestamp of the time this member was created.
* `<LastChange>`: The ISO 8601 timestamp of the time a change was last made to the memberships.

##### Info
This element contains four children:
* `<Handle>`: Described [below](#handle).
* `<CreatorPuid>`: This is always set to `0`.
* `<CreatorCID>`: The Common ID of this member.
* `<CreatorPassportName>`: The user handle of this member.

###### Handle
This element contains three children:
* `<Id>`: The [Address Book Service](../abservice.md) GUID.
* `<IsPassportNameHidden>`: This is always set to `false`.
* `<CID>`: This is always set to `0`.

# [children of Service]
These elements are the children of the [`<Service>`](#service) element.

## Memberships
This element only contains one or multiple `<Membership>` elements.

### Membership
This element has three children:
* `<MemberRole>`: The type of list:
	* `Allow`: The Allow List (AL).
	* `Block`: The Block List (BL).
	* `Reverse`: The Reverse List (RL).
* `<Members>`: Explained [below](#members).
* `<MembershipIsComplete>`: If this is the full list of `<Members>` in this `<Membership>`,
  set to `true`, otherwise, set to `false`.

#### Members
This element only contains one or multiple `<Member>` elements.

### Handle
This element has three children:
* `Id`: The Network ID of the `<Service>`.
* `Type`: The type of this `<Service>`:
	* `Messenger`: The `<Memberships>` of this `<Service>` are for the Messenger Service.
* `ForeignId`: Unknown, usually empty:
	* `MyProfile`: The `<memberships>` of this `<Service>` are for my roaming profile.

#### Member
This element has only one attribute:
* `xsi:type`: The type of this `<Member>`:
	* `PassportMember`
	* `EmailMember`
	* `PhoneMember`

This element contains seven children:
* `<Type>`: The type of this `<Member>`:
	* `Passport`
	* `Email`
	* `Phone`
* `<State>`: This is usually only set to `Accepted`.
* `<Deleted>`: Has this member been deleted? (`true` or `false`).
* `<LastChanged>`: The ISO 8601 timestamp of the time this member was last modified.
* `<JoinedDate>`: The ISO 8601 timestamp of the time when this member joined the service.
* `<ExpirationDate>`: The ISO 8601 timestamp of the time when this member expires.
  Set to `0001-01-01T00:00:00` to disable this behaviour.
* `<Changes>`: A space delimited list of elements changed in an unknown place.

This element also contains one of the following mutually exclusive children:
1) `<PassportName>`: The user handle associated with this membership.
2) `<Email>`: The e-mail address associated with this membership.
3) `<PhoneNumber>`: The phone number associated with this membership.

This element also contains the following five children IF the `<Type>` is set to `Passport`:
* `<IsPassportNameHidden>`: Are the contents of `<PassportName>` hidden to the user (`true` or `false`)?
* `<PassportId>`: This is always set to `0`.
* `<CID>`: The Common ID of this member, which is a signed 64-bit integer.
* `<PassportChanges>`: A space delimited list of elements changed in an unknown place.
* `<LookedupByCID>`: Did we search for this contact using their `<CID>` (`true` or `false`)?

This element may optionally contain the child:
* `<DisplayName>`: The current display name of the member.
  (Only seen in `Reverse` and `Pending` Member roles)

## Info
This element has four children:
* `<InverseRequired>`: Always set to `false`.
* `<AuthorizationCriteria>`: A colon delimited list of allowed members of this service:
	* `Everyone`: Everyone.
	* `2ndDegreeSocNet`: Second-degree social network. (TODO: What does this mean, exactly?)
	* `MsgrAllow`: The members of the Messenger Allow List (AL).
* `<IsBot>`: Is this membership list provided to a provisioned account? (`true` or `false`).

# Examples

## Client/Request
```http
POST /abservice/abservice.asmx HTTP/1.1
SOAPAction: http://www.msn.com/webservices/AddressBook/FindMembership
Cache-Control: no-cache
Content-Type: text/xml; charset=utf-8
Content-Length: 1125

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
		<FindMembership
			xmlns="http://www.msn.com/webservices/AddressBook"
		>
			<serviceFilter>
				<Types>
					<ServiceType>Messenger</ServiceType>
				</Types>
			</serviceFilter>
			<View>Full</View>
			<deltasOnly>false</deltasOnly>
			<lastChange>0001-01-01T00:00:00.0000000-08:00</lastChange>
		</FindMembership>
	</soap:Body>
</soap:Envelope>
```

## Server/Response
```http
HTTP/1.1 200 OK
Content-Type: text/xml; charset=utf-8
Content-Length: 4132

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
		<FindMembershipResponse
			xmlns="http://www.msn.com/webservices/AddressBook"
		>
			<FindMembershipResult>
				<Services>
					<Service>
						<Memberships>
							<Membership>
								<MemberRole>Allow</MemberRole>
								<Members>
									<Member
										xsi:type="PassportMember"
									>
										<MembershipId>1</MembershipId>
										<Type>Passport</Type>
										<State>Accepted</State>
										<Deleted>false</Deleted>
										<LastChanged>2024-11-20T12:58:02.4680000-08:00</LastChanged>
										<JoinedDate>2024-10-10T20:38:51.0000000-08:00</JoinedDate>
										<ExpirationDate>0001-01-01T00:00:00</ExpirationDate>
										<Changes />
										<PassportName>anotheruser@hotmail.com</PassportName>
										<IsPassportNameHidden>false</IsPassportNameHidden>
										<PassportId>0</PassportId>
										<CID>4388220788362762</CID>
										<PassportChanges />
										<LookedupByCID>false</LookedupByCID>
									</Member>
									<Member
										xsi:type="PhoneMember"
									>
										<MembershipId>3</MembershipId>
										<Type>Phone</Type>
										<State>Accepted</State>
										<Deleted>false</Deleted>
										<LastChanged>2024-11-20T12:58:02.4680000-08:00</LastChanged>
										<JoinedDate>2024-10-22T21:40:16.0000000-08:00</JoinedDate>
										<ExpirationDate>0001-01-01T00:00:00</ExpirationDate>
										<Changes />
										<PhoneNumber>15551111222</PhoneNumber>
									</Member>
								</Members>
								<MembershipIsComplete>true</MembershipIsComplete>
							</Membership>
							<Membership>
								<MemberRole>Reverse</MemberRole>
								<Members>
									<Member
										xsi:type="PassportMember"
									>
										<MembershipId>2</MembershipId>
										<Type>Passport</Type>
										<DisplayName>another user</DisplayName>
										<State>Accepted</State>
										<Deleted>false</Deleted>
										<LastChanged>2024-11-20T12:58:02.4680000-08:00</LastChanged>
										<JoinedDate>2024-10-10T20:38:51.0000000-08:00</JoinedDate>
										<ExpirationDate>0001-01-01T00:00:00</ExpirationDate>
										<Changes />
										<PassportName>anotheruser@hotmail.com</PassportName>
										<IsPassportNameHidden>false</IsPassportNameHidden>
										<PassportId>0</PassportId>
										<CID>4388220788362762</CID>
										<PassportChanges />
										<LookedupByCID>false</LookedupByCID>
									</Member>
								</Members>
								<MembershipIsComplete>true</MembershipIsComplete>
							</Membership>
						</Memberships>
						<Info>
							<Handle>
								<Id>1</Id>
								<Type>Messenger</Type>
								<ForeignId />
							</Handle>
							<InverseRequired>false</InverseRequired>
							<AuthorizationCriteria>Everyone</AuthorizationCriteria>
							<IsBot>false</IsBot>
						</Info>
						<Changes />
						<LastChange>2024-11-20T12:58:02.4680000-08:00</LastChange>
						<Deleted>false</Deleted>
					</Service>
				</Services>
				<OwnerNamespace>
					<Info>
						<Handle>
							<Id>00000000-0000-0000-0000-000000000000</Id>
							<IsPassportNameHidden>false</IsPassportNameHidden>
							<CID>0</CID>
						</Handle>
						<CreatorPuid>0</CreatorPuid>
						<CreatorCID>4294967298</CreatorCID>
						<CreatorPassportName>example@hotmail.com</CreatorPassportName>
					</Info>
					<Changes />
					<CreateDate>2024-10-10T20:38:51.0000000-08:00</CreateDate>
					<LastChange>2024-11-20T12:58:02.4680000-08:00</LastChange>
				</OwnerNamespace>
			</FindMembershipResult>
		</FindMembershipResponse>
	</soap:Body>
</soap:Envelope>
```
