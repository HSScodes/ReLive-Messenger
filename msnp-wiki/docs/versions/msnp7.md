# Introduction
MSNP7 is the sixth released version of the Mobile Status Notification Protocol.  
It was introduced officially in Client Version 4.5.0121.

# Command information
It introduces the notification service commands:
* [ADG](../commands/adg.md)
* [REG](../commands/reg.md)
* [RMG](../commands/rmg.md)
* [LSG](../commands/lsg.md)

*No switchboard or dispatch service commands were known to be introduced in this version.*

*No commands were known to be removed in this version.*

# Known changes
(from [MSNP6](msnp6.md)):
* Added contact groups. All Forward List (FL) contacts now have an extra numerical array for what groups they are in.  
  The "Other Contacts" group can NOT be removed.
* [ADD](../commands/add.md) and [REM](../commands/rem.md) now have group parameters if the list is set to the Forward List (FL).
* [REM](../commands/rem.md) commands with the list set to the Forward List (FL) with a group ID only removes that user from the respective group,
  not the Forward List (FL) itself.
* [ADD](../commands/add.md) commands with the list set to the Forward List (FL) with a group ID only adds that user from the respective group,
  and the Forward List (FL) if the user is not already in the Forward List (FL).
* [SYN](../commands/syn.md) now includes LSG entries for groups.
* [LST](../commands/lst.md) (either from itself or a SYN response) now includes contact group numbers for the Forward List (FL).
* [XFR](../commands/xfr.md) `NS`'s now include the server it was sent from.
* Official website's `whatsnew.asp` page has been updated.
* Official Client: New service URLs for some features.
* Official Client: Added new [URL](../commands/url.md) service `CHAT`.
* Official Client: Removed [URL](../commands/url.md) services `N2PACCOUNT` and `N2PFUND`.

# Client-server communication example
```msnp
C: VER 1 MSNP7 MSNP6 MSNP5 MSNP4 CVR0
S: VER 1 MSNP7
C: INF 2
S: INF 2 MD5
C: USR 3 MD5 I example@hotmail.com
S: XFR 3 NS 10.0.0.5:1863 0 10.0.0.1:1863
```
Client disconnects from server.

Client opens a connection to `10.0.0.5:1863`.
```msnp
C: VER 4 MSNP7 MSNP6 MSNP5 MSNP4 CVR0
S: VER 4 MSNP7
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
S: SYN 8 9
S: SYN 8 9
S: GTC 8 9 A
S: BLP 8 9 AL
S: PRP 8 9 PHH 123%20(4567)
S: PRP 8 9 PHW
S: PRP 8 9 PHM
S: PRP 8 9 MOB N
S: PRP 8 9 MBE N
S: LSG 8 9 1 2 0 Other%20Contacts 0
S: LSG 8 9 2 2 1 Friends 0
S: LST 8 FL 9 1 1 anotheruser@hotmail.com another%20user 0
S: BPR 9 anotheruser@hotmail.com PHH 1%20(222)%20333%204444
S: BPR 9 anotheruser@hotmail.com PHW
S: BPR 9 anotheruser@hotmail.com PHM
S: BPR 9 anotheruser@hotmail.com MOB N
S: LST 8 AL 9 1 1 anotheruser@hotmail.com another%20user
S: LST 8 BL 9 0 0
S: LST 8 RL 9 1 1 anotheruser@hotmail.com another%20user
C: CHG 9 NLN
S: CHG 9 NLN
C: ADG 10 New%20Group%201 0
S: ADG 10 10 New%20Group%201 2 0
C: REG 11 2 Cool%20People 0
S: REG 11 11 Cool%20People 0
C: ADD 12 FL anotheruser@hotmail.com another%20user 2
S: ADD 12 FL 12 anotheruser@hotmail.com another%20user 2
C: REM 13 FL anotheruser@hotmail.com 2
S: REM 13 FL 13 anotheruser@hotmail.com 2
C: RMG 14 2
S: RMG 14 14 2
C: OUT
```
Client disconnects from server.  
Server disconnects client.
