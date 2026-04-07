# Introduction
MSNP13 is the twelfth released version of the Mobile Status Notification Protocol.  
It was introduced officially in Client Version 8.0.0787, along with [MSNP14](msnp14.md).

# Command information

It introduces the notification service commands:
* [ADL](../commands/adl.md)
* [RML](../commands/rml.md)
* RFS
* UBN
* UUN

*No switchboard or dispatch service commands were known to be introduced in this version.*

The following commands were removed in this version:
* [ADC](../commands/adc.md) (automatic disconnection)
* [ADG](../commands/adc.md) (automatic disconnection)
* [REG](../commands/reg.md) (automatic disconnection)
* [REM](../commands/rem.md) (automatic disconnection)
* [RMG](../commands/rmg.md) (automatic disconnection)
* [GTC](../commands/gtc.md) (automatic disconnection)
* [SYN](../commands/syn.md) (automatic disconnection)
* [SBP](../commands/sbp.md) (unconfirmed, could be used for HSB and stuff, automatic disconnection)

# Known changes
(from [MSNP12](msnp12.md)):
* This is the second protocol split since [MSNP8](msnp8.md).  
  No clients supporting this protocol are expected to support [MSNP12](msnp12.md) or below.
* [XFR](../commands/xfr.md) `NS` format has been changed:  
  The unused parameter from [MSNP3](msnp3.md) and the current server parameter from [MSNP7](msnp7.md)
  have been replaced with two new parameters, one containing `U`, and one containing a `D`.  
  The use of these parameters is unknown.
* The [Passport SOAP (RST) service](../services/rst.md) authentication request
  will now include a request for few more security tokens,
  notably `contacts.msn.com` for the [Address Book Service](../services/abservice.md).
* Replaced [SYN](../commands/syn.md) with both the
  [Address Book Service](../services/abservice.md)'s
  [`ABFindAll`](../services/abservice/abfindall.md)
  and the [Contact Sharing Service](../services/sharingservice.md)'s
  [`FindMembership`](../services/sharingservice/findmembership.md) actions.
* Instead of [ADC](../commands/adc.md) adding new users to the Forward List (FL), Allow List (AL),
  Block List (BL), or the Reverse List (RL), the [Address Book Service](../services/abservice.md)'s
  [`ABContactAdd`](../services/abservice/abcontactadd.md) action is used for the Forward List (FL),
  and the [Contact Sharing Service](../services/sharingservice.md)'s
  [`AddMember`](../services/sharingservice/addmember.md) action for the other lists.
* Instead of [REM](../commands/rem.md) removing existing users from the Forward List (FL), Allow List (AL),
  Block List (BL), or the Pending List (PL), the [Address Book Service](../services/abservice.md)'s
  [`ABContactDelete`](../services/abservice/abcontactdelete.md) action is used for the Forward List (FL),
  and the [Contact Sharing Service](../services/sharingservice.md)'s
  [`DeleteMember`](../services/sharingservice/deletemember.md) action for the other lists.
* Instead of [GTC](../commands/gtc.md), use the [Address Book Service](../services/abservice.md)'s
  [`ABContactUpdate`](../services/abservice/abcontactdelete.md) action on your own user to set the
  `MSN.IM.GTC` annotation's value to 0 or 1:
	* `0`: Automatically add to AL  
	* `1`: Ask before adding to AL/BL
* Instead of [ADG](../commands/adg.md), use the [Address Book Service](../services/abservice.md)'s
  [`ABGroupAdd`](../services/abservice/abgroupadd.md) action.
* Instead of [RMG](../commands/adg.md), use the [Address Book Service](../services/abservice.md)'s
  [`ABGroupDelete`](../services/abservice/abgroupdelete.md) action.
* Instead of [REG](../commands/adg.md), use the [Address Book Service](../services/abservice.md)'s
  [`ABGroupUpdate`](../services/abservice/abgroupupdate.md) action.
* Instead of [SBP](../commands/sbp.md), use the [Address Book Service](../services/abservice.md)'s
  [`ABContactUpdate`](../services/abservice/abcontactupdate.md) action.
* [NOT](../commands/not.md): `<NotificationData>` notifications are used for updates to your contact list
  as well as [ADL](../commands/adl.md).
* [GCF](../commands/gcf.md): All policies are now always sent after your first [USR](../commands/usr.md) command,
  including the contents of `Shields.xml` in the policy with the type of `SHIELDS`.  
  All policies now have an capitalized MD5 checksum of their respective contents.
* [UUX](../commands/uux.md), [UBX](../commands/ubx.md): Added `<MachineGuid>` element to `<Data>`.
* The contact management commands ([ADL](../commands/adl.md) and [RML](../commands/rml.md))
  now only manage the state of the Forward List (FL), Allow List (AL) and Block List (BL) for the current session.  
  For managing contacts persistently, you have to use both the [Address Book Service](../services/abservice.md)
  and the [Contact Sharing Services](../services/sharingservice.md) SOAP services.
* [RNG](../commands/rng.md) and [XFR](../commands/xfr.md) SB commands now have two extra parameters.  
  The use of these parameters is currently unknown.
* Offline instant messages can now be sent via the Offline Instant Messaging SOAP service.

# Client-server communication example
*NOTE: This has been line-broken.
Lines beginning with `..` followed by a space are continuations of the previous line.*
```msnp
C: VER 1 MSNP13 CVR0
S: VER 1 MSNP13
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
C: VER 4 MSNP13 CVR0
S: VER 4 MSNP13
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
S: MSG Hotmail Hotmail 481
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
BetaInvites: 10

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
