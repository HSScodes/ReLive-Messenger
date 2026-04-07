# Introduction
MSNP14 is the thirteenth released version of the Mobile Status Notification Protocol.  
It was introduced officially in Client Version 8.0.0787, along with [MSNP13](../versions/msnp13.md).

# Command information

It introduces the notification service commands:
* [FQY](../commands/fqy.md)
* UBM
* UUM

*No switchboard or dispatch service commands were known to be introduced in this version.*

*No commands were known to be removed in this version.*

# Known changes
(from [MSNP13](../versions/msnp13.md)):
* [UBX](../commands/ubx.md) now has an extra parameter for a Network ID of the network
  that generated the new XML payload.
* [RNG](../commands/rng.md) and [XFR](../commands/xfr.md) `SB` commands now have an extra parameter
  to specify if the address should be connected to directly or only via the HTTP Gateway.
* [ILN](../commands/iln.md), [NLN](../commands/nln.md) and [FLN](../commands/fln.md)
  now have a few extra parameters:
  * One for the Network ID of the network that generated the new status.
  * One for the current Client Capabilities of the user.
  * Finally, one to specify what icon to use to denote a user from another service.
* Official Client: Yahoo! Messenger interoperability is now supported.  
  The [FQY](../commands/fqy.md) command is used to discover if a user is from the Yahoo! Messenger network.  
  This is represented in the [Address Book Service](../services/abservice.md) as a email-only contact
  with the `isMessengerEnabled` element set to `true` for the `contactEmailType` of `Messenger2`.  
  This is also represented in the [Contact Sharing Service](../services/sharingservice.md) as a e-mail membership,
  with the `MSN.IM.BuddyType` annotation set to `32:`.  
  The Network ID 32 (bit 6) is used to specify that this user is from the Yahoo! Messenger service.

# Client-server communication example
*NOTE: This has been line-broken.
Lines beginning with `..` followed by a space are continuations of the previous line.*
```msnp
C: VER 1 MSNP14 MSNP13 CVR0
S: VER 1 MSNP14
C: CVR 2 0x0409 winnt 5.1 i386 MSG80BETA 8.0.0566 msmsgs example@hotmail.com
S: CVR 2 8.0.0566 8.0.0566 8.0.0566
.. http://msgr.dlservice.microsoft.com/download/4/5/b/45beb06f-5a08-4694-abd8-d6e706b06b68/Install_Messenger_Beta.exe
.. http://ideas.live.com
C: USR 3 TWN I example@hotmail.com
S: XFR 3 NS 10.0.0.5:1863 U D
```
Client disconnects from server.

Client opens a connection to `10.0.0.5:1863`.
```msnp
C: VER 4 MSNP14 MSNP13 CVR0
S: VER 4 MSNP14
C: CVR 5 0x0409 winnt 5.1 i386 MSNMSGR 8.0.0566 MSMSGS example@hotmail.com
S: CVR 5 8.0.0566 8.0.0566 8.0.0566
.. http://msgr.dlservice.microsoft.com/download/4/5/b/45beb06f-5a08-4694-abd8-d6e706b06b68/Install_Messenger_Beta.exe
.. http://ideas.live.com
C: USR 6 TWN I example@hotmail.com
```
*The HTTPS interlude is described in the
[Passport SOAP (RST)](../services/rst.md) article.*
```msnp
S: USR 6 TWN S passport=parameters,neat=huh,lc=1033,id=507
S: GCF 0 245
<Policies>
	<Policy type="SHIELDS" checksum="83B30425941CE296DED998A20861F87B">
		<config>
			<shield>
				<cli maj="7" min="0" minbld="0" maxbld="9999" deny=" " />
			</shield>
			<block>
			</block>
		</config>
	</Policy>
</Policies>
C: USR 7 TWN S $(xmldecode(RequestSecurityTokenResponse.BinarySecurityToken#Compact1))
S: USR 7 OK example@hotmail.com 1 0
S: SBS 0 null
S: MSG Hotmail Hotmail 465
MIME-Version: 1.0
Content-Type: text/x-msmsgsprofile; charset=UTF-8
LoginTime: 1732890086
EmailEnabled: 1
MemberIdHigh: 1
MemberIdLow: 2
lang_preference: 1033
PreferredEmail: example@hotmail.com
country: US
PostalCode: 
Gender: 
Kid: 0
Age: 
BDayPre: 
Birthday: 
Wallet: 
Flags: 1027
sid: 507
kv: 11
MSPAuth: whatever+t+is+in+your+passport+login+ticket+that+you+sent+for+USR+TWN+S$
ClientIP: 192.168.1.111
ClientPort: 18183
ABCHMigrated: 1

```
*The Client now uses both the [`ABFindAll`](../services/abservice/abfindall.md)
and the [`FindMembership`](../services/sharingservice/findmembership.md) actions
to get the current state of all lists and the last stored name and privacy mode.*

*NOTE: The following [ADL](../commands/adl.md) and [UUX](../commands/uux.md) payloads
have been exploded for visibility and formatting reasons.  
No whitespace is allowed in [ADL](../commands/adl.md)'s payload and the payload size reflects this,
and is set to the correct value.*
```msnp
C: BLP 7 AL
S: BLP 7 AL
C: ADL 8 110
<ml l="1">
	<d n="hotmail.com">
		<c n="anotheruser" l="3" t="1" />
	</d>
	<t>
		<c n="tel:+15551111222" l="3" />
	</t>
</ml>
S: ADL 8 OK
C: PRP 9 MFN example%20user
S: PRP 9 MFN example%20user
C: CHG 10 NLN
S: CHG 10 NLN
C: UUX 11 118
<Data>
	<PSM></PSM>
	<CurrentMedia></CurrentMedia>
	<MachineGuid>{44BFD5A4-7450-4BDA-BA3A-C51B3031126D}</MachineGuid>
</Data>
S: UUX 11 0
C: OUT
```
Client disconnects from server.  
Server disconnects client.
