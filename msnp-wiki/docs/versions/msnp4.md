# Introduction
MSNP4 is the third released version of the Mobile Status Notification Protocol.  
It was introduced officially in Client Version 2.1.1047.

# Command information
*No commands for any service were known to be introduced in this version.*

*No commands were known to be removed in this version.*

# Known changes
(from [MSNP3](msnp3.md)):
* [CVR](../commands/cvr.md), [SND](../commands/snd.md): Added a client codebase identification parameter.
* [CVQ](../commands/cvq.md) has an empty parameter, meant to be the client codebase
  identification parameter, like [CVR](../commands/cvr.md) has, but is always empty.
* Official Client: Client Version 2.2.1053 re-enables the ability to invite people again,
  and implements the MSNP error code `923`,
  which when sent as a [USR](../commands/usr.md) response, shows the
  "Sorry, this Kids Passport account does not have permission to access this service" dialog.

# Client-server communication example
```msnp
C: VER 1 MSNP4 MSNP3 CVR0
S: VER 1 MSNP4
C: INF 2
S: INF 2 MD5
C: USR 3 MD5 I example@hotmail.com
S: XFR 3 NS 10.0.0.5:1863 0
```
Client disconnects from server.

Client opens a connection to `10.0.0.5:1863`.
```msnp
C: VER 4 MSNP4 MSNP3 CVR0
S: VER 4 MSNP4
C: INF 5
S: INF 5 MD5
C: USR 6 MD5 I example@hotmail.com
S: USR 6 MDS S prefix
C: USR 7 MD5 S $md5(prefix + password)
S: USR 7 OK example@hotmail.com example%20user
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

C: SYN 8 5
S: SYN 8 5
C: CHG 9 NLN
S: CHG 9 NLN
C: SND 10 anotheruser@hotmail.com 0x0409 MSMSGS MSMSGS
S: SND 10 OK
C: OUT
```
Client disconnects from server.  
Server disconnects client.
