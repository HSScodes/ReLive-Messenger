# Introduction
MSNP12 is the eleventh released version of the Mobile Status Notification Protocol.  
It was introduced officially in Client Version 7.5.0299.

# Command information
It introduces the notification service commands:
* LKP

*No switchboard or dispatch service commands were known to be introduced in this version.*

*No commands were known to be removed in this version.*

# Known changes
(from [MSNP11](msnp11.md)):
* Network IDs are introduced, each bit represents a contact's service, with bit 0/decimal 1 being MSNP.
* Switchboard commands [JOI](../commands/joi.md) and [IRO](../commands/iro.md) have a new parameter for the
  [Client Capabilities](../files/client_capabilities.md) of the relevant user.
* [LST](../commands/lst.md) has the Network ID after the list bits (on any list),
  but before the Group ID (if contact is on the Forward List (FL)).
* Official Client: Now uses the [Passport SOAP (RST) service](../services/rst.md),
  via the Microsoft Identity Common Runtime Library (`MSIDCRL`).
* Official Client: Dropped support for older operating systems, Now requires Windows XP or higher.
* Official Client: Now supports Voice Clips, which can be disabled in the [Messenger Config](../services/msgrconfig.md).
* Official Client: [Shield Configuration Data](../files/shields.md) can now block file hashes and
  instant message text via regular expressions.

# Client-server communication example
*NOTE: This has been line-broken.
Lines beginning with `..` followed by a space are continuations of the previous line.*
```msnp
C: VER 1 MSNP12 MSNP11 MSNP10 CVR0
S: VER 1 MSNP12
C: CVR 2 0x0409 winnt 5.1 i386 MSNMSGR 6.0.0602 MSMSGS example@hotmail.com
S: CVR 2 6.1.0211 6.1.0211 6.1.0155
.. http://download.microsoft.com/download/8/3/C/83C4B2DB-AC1C-4B56-8144-4472C0982F21/SetupDl.exe
.. http://messenger.msn.com
C: USR 3 TWN I example@hotmail.com
S: XFR 3 NS 10.0.0.5:1863 0 10.0.0.1:1863
```
Client disconnects from server.

Client opens a connection to `10.0.0.5:1863`.
```msnp
C: VER 4 MSNP12 MSNP11 MSNP10 CVR0
S: VER 4 MSNP12
C: CVR 5 0x0409 winnt 5.1 i386 MSNMSGR 6.0.0602 MSMSGS example@hotmail.com
S: CVR 5 6.1.0211 6.1.0211 6.1.0155
.. http://download.microsoft.com/download/8/3/C/83C4B2DB-AC1C-4B56-8144-4472C0982F21/SetupDl.exe
.. http://messenger.msn.com
C: USR 6 TWN I example@hotmail.com
```
*The HTTPS interlude is described in the
[Passport SOAP (RST)](../services/rst.md) article.*
```msnp
S: USR 6 TWN S passport=parameters,neat=huh,lc=1033,id=507
C: USR 7 TWN S $(xmldecode(RequestSecurityTokenResponse.BinarySecurityToken#Compact1))
S: USR 7 OK example@hotmail.com 1 0
S: SBS 0 null
S: MSG Hotmail Hotmail 465
MIME-Version: 1.0
Content-Type: text/x-msmsgsprofile; charset=UTF-8
LoginTime: 1726321960
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

C: SYN 8 2024-09-28T17:18:18.6400000-07:00 2024-09-28T17:18:18.6400000-07:00
S: SYN 8 2024-09-29T11:27:30.2300000-07:00 2024-09-28T17:18:18.6400000-07:00
S: GTC A
S: BLP AL
S: PRP MFN example%20user
S: PRP PHH 123%20(4567)
S: LSG Other%20Contacts d6deeacd-7849-4de4-93c5-d130915d0042
S: LST N=anotheruser@hotmail.com F=another%20user C=c1f9a363-4ee9-4a33-a434-b056a4c55b98 11 1 d6deeacd-7849-4de4-93c5-d130915d0042
S: BPR PHH 1%20(222)%20333%204444
C: GCF 9 Shields.xml
S: GCF 9 Shields.xml 145
<?xml version="1.0" encoding="utf-8" ?><config><shield><cli maj="7" min="0" minbld="0" maxbld="9999" deny=" " /></shield><block></block></config>
C: CHG 10 NLN
S: CHG 10 NLN
C: UUX 11 53
<Data><PSM></PSM><CurrentMedia></CurrentMedia></Data>
S: UUX 11 0
C: OUT
```
Client disconnects from server.  
Server disconnects client.
