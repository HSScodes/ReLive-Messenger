# Introduction
MSNPx is the nth released version of the Mobile Status Notification Protocol.  
It was introduced officially in Client Version y.y.yyyy.

# Command information
*No commands for any service were known to be introduced in this version.*

*No commands were known to be removed in this version.*

# Known changes
(from [MSNPx-1](msnpx-1.md)):
* a
* b
* c

# Client-server communication example
```msnp
C: VER 1 MSNPx MSNPx-1? CVR0
S: VER 1 MSNPx
C: CVR 2 0x0409 winnt 5.1 i386 MSNMSGR 6.0.0602 MSMSGS example@hotmail.com
S: CVR 2 6.0.0602 6.0.0602 6.0.0268 http://download.microsoft.com/download/8/a/4/8a42bcae-f533-4468-b871-d2bc8dd32e9e/SetupDl.exe http://messenger.msn.com
C: USR 3 TWN I example@hotmail.com
S: XFR 3 NS 10.0.0.5:1863 0 10.0.0.1:1863
```
Client disconnects from server.

Client opens a connection to `10.0.0.5:1863`
```msnp
C: VER 4 MSNPx MSNPx-1 CVR0
S: VER 4 MSNPx
C: CVR 5 0x0409 winnt 5.1 i386 MSNMSGR y.y.yyyy MSMSGS example@hotmail.com
S: CVR 5 z.z.zzzz z.z.zzzz z.z.zzzz http://example.com/download.exe http://messenger.msn.com
C: USR 6 TWN I example@hotmail.com
S: USR 6 TWN S passport=parameters,neat=huh,lc=1033,id=507
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

C: SYN 8 15
if syn is different, write new syn response
S: SYN 8 15
C: CHG 9 NLN
S: CHG 9 NLN
write some new commands or example of changes here
C: OUT
```
Client disconnects from server.  
Server disconnects client.
