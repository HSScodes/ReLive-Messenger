# Introduction
The Address Book Service (abservice), also known as the Address Book Clearing House (ABCH) is a SOAP (XML) Web Service.
It was introduced with [MSNP8](../versions/msnp8.md).

It manages the link(s) between the E-mail Service Address Book and the Forward List (FL).

It's default HTTP URL is `http://contacts.msn.com/abservice/abservice.asmx`.
It's default HTTPS URL is `https://contacts.msn.com/abservice/abservice.asmx`.

Related: [Contact Sharing Service](sharingservice.md) (for other List's members).

# Authentication
This service requires Passport Authentication, either using [Passport SSI 1.4](passport14.md) or [Passport SOAP (RST)](rst.md).

There are two ways to authenticate.

## Using Cookies
The easiest way to authenticate is by setting the `MSPAuth` cookie to the MSPAuth value from your Passport Compact Token (everything after `t=` and before `&p=`)

This can be done using a token for either `contacts.msn.com` or `messenger.msn.com`.

## Using SOAP
Clients from MSNP15 and up use SOAP to authenticate with the service. See the [ABAuthHeader](#abauthheader) section for more info.

This method of authentication only works with a token for `contacts.msn.com`.

# Actions
*All actions listed have the prefix of
`http://www.msn.com/webservices/AddressBook/`.*

* [ABFindAll](abservice/abfindall.md) (internal name: `Contacts.Pull`)
* [ABContactAdd](abservice/abcontactadd.md) (internal name: `Contacts.Push.Contact.Add`)
* [ABContactDelete](abservice/abcontactdelete.md) (internal name: `Contacts.Push.Contact.Delete`)
* [ABContactUpdate](abservice/abcontactupdate.md) (internal name: `Contacts.Push.Contact.Update`)
* [ABGroupContactAdd](abservice/abgroupcontactadd.md) (internal name: `Contacts.Push.Contact.AddToGroup`)
* [ABGroupContactDelete](abservice/abgroupcontactdelete.md) (internal name: `Contacts.Push.Contact.DeleteFromGroup`)
* [ABGroupAdd](abservice/abgroupadd.md) (internal name: `Contacts.Push.Group`)
* [ABGroupDelete](abservice/abgroupdelete.md) (internal name: `Contacts.Push.Group.Delete`)
* [ABGroupUpdate](abservice/abgroupupdate.md) (internal name: `Contacts.Push.Contact.Edit`)

## Actions that we don't know much about
* ABFind (internal name: `Contacts.FindId`)
* ABAdd (internal name: `Contacts.AddAb`)
* ABDelete (internal name: `Contacts.DeleteAb`)
* ABFindByContacts (internal name: `Contacts.Pull.Id`)
* UpdateDynamicItem (internal name: `Contacts.Push.DynamicItem.Edit`)

# Shared Templates
This is used by all Actions listed, as far as we know.
The following also applies to the [Contact Sharing Service](sharingservice.md).

## Client/Request
The following sub-headings are XML elements for the client's request.

### soap:Envelope
This element has four attributes:
* `xmlns:soap`: Is always set to `http://schemas.xmlsoap.org/soap/envelope/`.
* `xmlns:xsi`: Is always set to `http://www.w3.org/2001/XMLSchema-instance`.
* `xmlns:xsd`: Is always set to `http://www.w3.org/2001/XMLSchema`.
* `xmlns:soapenc`: Is always set to `http://schemas.xmlsoap.org/soap/encoding/`.

#### soap:Header
This element only serves to host the `<ABApplicationHeader>` and `<ABAuthHeader>` elements.

##### ABApplicationHeader
This element has only one attribute:
* `xmlns`: Is always set to `http://www.msn.com/webservices/AddressBook`.

This element has three children:
* `<ApplicationID>`: The GUID of the client that sent the request for this action.
* `<IsMigration>`: If this request is part of the ABCH Migration process.
  If it is, set to `true`, otherwise set to `false`.
* `<PartnerScenario>`: What caused this request to happen:
	* `Initial`: This is the initial request to this action.
	* `Timer`: This request was done automatically on a timer.
	* `ContactSave`: When the modified contact is saved by the client.
	* `MessengerPendingList`: Managing the Pending List (PL).
	* `ContactMsgrAPI`: General Messenger API.
	* `BlockUnblock`: Block or unblock of this user.
	* `GroupSave`: When the modified group is saved by the client.

##### ABAuthHeader
This element has only one attribute:
* `xmlns`: Is always set to `http://www.msn.com/webservices/AddressBook`.

This element has two children:
* `<ManagedGroupRequest>`: If this is a managed group request, set to `true`, otherwise set to `false`.
* `<TicketToken>` This element contains the XML-encoded Passport Compact token for `contacts.msn.com` (see above).
  Added since [MSNP15](../versions/msnp15.md). 

#### soap:Body
Your request element and it's children goes here.

## Server/Response
The following sub-headings are XML elements for the server's response.

### soap:Envelope
This element has three attributes:
* `xmlns:soap`: Is always set to `http://schemas.xmlsoap.org/soap/envelope/`.
* `xmlns:xsi`: Is always set to `http://www.w3.org/2001/XMLSchema-instance`.
* `xmlns:xsd`: Is always set to `http://www.w3.org/2001/XMLSchema`.

#### soap:Header
This element only serves to host the `<ServiceHeader>` element.

##### ServiceHeader
This element has only one attribute:
* `xmlns`: Is always set to `http://www.msn.com/webservices/AddressBook`.

This element has five children:
* `<Version>`: The version of this service.
* `<CacheKey>`: The current or new address book caching key.
  Usually starts with `14r2;`, then continues with base64-encoded data.
  The meaning of the appended data is yet to be known. It may be a 128-bit hash of some kind.
* `<CacheKeyChanged>`: Did the `<CacheKey>` change? If it did, set to `true`, otherwise set to `false`.
* `<PreferredHostName>`: The domain name that this service would like to receive requests to.
* `<SessionId>`: The current session GUID.

#### soap:Body
This element contains the server's response elements and their children for the action.
