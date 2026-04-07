# Introduction
MSNP10 is the ninth released version of the Mobile Status Notification Protocol.  
It was introduced officially in Client Version 6.1.0155.

# Command information
It introduces the notification service commands:
* [ADC](../commands/adc.md)
* [SBP](../commands/sbp.md)

*No switchboard or dispatch service commands were known to be introduced in this version.*

The following commands were removed in this version:
* [ADD](../commands/add.md) (automatic disconnection)
* [REA](../commands/rea.md) (automatic disconnection?)

# Known changes
(from [MSNP9](msnp9.md)):
* Added new initial profile variable `TOUNeeded`. If the value exists and it is set to `1`,
  a dialog box to review the Messenger Service Terms of Use is shown to the user.
* Changed [SYN](../commands/syn.md) request and response.  
  Client: `SYN transactionID listVersion settingsVersion`  
  Server: `SYN transactionID listVersion settingsVersion numberOfContacts numberOfGroups`  
  The `settingsVersion` parameter is by default, always `0`.
* Removed unused parameter from [LSG](../commands/lsg.md).
* Current display name is removed from USR, now is returned with other user properties ([PRP](../commands/prp.md) commands) in [SYN](../commands/syn.md).
* [PRP](../commands/prp.md) MFN replaces [REA](../commands/rea.md) (current user handle). [SBP](../commands/sbp.md) (contact ID) MFN replaces other uses of [REA](../commands/rea.md).
* [LST](../commands/lst.md): Added prefixes to the user handle (`N=`) and friendly name (`F=`) parameters.
* Added new initial profile variable `ABCHMigrated`. If set to 1, some commands are altered, such as:
	* [SYN](../commands/syn.md): The request and response's list versions are now ISO 8601 with 7 sub-second digits,
		   usually with a -07:00 time zone offset.  
		   The previously unused second parameter (both request and response) is used as the Last Settings Version,
		   and follows the same time format as List Versions now do.
	* [LST](../commands/lst.md): GUID specified as `C=` parameter, group IDs are now GUIDs.
	* [ADC](../commands/adc.md), [REM](../commands/rem.md): uses GUIDs instead of contact user handles if the list is the Forward List (FL), and same applies also for groups.
	* [LSG](../commands/lsg.md), [ADG](../commands/adg.md): Uses GUIDs instead of IDs.
	* [SBP](../commands/sbp.md): Uses the contact's GUID instead of the Contact Address.
* All list version updating commands no longer return the current list version when used.  
  The following commands are affected:
	* [GTC](../commands/gtc.md)
	* [BLP](../commands/blp.md)
	* [ADG](../commands/adg.md)
	* [BPR](../commands/bpr.md)
	* [REG](../commands/reg.md)
	* [RMG](../commands/rmg.md)
	* [REM](../commands/rem.md)
	* [PRP](../commands/prp.md)
* Added a new list: Pending List (PL), which is denoted by the decimal number 16.  
  This list contains users that have unhandled "user added you, do you want to add or block them?" notifications.  
  This list can only be modified with [REM](../commands/rem.md) commands, but not with [ADC](../commands/adc.md) commands.
* The Reverse List (RL) can now be modified with [ADC](../commands/adc.md) commands.
  Attempting to use [REM](../commands/rem.md) commands will still cause an automatic disconnection.  
  This change was implemented so you can move users from the
  Pending List (PL) to the Reverse List (RL), once you have cleared their request notification.
* Added new server-side [OUT](../commands/out.md) reasons: `MIG`, if the server has migrated you to ABCH,
  and `TOU`, for not accepting the Service Terms of Use.
* First protocol version to remove a core command implemented since [MSNP2](msnp2.md) draft ([ADD](../commands/add.md)).

# Client-server communication example
*NOTE: This has been line-broken.
Lines beginning with `..` followed by a space are continuations of the previous line.*
```msnp
C: VER 1 MSNP10 MSNP9 CVR0
S: VER 1 MSNP10
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
C: VER 4 MSNP10 MSNP9 CVR0
S: VER 4 MSNP10
C: CVR 5 0x0409 winnt 5.1 i386 MSNMSGR 6.0.0602 MSMSGS example@hotmail.com
S: CVR 5 6.1.0211 6.1.0211 6.1.0155
.. http://download.microsoft.com/download/8/3/C/83C4B2DB-AC1C-4B56-8144-4472C0982F21/SetupDl.exe
.. http://messenger.msn.com
C: USR 6 TWN I example@hotmail.com
S: USR 6 TWN S passport=parameters,neat=huh,lc=1033,id=507
```
*The HTTPS interlude is described in the [Passport SSI 1.4](../services/passport14.md) article.*
```msnp
C: USR 7 TWN S $(pp14response.headers.authenticationInfo["from-PP"])
S: USR 7 OK example@hotmail.com 1 0
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
ABCHMigrated: 0

C: SYN 8 15 0
S: SYN 8 16 0 1 1
S: GTC A
S: BLP AL
S: PRP MFN example%20user
S: PRP PHH 123%20(4567)
S: LSG Other%20Contacts 0
S: LST N=anotheruser@hotmail.com F=another%20user C=anotheruser@hotmail.com 11 0
S: BPR PHH 1%20(222)%20333%204444
C: CHG 9 NLN
S: CHG 9 NLN
S: OUT MIG
```
Server disconnects client.

Client opens a connection to `10.0.0.5:1863` (from stored server).
```msnp
C: VER 10 MSNP10 MSNP9 CVR0
S: VER 10 MSNP10
C: CVR 11 0x0409 winnt 5.1 i386 MSNMSGR 6.0.0602 MSMSGS example@hotmail.com
S: CVR 11 6.1.0211 6.1.0211 6.1.0155
.. http://download.microsoft.com/download/8/3/C/83C4B2DB-AC1C-4B56-8144-4472C0982F21/SetupDl.exe
.. http://messenger.msn.com
C: USR 12 TWN I example@hotmail.com
S: USR 12 TWN S passport=parameters,neat=huh,lc=1033,id=507
C: USR 13 TWN S $(pp14response.headers.authenticationInfo["from-PP"])
S: USR 13 OK example@hotmail.com 1 0
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

C: SYN 14 0 0
S: SYN 14 2024-09-28T17:18:18.6400000-07:00 2024-09-28T17:18:18.6400000-07:00 1 1
S: GTC A
S: BLP AL
S: PRP MFN example%20user
S: PRP PHH 123%20(4567)
S: LSG Other%20Contacts d6deeacd-7849-4de4-93c5-d130915d0042
S: LST N=anotheruser@hotmail.com F=another%20user C=c1f9a363-4ee9-4a33-a434-b056a4c55b98 11 d6deeacd-7849-4de4-93c5-d130915d0042
S: BPR PHH 1%20(222)%20333%204444
C: CHG 15 NLN
S: CHG 15 NLN
C: OUT
```
Client disconnects from server.  
Server disconnects client.
