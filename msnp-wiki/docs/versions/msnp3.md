# Introduction
MSNP3 is the second released version of the Mobile Status Notification Protocol.  
It was introduced officially in Client Version 2.0.0083.

# Command information
It introduces the notification service commands:
* [IMS](../commands/ims.md)

*No switchboard or dispatch commands were known to be introduced in this version.*

*No commands were known to be removed in this version.*

# Known changes
(from [MSNP2](msnp2.md)):
* [XFR](../commands/xfr.md): Added a new parameter that is always `0`. No use is known or documented.
* Added Passport Site IDs to [URL](../commands/url.md) (parameter 3).
* Content types of both e-mail notifications have changed.
	* The initial configuration content type was changed from
	  `application/x-msmsgsemailnotification` to `text/x-msmsgsinitialemailnotification`.  
	  The content remains the same.
	* The notification content type was changed from
	  `application/x-msmsgsemailnotification` to `text/x-msmsgsemailnotification`.  
	  The only difference in content is the added `id` header.
* Added Hotmail's Passport Site ID to new e-mail notifications.
* [SND](../commands/snd.md): Added a target language parameter and 
  a client library parameter, similar to the one in [CVR](../commands/cvr.md).
* Initial profile: Added Passport integration fields.
* Font information has been added to Switchboard [MSG](../commands/msg.md) commands.
* Non-protocol: Client can now use non-hotmail domains in relevant places.
* Non-protocol: WebTV 2.5+ clients (example@webtv.net) can talk to other users (example@hotmail.com)
* Clear-Text Password (`CTP`) authentication method removed. Use `MD5` instead.
  Applies to both [INF](../commands/inf.md) and [USR](../commands/usr.md).
* Official Client: Automatic login form now supports Passport authentication
  if parameter 3 is set in [URL](../commands/url.md).  
  To generate `creds`, MD5 hash the following as one concatenated string: 
	* `auth` (from Initial Profile's `MSPAuth`, also included in the form) +
	* `sl` (amount of seconds since `LoginTime`, also included in the form) +
	* `passwd` (plain-text password).
* Official Client: Legacy automatic login form parameters has changed.
  This only applies for [URL](../commands/url.md) commands without parameter 3.  
  To generate `k2`, MD5 hash the following as one concatenated string:
	* `login` (The local-part of your user handle, also included in the form) +
	* `k1` (A short 2 digit number that you generate and is also included in the form) +
	* `passwd` (plain-text password).
* Official Client: Removed [URL](../commands/url.md) service `PASSWORD`.
* Official Client: Disabled inviting people to the service (needs confirmation).

# Client-server communication example
```msnp
C: VER 1 MSNP3 MSNP2 CVR0
S: VER 1 MSNP3
C: INF 2
S: INF 2 MD5
C: USR 3 MD5 I example@hotmail.com
S: XFR 3 NS 10.0.0.5:1863 0
```
Client disconnects from server.

Client opens a connection to `10.0.0.5:1863`.
```msnp
C: VER 4 MSNP3 MSNP2 CVR0
S: VER 4 MSNP3
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
C: IMS 10 OFF
S: IMS 10 0 OFF
C: IMS 11 ON
S: IMS 11 0 ON
C: SND 12 anotheruser@hotmail.com 0x0409 MSMSGS
S: SND 12 OK
C: OUT
```
Client disconnects from server.  
Server disconnects client.
