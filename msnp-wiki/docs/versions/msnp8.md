# Introduction
MSNP8 is the seventh released version of the Mobile Status Notification Protocol.  
It was introduced officially in Client Version 5.0.0537.

# Command information
*No commands for any service were known to be introduced in this version.*

The following commands were removed in this version:
* [INF](../commands/inf.md) (automatic disconnection)
* [FND](../commands/fnd.md) (`502` by July 2003, see Known changes for client details.)

# Known changes
(from [MSNP7](msnp7.md)):
* [CVQ](../commands/cvq.md): Client codebase identification parameter is no longer empty.
* Being the first protocol split,
  all released clients that support MSNP8 do not support any previous versions.
* Login process is now [VER](../commands/ver.md)-[CVR](../commands/cvr.md)-[USR](../commands/usr.md)
  instead of [VER](../commands/ver.md)-[INF](../commands/inf.md)-[USR](../commands/usr.md).
* [USR](../commands/usr.md) `OK` has a new parameter, Account restriction status, if set to `1`,
  the Official Client **will** forcefully log out and **demand** that you log in using MSN Explorer instead.  
  Unrestricted accounts (those that do **not** need to log in using MSN Explorer) will have the value set to `0` instead.
* Introduced the [TWN](../authschemes/twn.md)` authentication scheme, which uses Passport over HTTPS.
* Reworked [SYN](../commands/syn.md) and related response commands (notably [LSG](../commands/lsg.md) and [LST](../commands/lst.md)) drastically:
	* Iterators are gone, now total size of both groups and total contacts included in SYN response.
	* All transaction IDs and list versions have been removed from response commands (now treated as asynchronous commands).
	* Unset properties ([PRP](../commands/prp.md) commands) are now omitted. Hurray.
* [CVR](../commands/cvr.md) request now has a new 8th parameter, which is the current user.
  This also applies to [CVQ](../commands/cvq.md) in [CVR0](cvr0.md).
* New initial profile fields: `ClientIP` and `ClientPort`.  
  `ClientPort` needs to be endian swapped for it's correct value.
  Formula: `y = (((x & 0xff) << 8) | ((x & 0xff00) >> 8))`.
* NOTE: [FND](../commands/fnd.md) might still exist in client, but there's no known way of triggering it.  
  Practically removed.  
  All previous protocol versions also received the 502 error code.
* [BPR](../commands/bpr.md) removes related user, for some reason, default fields share same optimization as [PRP](../commands/prp.md) does.
* [LST](../commands/lst.md) (for [SYN](../commands/syn.md)): Lists are now all combined into a single number, where:  
  `1` denotes the Forward List (FL), `2` denotes the Allow List (AL), `4` denotes the Block List (BL), `8` denotes the Reverse List (RL).  
  For example, a contact on the Forward List (FL), Allow List (AL) and Reverse List (RL)
  would have their combined list number be `11` (`1` + `2` + `8`).
* [CHG](../commands/chg.md), [ILN](../commands/iln.md), [NLN](../commands/nln.md):
  [Client Capabilities](../files/client_capabilities.md) are introduced.
  You can now tell other clients what features you support.
* Official Client: `Connectivity` field added to application invitations
  to notify the other user about what the network conditions are.
* Official Client: Introduced support for the [Address Book Service](../services/abservice.md).
  The URL is gathered from `svcs.microsoft.com`.
  `abch_config.asp` provides an XML document with a `<abchconfig>` element.  
  It has a `<url>` element containing the service URL, a `<refresh>` element,
  and finally a `<percent>` element. Example values are
  `http://contacts.msn.com/abservice/abservice.asmx`, `0` and `0.0` respectively.
* Official Client: Added new [URL](../commands/url.md) services `ADDRBOOK`, `ADVSEARCH` and `INTSEARCH`.

# Client-server communication example
*NOTE: This has been line-broken.
Lines beginning with `..` followed by a space are continuations of the previous line.*
```msnp
C: VER 1 MSNP8 CVR0
S: VER 1 MSNP8
C: CVR 2 0x0409 win 4.10 i386 MSNMSGR 5.0.0537 MSMSGS example@hotmail.com
S: CVR 2 5.0.0537 5.0.0537 1.0.0863
.. http://download.microsoft.com/download/msnmessenger/install/5.0/w98nt42kmexp/en-us/setupdl.exe
.. http://messenger.microsoft.com
C: USR 3 TWN I example@hotmail.com
S: XFR 3 NS 10.0.0.5:1863 0 10.0.0.1:1863
```
Client disconnects from server.

Client opens a connection to `10.0.0.5:1863`.
```msnp
C: VER 4 MSNP8 CVR0
S: VER 4 MSNP8
C: CVR 5 0x0409 win 4.10 i386 MSNMSGR 5.0.0537 MSMSGS example@hotmail.com
S: CVR 5 5.0.0537 5.0.0537 1.0.0863
.. http://download.microsoft.com/download/msnmessenger/install/5.0/w98nt42kmexp/en-us/setupdl.exe
.. http://messenger.microsoft.com
C: USR 6 TWN I example@hotmail.com
S: USR 6 TWN S passport=parameters,neat=huh,lc=1033,id=507
```
*The HTTPS interlude is described in the [Passport SSI 1.4](../services/passport14.md) article.*
```msnp
C: USR 7 TWN S $(pp14response.headers.authenticationInfo["from-PP"])
S: USR 7 OK example@hotmail.com example%20user 1 0
S: MSG Hotmail Hotmail 448
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

C: SYN 8 14
S: SYN 8 15 1 1
S: GTC A
S: BLP AL
S: PRP PHH 123%20(4567)
S: LSG 0 Other%20Contacts 0
S: LST anotheruser@hotmail.com another%20user 11 0
S: BPR PHH 1%20(222)%20333%204444
C: CHG 9 NLN 0
S: CHG 9 NLN 0
S: ILN 9 NLN anotheruser@hotmail.com another%20user 28
S: NLN NLN anotheruser@hotmail.com another%20user 2
S: NLN NLN anotheruser@hotmail.com another%20user 28
C: OUT
```
Client disconnects from server.  
Server disconnects client.
