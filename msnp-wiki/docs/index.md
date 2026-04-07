# Introduction
Welcome to yellows' MSNP wiki - "we actually have documentation"

Why not visit the [Table of Commands](table_of_commands.md)?

# License
Copyright (C)  2024-2025  yellows111.  
Permission is granted to copy, distribute and/or modify this document
under the terms of the GNU Free Documentation License, Version 1.3
or any later version published by the Free Software Foundation;
with no Invariant Sections, no Front-Cover Texts, and no Back-Cover Texts.  
A copy of the license is included in the article entitled
"[GNU Free Documentation License](license.md)".

# Protocol Versions
* [CVR0](versions/cvr0.md)
* [MSNP2](versions/msnp2.md)
* [MSNP3](versions/msnp3.md)
* [MSNP4](versions/msnp4.md)
* [MSNP5](versions/msnp5.md)
* [MSNP6](versions/msnp6.md)
* [MSNP7](versions/msnp7.md)
* [MSNP8](versions/msnp8.md)
* [MSNP9](versions/msnp9.md)
* [MSNP10](versions/msnp10.md)
* [MSNP11](versions/msnp11.md)
* [MSNP12](versions/msnp12.md)
* [MSNP13](versions/msnp13.md)
* [MSNP14](versions/msnp14.md)

More is to come soon! Hopefully!

# Authentication Schemes

* [CTP](authschemes/ctp.md) (Cleartext Password), used in MSNP2 (only in Messenger clients from version 1.0.0452 to 1.0.0893)
* [MD5](authschemes/md5.md) (MD5 Password Authentication), used from MSNP2 to MSNP7
* [TWN](authschemes/twn.md) (Tweener/Passport Authentication), used from MSNP8 to MSNP14
* [SSO](authschemes/sso.md) (Single Sign On), used from MSNP15 onward

# Web Services
* [Address Book Service](services/abservice.md)
* [Contact Sharing Service](services/sharingservice.md)
* [Messenger Config Service](services/msgrconfig.md)
* [Passport SSI 1.4](services/passport14.md)
* [Passport SOAP (RST)](services/rst.md)

More is to come soon! Hopefully!

# Other documents and files
* [Constants used on the wiki](reference_constants.md)
* [List of Error Codes and HRESULTs](errors_and_hresults.md)
* [Table of Commands](table_of_commands.md)
* [Shields Configuration Data](files/shields.md)
* [`<NOTIFICATION>` documents](files/notification.md)
* [Challenge key pairs](files/challenge_keypairs.md)
* [All Client Capabilities](files/client_capabilities.md)
* [MSNP Challenge implementation (C#)](files/msnp_challenges.cs.md)

# Wanted Information
* [MSNP8](versions/msnp8.md): Did [FND](commands/fnd.md) exist? Rumours said it did shortly before it got killed in all protocols.
* [MSNP8](versions/msnp8.md): Did [LSG](commands/lsg.md) and [LST](commands/lst.md) change outside of [SYN](commands/syn.md) in this version?
* [MSNP10](versions/msnp10.md): Asynchronous `BPR MFN`s from the server. Does it really?
* [MSNP10](versions/msnp10.md): Did [LSG](commands/lsg.md) and [LST](commands/lst.md) change outside of [SYN](commands/syn.md) in this version?
* [MSNP11](versions/msnp11.md): Anything about the `GSB` command, and is it related to `SBS`?
* [MSNP11](versions/msnp11.md): How does `ABCHMigrated: 0` really work now? `OUT MIG` still exists.
* [MSNP12](versions/msnp12.md): Did [LST](commands/lst.md) change outside of [SYN](commands/syn.md) in this version?
* [MSNP13](versions/msnp13.md): All of the new Client Capabilities used in `UUN`.
* [MSNP13](versions/msnp13.md)+: All uses of the `UUN`/`UBN` command.
* [MSNP18](versions/msnp18.md): Did `<NotificationData>`-based circle updates get added in [MSNP17](versions/msnp17.md) instead of [MSNP18](versions/msnp18.md)?
* [MSNP2](versions/msnp2.md) to [MSNP7](versions/msnp7.md): TODO: Add CVR requests as command 10.
* All Protocols: Any error code known to exist but is missing from the pages.
* All Protocols: Good [CVR](commands/cvr.md) responses, all of them are their release versions, when they could be latest.
* All Protocols since [MSNP10](versions/msnp10.md): Use legitimate [CVR](commands/cvr.md) responses from the time if possible, not ones for Client Version 6.1.
* [IMS command](commands/ims.md): What is the unknown number (that is usually `0`) in the response?
* [NAK command](commands/nak.md): This isn't used ever as a response for [MSG](commands/msg.md) D right?
* [MSG command](commands/msg.md): What can return from [MSG](commands/msg.md) D?
* [LST command](commands/lst.md): Any updates to this command outside of [SYN](commands/syn.md).
* [PRP command](commands/prp.md): Any information on the following properties (if they are properties?):
	* `UTL`
	* `WPL`
	* `CID`: Is this related to spaces?
	* `RES`
	* `NSD`
	* `UAC`
	* `MNI`
* [UUX command](commands/uux.md): Any information on the following optional elements:
	* `PHMEnabled`
	* `MNIEnabled`
	* `LastSpaceUpdate`
	* `LastStorageError`
	* `FIR`
* Meta: A good way to handle removed-mid-protocol commands like [FND](commands/fnd.md), [LSG](commands/lsg.md) and [LST](commands/lst.md)...

## We know, but isn't written
* [Messenger Config service](services/msgrconfig.md): maybe provide examples?
* MSNC1: the client-to-client subprotocol introduced with [MSNP9](versions/msnp9.md), unsure where to put this one...
* MSNP2P: the sub-protocol used with MSNC for file transfers, custom emoticons, display pictures, and more, maybe put with MSNC articles?
* MSNFTP: the sub-protocol used for file transfers in [MSNP5](versions/msnp5.md), also unsure where to put this one...

### We know SOME Information
* Offline IMs (OIM) SOAP service: Absolutely needs a service page, since it's been in since [MSNP11](versions/msnp11.md).

## Unsolved Mysteries
* [INF command](commands/inf.md): ***Why*** does the [MSNP2](versions/msnp2.md) [draft](https://datatracker.ietf.org/doc/html/draft-movva-msn-messenger-protocol-00#section-7.2) have this in Switchboard? It's not used by any client as far as I'm aware.
* [FND command](commands/fnd.md): Why does this have an iterator if you can't send it over multiple packets?
* [USR command](commands/usr.md): Speaking of CKI, Why is it not specified when authenticating to Switchboard?
* [XFR command](commands/xfr.md): That one single digit parameter ([MSNP3](versions/msnp3.md)-[MSNP12](versions/msnp12.md)) and what it has to do with `application/x-msmsgsspmessage`.
* The Draft: Why did the draft go vague on the errors? The list [was there](https://datatracker.ietf.org/doc/html/draft-movva-msn-messenger-protocol-00#section-7.11), but no explanations on what can cause them... Odd.

# Common (or not) Terms
* Official Client: MSN Messenger (Service) or Windows Live Messenger.
* Client Version: relevant Official Client version.
* MSNP: Mobile Status Notification Protocol, or whatever acronym you like. Runs over TCP via port 1863.  
  Offically called the Microsoft Notification Protocol.
* ABCH: Address Book Clearing House. Usually refers to the [Address Book Service](services/abservice.md) and the [Contact Sharing Service](services/sharingservice.md).
* Messenger Config: A file used by Client Version 6.0 and higher that specifies some data for the Official Client.
* `svcs.microsoft.com`: Usually a grab-bag of random XML files or services used for clients older than Client Version 6.0.
* Protocol Split: A MSNP version that usually defines a point of no return.
* PP14, Passport 1.4, TWN, Tweener: [Passport SSI Version 1.4](services/passport14.md).
* Passport SOAP, RST, Passport 3.0, SOAP authentication: The [Passport SOAP (RST) service](services/rst.md) that was implemented in Client Version 7.5+ ([MSNP12](versions/msnp12.md)).
* RST2: The second version of the Passport SOAP (RST) service that was implemented in Client Version 14.0+ ([MSNP18](versions/msnp18.md)) (TODO: Am I right about this?).
* SOAP: Simple Object Access Protocol, A message schema based on XML. That's the kindest thing I can write about it.
* Passport: The authentication server and/or protocol.
* Passport Compact Token: A domain-scoped token containing an authentication token and profile data, 
  in the format of `t={auth}&p={profile}`. Sometimes URL encoded, sometimes XML encoded.
* Undefined Behaviour: An intentional blank left in the documentation, basically as a "I am not responsible for what this does to your client or server" warning.
* Dispatch Server: A type of MSNP server that handles moving users to Notification Servers,
  usually being the first server in the login chain.
* Notification Server/NS: The real "meat" of MSNP, handles authentication, user presence, notifications,
  creates and defers to Switchboard Server sessions and boasts the most commands.  
  Officially called the Connection Server (CS) for the front-end, and the Presence Server (PS) for the back-end.
* Switchboard Server/SB: The messaging part of the protocol. Changed only twice until it was deprecated in [MSNP21](versions/msnp21.md).  
  Officially called the Mixer.
* Command: A 3-letter case-sensitive command type, followed optionally by a transaction ID and the rest of the Command parameters, ending with a new-line.
* Payload Command: A special type of Command that has a integer length parameter as the final parameter before the delimiting new-line.
* New-line/Newline: A Carriage Return character followed by a Line Feed character. Separates commands in the protocol.
* Error Code: A 3-digit Command that denotes that there was a problem with the last command sent.
* Carriage Return: To return the page-writing apparatus to the left of the page.
* Line Feed: To move the page-writing apparatus down a "line".
* TrID: Transaction ID. Links the server's response to the client's request.
* User handle: An address which supports up to 129 characters that is used across the protocol.
  May be called "principals" (term from [RFC2778](https://datatracker.ietf.org/doc/html/rfc2778#page-13))
  or incorrectly "principles" outside of this documentation.
* Public Key, Private Key: The parameters used in [QRY](commands/qry.md).
	* The one you send with it in plain is the Public Key.  
	  An example of the Public Key is `msmsgs@msnmsgr.com` or `PROD0090YUAUV{2B`.
	* The one you use for the main challenge response hash is the Private Key.  
	  An example of the Private Key is `Q1P7W2E4J9R8U3S5` or `YMM8C_H7KCQ2S_KL`.
* Buddy: A contact on the Forward List (FL) of the current user.

# Where can I find or edit the source of the articles provided?
The git repository for the project is available at <https://git.computernewb.com/yellows111/msnp-wiki>.

You can submit changes to me via any available contact method as a e-mail merge request,
like those made with [`git format-patch`](https://git-scm.com/docs/git-format-patch).  
If such a method is undesired or you do not want to format such a message,
that is fine too, as long as you give a pointer to where you would like the information to go.
