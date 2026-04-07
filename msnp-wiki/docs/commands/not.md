# Introduction
`NOT` is a command introduced with [MSNP5](../versions/msnp5.md).

It is a Notification Server command, WITH a response payload.

Used to send notifications ("alerts") to the client.

# Client/Request
This command can not be sent from the client.

# Server/Response
```
NOT length
payload
```

Where `length` is the size (in bytes) of the `payload`.

Where `payload` is a [`<NOTIFICATION>` document](../files/notification.md).

# Examples

## Basic notification
```msnp
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
```

## Extended notification
*Since [MSNP9](../versions/msnp9.md).*
```msnp
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
```

## Blog update notification
*Since [MSNP11](../versions/msnp11.md).*
```msnp
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
```

## Contact update notification
*Since [MSNP13](../versions/msnp13.md).*
```msnp
S: NOT 694
<NOTIFICATION id="2" siteid="45705" siteurl="http://contacts.msn.com/">
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
				&lt;Service&gt;ABCHInternal&lt;/Service&gt;
				&lt;CID&gt;4294967298&lt;/CID&gt;
				&lt;LastModifiedDate&gt;2024-10-26T09:33:27.1020000-08:00&lt;/LastModifiedDate&gt;
				&lt;HasNewItem&gt;false&lt;/HasNewItem&gt;
			&lt;/NotificationData&gt;
		</BODY>
	</MSG>
</NOTIFICATION>
```

## Invalid context
*Inherited from being an unimplemented command.*
```msnp
C: NOT 1 0
```
Server disconnects client.

# Known changes
* [MSNP9](../versions/msnp9.md): Added support for extended notifications using the `<TEXTX>` element.
* [MSNP11](../versions/msnp11.md): Using an `<NotificationData>` sub-document embedded into a `<NOTIFICATION>` document is supported.
  Using the new sub-document, live blog updates are now sent.
* [MSNP13](../versions/msnp13.md): Used for [Address Book Service](../services/abservice.md) live updates using the `<NotificationData>` sub-document.
* [MSNP18](../versions/msnp18.md): Used for live persistent chat group ("circle") updates using the `<NotificationData>` sub-document.
