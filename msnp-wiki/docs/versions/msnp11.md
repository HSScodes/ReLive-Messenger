# Introduction
MSNP11 is the tenth released version of the Mobile Status Notification Protocol.  
It was introduced officially in Client Version 7.0.0777.

# Command information
It introduces the notification service commands:
* [GCF](../commands/gcf.md)
* GSB
* SBS
* [UBX](../commands/ubx.md)
* [UUX](../commands/uux.md)

*No switchboard or dispatch service commands were known to be introduced in this version.*

*No commands were known to be removed in this version.*

# Known changes
(from [MSNP10](msnp10.md)):
* [QRY](../commands/qry.md): Challenge response generation has been drastically overhauled.  
  An implementation is provided as `SolveMSNP11Challenge` in [`msnp_challenges.cs`](../files/msnp_challenges.cs.md).
* [OUT](../commands/out.md) `RCT TimeBeforeRetry` now exists.  
  `TimeBeforeRetry` is a numerical value in minutes that specifies the amount
  of time in minutes the client should wait before reconnecting.
* All `ABCHMigrated` changes are now the default.  
  `ABCHMigrated: 0` is to be considered Undefined Behaviour from now on.
* [ADC](../commands/adc.md): Now supports a telephone address (`tel:`) for `N=`.
* Entire content of initial email notification changed from
  `text/x-msmsgsinitialemailnotification` to `text/x-msmsgsinitialmdatanotification`.  
  The new format is XML-based.
* Offline Instant Messaging has been introduced, using `text/x-msmsgsoimnotification`
  messages from the Notification Server using a XML-based format,
  and a SOAP service for receiving message data.
* Official Client: Feature blocks are implemented using the [GCF](../commands/gcf.md) command to download `Shields.xml`.  
  For more information read the [Shields Configuration Data](../files/shields.md) article.
* Official Client: WebMessenger now canonically exists, the [Client Capability](../files/client_capabilities.md)
  flag `512` (`0x200` mask) is set for clients online via this method.
* Official Client: Notifications ([NOT](../commands/not.md) commands) with encoded
  [`<NotificationData>`](../files/notification.md) sub-documents are supported for spaces (blogs).
* Official Client: Messenger Config requests now support regional arguments via SOAP.
* Official Client: [OUT](../commands/out.md) `SSD` is actually implemented now.

# Client-server communication example
*NOTE: This has been line-broken.
Lines beginning with `..` followed by a space are continuations of the previous line.*
```msnp
C: VER 1 MSNP11 MSNP10 MSNP9 CVR0
S: VER 1 MSNP11
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
C: VER 4 MSNP11 MSNP10 MSNP9 CVR0
S: VER 4 MSNP11
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
S: SYN 8 2024-09-28T17:18:18.6400000-07:00 2024-09-28T17:18:18.6400000-07:00
C: GCF 9 Shields.xml
S: GCF 9 Shields.xml 145
<?xml version="1.0" encoding="utf-8" ?><config><shield><cli maj="7" min="0" minbld="0" maxbld="9999" deny=" " /></shield><block></block></config>
C: CHG 10 NLN
S: CHG 10 NLN
C: UUX 11 53
<Data><PSM></PSM><CurrentMedia></CurrentMedia></Data>
S: UUX 11 0
S: ILN 10 NLN anotheruser@hotmail.com another%20user 1073791084
S: UBX anotheruser@hotmail.com 67
<Data><PSM>new feature :P</PSM><CurrentMedia></CurrentMedia></Data>
C: ADC 11 FL N=tel:15551111222 F=john
S: ADC 11 FL N=tel:15551111222 F=john C=a47e39cf-312c-4100-94a6-f2b33adf5b68
C: ADC 12 AL N=tel:15551111222
S: ADC 12 AL N=tel:15551111222
S: NOT 1264
<NOTIFICATION id="2" siteid="45705" siteurl="http://storage.msn.com/">
	<TO pid="0x00000001:0x00000002" name="example@hotmail.com">
		<VIA agent="messenger"/>
	</TO>
	<MSG id="0">
		<ACTION url="a.htm" />
		<SUBSCR url="s.htm" />
		<BODY>
			&lt;NotificationData
				xmlns:xsd=&quot;http://www.w3.org/2001/XMLSchema&quot;
				xmlns:xsi=&quot;http://www.w3.org/2001/XMLSchema-instance&quot;
			&gt;
				&lt;SpaceHandle&gt;
					&lt;ResourceID&gt;example1!101&lt;/ResourceID&gt;
				&lt;/SpaceHandle&gt;
				&lt;ComponentHandle&gt;
					&lt;ResourceID&gt;example2!101&lt;/ResourceID&gt;
				&lt;/ComponentHandle&gt;
				&lt;OwnerCID&gt;4294967298&lt;/OwnerCID&gt;
				&lt;LastModifiedDate&gt;2024-10-26T09:33:27.1020000-08:00&lt;/LastModifiedDate&gt;
				&lt;HasNewItem&gt;true&lt;HasNewItem&gt;
				&lt;ComponentSummary&gt;
					&lt;Component xsi:type=&quot;MessageContainer&quot;&gt;
						&lt;ResourceID&gt;example2!102&lt;/ResourceID&gt;
					&lt;/Component&gt;
					&lt;Items&gt;
						&lt;Component xsi:type=&quot;Message&quot;&gt;
							&lt;ResourceID&gt;example2!101&lt;/ResourceID&gt;
						&lt;/Component&gt;
					&lt;/Items&gt;
				&lt;/ComponentSummary&gt;
			&lt;/NotificationData&gt;
		</BODY>
	</MSG>
</NOTIFICATION>
C: OUT
```
Client disconnects from server.  
Server disconnects client.
