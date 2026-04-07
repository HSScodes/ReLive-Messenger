# Introduction
MSNP9 is the eighth released version of the Mobile Status Notification Protocol.  
It was introduced officially in Client Version 6.0.0602.

# Command information
It introduces the notification service commands:
* [PGD](../commands/pgd.md)

*No switchboard or dispatch service commands were known to be introduced in this version.*

The following commands were removed in this version:
* [PAG](../commands/pag.md) (returns 715)
* [LST](../commands/lst.md) (Only client-initiated, the one in [SYN](../commands/syn.md) is kept,
  removed in November, 2003 via automatic disconnect.)
* [LSG](../commands/lsg.md) (Only client-initiated, the one in [SYN](../commands/syn.md) is kept,
  removed in November, 2003 via automatic disconnect.)

# Known changes
(from [MSNP8](msnp8.md)):
* [CHG](../commands/chg.md), [ILN](../commands/iln.md), [NLN](../commands/nln.md): Added an optional MSNObject parameter.  
  Now you can tell other clients about image data associated with your account.
* [QNG](../commands/qng.md): Added a "next ping" time (in seconds) parameter.
* Switchboard [MSG](../commands/msg.md): Acknowledgement type `D` added.  
  Can respond with either [ACK](../commands/ack.md), error 282, or possibly any other error codes.
* [NOT](../commands/not.md): Extended notifications are now supported via the `<TEXTX>` element.
* Official Client: Supports the [Messenger Config](../services/msgrconfig.md) XML service, replacing `svcs.microsoft.com`.

# Client-server communication example
*NOTE: This has been line-broken.
Lines beginning with `..` followed by a space are continuations of the previous line.*
```msnp
C: VER 1 MSNP9 MSNP8 CVR0
S: VER 1 MSNP9
C: CVR 2 0x0409 winnt 5.1 i386 MSNMSGR 6.0.0602 MSMSGS example@hotmail.com
S: CVR 2 6.0.0602 6.0.0602 6.0.0268
.. http://download.microsoft.com/download/8/a/4/8a42bcae-f533-4468-b871-d2bc8dd32e9e/SetupDl.exe
.. http://messenger.msn.com
C: USR 3 TWN I example@hotmail.com
S: XFR 3 NS 10.0.0.5:1863 0 10.0.0.1:1863
```
Client disconnects from server.

Client opens a connection to `10.0.0.5:1863`.
```msnp
C: VER 4 MSNP9 MSNP8 CVR0
S: VER 4 MSNP9
C: CVR 5 0x0409 winnt 5.1 i386 MSNMSGR 6.0.0602 MSMSGS example@hotmail.com
S: CVR 5 6.0.0602 6.0.0602 6.0.0268
.. http://download.microsoft.com/download/8/a/4/8a42bcae-f533-4468-b871-d2bc8dd32e9e/SetupDl.exe
.. http://messenger.msn.com
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

C: SYN 8 15
S: SYN 8 15
C: CHG 9 NLN
S: CHG 9 NLN
S: ILN 9 NLN anotheruser@hotmail.com another%20user 268435500 %3Cmsnobj%20Creator%3D%22anotherdude%40hotmail.com%22
.. %20Size%3D%2225235%22%20Type%3D%223%22
.. %20Location%3D%22uexA4DE.dat%22%20Friendly%3D%22AAA%3D%22
.. %20SHA1D%3D%22vP1ppB+xiFQ8ceZivRe0uCaYLIU%3D%22
.. %20SHA1C%3D%22PApbbjkbDSGrt3ybGHRKNaZ8s%2Fw%3D%22%2F%3E
C: PNG
S: NLN NLN anotheruser@hotmail.com another%20user 268435500 %3Cmsnobj%20Creator%3D%22anotherdude%40hotmail.com%22
.. %20Size%3D%2225235%22%20Type%3D%223%22
.. %20Location%3D%22uexA4DE.dat%22%20Friendly%3D%22AAA%3D%22
.. %20SHA1D%3D%22vP1ppB+xiFQ8ceZivRe0uCaYLIU%3D%22
.. %20SHA1C%3D%22PApbbjkbDSGrt3ybGHRKNaZ8s%2Fw%3D%22%2F%3E
S: QNG 60
S: NOT 458
<NOTIFICATION ver="1" id="2" siteid="0" siteurl="http://example.com/">
	<TO pid="0x00000001:0x00000002" name="example@hotmail.com" />
	<MSG id="0">
		<ACTION url="alert?command=action" />
		<SUBSCR url="alert?command=change" />
		<BODY lang="1033" icon="alerticon_32x32.png">
			<TEXT>This is an example notification.</TEXT>
			<TEXTX>&lt;P&gt;This is an &lt;B&gt;extended&lt;/B&gt; notification!&lt;/P&gt;</TEXTX>
		</BODY>
	</MSG>
</NOTIFICATION>
C: OUT
```
Client disconnects from server.  
Server disconnects client.
