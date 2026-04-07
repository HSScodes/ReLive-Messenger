# Introduction
MSNP6 is the fifth released version of the Mobile Status Notification Protocol.  
It was introduced officially in Client Version 3.6.0038.

# Command information
It introduces the notification service commands:
* [CHL](../commands/chl.md)
* [IPG](../commands/ipg.md)
* [QRY](../commands/qry.md)

*No switchboard or dispatch service commands were known to be introduced in this version.*

*No commands were known to be removed in this version.*

# Known changes
(from [MSNP5](msnp5.md)):
* [USR](../commands/usr.md) OK now has a verified bit (parameter 4),
  if it is `0`, the Official Client shows a warning to verify the account.  
  *NOTE: Your display name will be forced to be
  `example@hotmail.com (E-Mail Address Not Verified)`, and can not be changed.*
* Client-server challenges were introduced.  
  The format for the response ([QRY](../commands/qry.md) commands) are
  `MD5(challenge + privateKey)` as a lowercase hexadecimal string.  
  An implementation is provided as `SolveMSNP6Challenge` in [`msnp_challenges.cs`](../files/msnp_challenges.cs.md).
* An example Private Key is `Q1P7W2E4J9R8U3S5`, which is tied to the Public Key of `msmsgs@msnmsgr.com`.
* First protocol version added in a patch release (Client Versions 3.6.0025 and 3.6.0026 do not support MSNP6).
* Official Client: Added new [URL](../commands/url.md) services `PROFILE`, `N2PACCOUNT` and `N2PFUND`.
* Official Client: Error 924 dialog changed to the unverified but still can use service one. Not sure why.

# Client-server communication example
```msnp
C: VER 1 MSNP6 MSNP5 MSNP4 CVR0
S: VER 1 MSNP6
C: INF 2
S: INF 2 MD5
C: USR 3 MD5 I example@hotmail.com
S: XFR 3 NS 10.0.0.5:1863 0
```
Client disconnects from server.

Client opens a connection to `10.0.0.5:1863`.
```msnp
C: VER 4 MSNP6 MSNP5 MSNP4 CVR0
S: VER 4 MSNP6
C: INF 5
S: INF 5 MD5
C: USR 6 MD5 I example@hotmail.com
S: USR 6 MDS S prefix
C: USR 7 MD5 S $md5(prefix + password)
S: USR 7 OK example@hotmail.com example%20user 1
S: MSG Hotmail Hotmail 367
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
MSPAuth: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA$$

C: SYN 8 8
S: SYN 8 8
C: CHG 9 NLN
S: CHG 9 NLN
S: CHL 0 11111111111111111111
C: QRY 10 msmsgs@msnmsgr.com 32
3b6666b60157322b6fc6e41a115968f5
S: QRY 10
S: IPG 478
<NOTIFICATION id="0" siteid="111100400" siteurl="http://mobile.msn.com/">
	<TO name="example@hotmail.com" pid="0x00000001:0x00000002" email="example@hotmail.com">
		<VIA agent="mobile"/>
	</TO>
	<FROM pid="0x00000001:0x00000002" name="anotheruser@hotmail.com"/>
	<MSG pri="1" id="0">
		<ACTION url="2wayIM.asp"/>
		<SUBSCR url="2wayIM.asp"/>
		<CAT id="110110001"/>
		<BODY lang="1033">
			<TEXT>Hello! I am talking from a mobile device.</TEXT>
		</BODY>
	</MSG>
</NOTIFICATION>
C: OUT
```
Client disconnects from server.  
Server disconnects client.
