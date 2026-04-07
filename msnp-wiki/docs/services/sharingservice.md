# Introduction
The Contact Sharing Service (SharingService) is a SOAP (XML) Web Service.
It was introduced with [MSNP13](../versions/msnp13.md).

It manages the Messenger Service's Allow List (AL), Block List (BL), Reverse List (RL), and Pending List (PL) members.

It's default HTTP URL is `http://byrdr.omega.contacts.msn.com/abservice/SharingService.asmx`.
It's default HTTPS URL is `https://byrdr.omega.contacts.msn.com/abservice/SharingService.asmx`.

Related: [Address Book Service](abservice.md) (for Forward List (FL) members).

# Authentication
This service requires Passport Authentication, either using [Passport SSI 1.4](passport14.md) or [Passport SOAP (RST)](rst.md).

There are two ways to authenticate.

## Using Cookies
The easiest way to authenticate is by setting the `MSPAuth` cookie to the MSPAuth value from your Passport Compact Token (everything after `t=` and before `&p=`)

This can be done using a token for either `contacts.msn.com` or `messenger.msn.com`.

## Using SOAP
Clients from MSNP15 and up use SOAP to authenticate with the service. See the [ABAuthHeader](abservice.md#abauthheader) section for more info.

This method of authentication only works with a token for `contacts.msn.com`.

# Actions
*All actions listed have the prefix of
`http://www.msn.com/webservices/AddressBook/`.*

* [FindMembership](sharingservice/findmembership.md) (internal name: `Sharing.Pull.Membership`)
* [AddMember](sharingservice/addmember.md) (internal name: `Sharing.Push.Member.Add`)
* [DeleteMember](sharingservice/deletemember.md) (internal name: `Sharing.Push.Member.Delete`)

## Actions that we don't know much about
* UpdateMember (internal name: `Sharing.Push.Member.Edit`)
* AddService (internal name: `Sharing.Push.Service.Add`)
* UpdateService (internal name: `Sharing.Push.Service.Edit`)
* FindInverseService (internal name: `Sharing.Pull.InverseServices`)
* DeleteInverseService (internal name: `Sharing.Push.Document.Delete`)
* AcceptInvitation (internal name: `Sharing.Push.Invitation.Accept`)
* DeclineInvitation (internal name: `Sharing.Push.Invitation.Decline`)
* AddNamespace (internal name: `Sharing.Push.Namespace.Add`)
* DeleteNamespace (internal name: `Sharing.Push.Namespace.Delete`)

# Shared Templates
Being based on the [Address Book Service](abservice.md),
both the request (client) and response (server) use the exact same boilerplate.
