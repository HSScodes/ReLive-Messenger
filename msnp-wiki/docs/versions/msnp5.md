# Introduction
MSNP5 is the fourth released version of the Mobile Status Notification Protocol.  
It was introduced officially in Client Version 3.0.0283.

# Command information
It introduces the notification service commands:
* [BPR](../commands/bpr.md)
* [NOT](../commands/not.md)
* [PAG](../commands/pag.md)
* [PRP](../commands/prp.md)
* [SDC](../commands/sdc.md)

*No switchboard or dispatch service commands were known to be introduced in this version.*

*No commands were known to be removed in this version.*

# Known changes
(from [MSNP4](msnp4.md)):
* [BPR](../commands/bpr.md) and [PRP](../commands/prp.md) have been added to [SYN](../commands/syn.md).
* [`<NOTIFICATION>`](../files/notification.md) documents are handled by the client with the new [NOT](../commands/not.md) payload command.
* Non-protocol: Official website stopped updating the whatsnew.asp page between this (MSNP5) and [MSNP7](msnp7.md).
* Official Client: Introduced the toast notification system. Notifications can now stack vertically.
* Official Client: Log in notifications are now handled by the newly introduced toast system.
* Official Client: Introduced emoticons.
* Official Client: Introduced File Transfer and Messenger-to-Messenger calling via invitations.
* Introduced first payload commands ([SDC](../commands/sdc.md), [PAG](../commands/pag.md)) to be sent to the Notification Server from the client.
* Official Client: [FND](../commands/fnd.md) functionality changed slightly(?) to say that the Passport privacy policy
  doesn't allow users to retrieve the e-mails associated with the user's account,
  sending the user to a invitation screen with, with it ending in sending an [SDC](../commands/sdc.md) in the format of
  `SDC TrID {FND index} 0x0409 MSMSGS MSMSGS X X example%20user {length}`.  
  The `0x0409` can be changed to any language code, with the `length` denoting the payload if specified.
* Official Client: [URL](../commands/url.md) without the Passport Site ID (parameter 3) support has been removed.
* Official Client: Added new [URL](../commands/url.md) services `MOBILE` and `CHGMOB` .
* Official Client: MSNP error code 924 has been implemented,
  which when sent as a response to [USR](../commands/usr.md), shows the
  "Sorry, you can not sign in until your verify that (user handle) really belongs to you" dialog.

# Client-server communication example
```msnp
C: VER 1 MSNP5 MSNP4 CVR0
S: VER 1 MSNP5
C: INF 2
S: INF 2 MD5
C: USR 3 MD5 I example@hotmail.com
S: XFR 3 NS 10.0.0.5:1863 0
```
Client disconnects from server.

Client opens a connection to `10.0.0.5:1863`.
```msnp
C: VER 4 MSNP5 MSNP4 CVR0
S: VER 4 MSNP5
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
S: SYN 8 6
S: SYN 8 6
S: GTC 8 6 A
S: BLP 8 6 AL
S: LST 8 FL 6 1 1 anotheruser@hotmail.com another%20user
S: BPR 6 anotheruser@hotmail.com PHH 1%20(222)%203333
S: BPR 6 anotheruser@hotmail.com PHW
S: BPR 6 anotheruser@hotmail.com PHM
S: BPR 6 anotheruser@hotmail.com MOB N
S: LST 8 AL 6 1 1 anotheruser@hotmail.com another%20user
S: LST 8 BL 6 0 0
S: LST 8 RL 6 1 1 anotheruser@hotmail.com another%20user
C: CHG 9 NLN
S: CHG 9 NLN
S: NOT 367
<NOTIFICATION ver="1" id="2" siteid="0" siteurl="http://example.com/">
	<TO pid="0x00000001:0x00000002" name="example@hotmail.com" />
	<MSG id="0">
		<ACTION url="alert?command=action" />
		<SUBSCR url="alert?command=change" />
		<BODY lang="1033" icon="alerticon_32x32.png">
			<TEXT>This is an example notification.</TEXT>
		</BODY>
	</MSG>
</NOTIFICATION>
C: PRP 10 PHH 123%20(4567)
S: PRP 10 7 PHH 123%20(4567)
S: BPR 8 anotheruser@hotmail.com PHH 1%20(222)%20333%204444
C: OUT
```
Client disconnects from server.  
Server disconnects client.
