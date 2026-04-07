# Introduction
`IPG` is a command introduced with [MSNP6](../versions/msnp6.md).

It is a Notification Server command, WITH a response payload.

Used to send incoming pages (mobile text messages) to the client.
For the command to send text messages to a mobile device, read [PAG](pag.md) or [PGD](pgd.md).

# Client/Request
This command can not be sent from the client.

# Server/Response
```
IPG length
payload
```

Where `length` is the size (in bytes) of the `payload`.

Where `payload` is a [`<NOTIFICATION>` document](../files/notification.md).

# Examples

## Incoming page
```msnp
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
```

## Message failed to send
*The `id` attribute of the `<NOTIFICATION>` element is the Transaction ID of the
[PAG](pag.md) or [PGD](pgd.md) request.*
```msnp
S: IPG 439
<NOTIFICATION id="1" siteid="111100400" siteurl="http://mobile.msn.com/">
	<TO name="example@hotmail.com" pid="0x00000001:0x00000002" email="example@hotmail.com">
		<VIA agent="mobile"/>
	</TO>
	<FROM pid="0x00000001:0x00000002" name="anotheruser@hotmail.com"/>
	<MSG pri="1" id="407">
		<ACTION url="2wayIM.asp"/>
		<SUBSCR url="2wayIM.asp"/>
		<CAT id="110110001"/>
		<BODY lang="1033">
			<TEXT></TEXT>
		</BODY>
	</MSG>
</NOTIFICATION>
```

## Invalid context
```msnp
C: IPG 1 0
```
Server disconnects client.

# Known changes
None.
