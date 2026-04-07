# Introduction
`UBX` is a command introduced with [MSNP11](../versions/msnp11.md).

It is a Notification Server command, WITH a response payload.

Updates a buddy's XML data.  
For the version of the command that is sent by the client, read [UUX](uux.md).

# Client/Request
This command can not be sent from the client.

# Server/Response
```
UBX user-handle {network-id} length
payload
```

Where `user-handle` is the user handle associated with this data.

Where `network-id` is a Network Identification Number. Added since [MSNP14](../versions/msnp14.md).

Where `length` is the size (in bytes) of the `payload`.

Where `payload` is the XML data for this user on the Forward List (FL),
contained in a `<Data>` element:
* `<PSM>`: The user's new Personal Status Message.
* `<CurrentMedia>`: The user's new currently playing media status.
* `<MachineGuid>`: The GUID of the computer that the user is using.
  Added since [MSNP13](../versions/msnp13.md).

# Examples
*NOTE: The XML in these examples has been exploded for visibility and formatting reasons.  
The payload sizes provided are to represent the size of the unexploded payloads.*

## Without MachineGuid
*Only in [MSNP11](../versions/msnp11.md) and [MSNP12](../versions/msnp12.md).*

### Blank status
```msnp
S: UBX anotheruser@hotmail.com 53
<Data>
	<PSM></PSM>
	<CurrentMedia></CurrentMedia>
</Data>
```

### With PSM
```msnp
S: UBX anotheruser@hotmail.com 75
<Data>
	<PSM>example status message</PSM>
	<CurrentMedia></CurrentMedia>
</Data>
```

### With playing media
```msnp
S: UBX anotheruser@hotmail.com 137
<Data>
	<PSM>example status message</PSM>
	<CurrentMedia>\0Music\01\0{0} - {1}\0Song Title\0Song Artist\0Song Album\0\0</CurrentMedia>
</Data>
```

## With MachineGuid
*Only in [MSNP13](../versions/msnp13.md).*

### Blank status
```msnp
S: UBX anotheruser@hotmail.com 118
<Data>
	<PSM></PSM>
	<CurrentMedia></CurrentMedia>
	<MachineGuid>{0061D708-CD9B-4D56-B64B-FFFAA92FF344}</MachineGuid>
</Data>
```

### With PSM
```msnp
S: UBX anotheruser@hotmail.com 140
<Data>
	<PSM>example status message</PSM>
	<CurrentMedia></CurrentMedia>
	<MachineGuid>{0061D708-CD9B-4D56-B64B-FFFAA92FF344}</MachineGuid>
</Data>
```

### With playing media
```msnp
S: UBX anotheruser@hotmail.com 202
<Data>
	<PSM>example status message</PSM>
	<CurrentMedia>\0Music\01\0{0} - {1}\0Song Title\0Song Artist\0Song Album\0\0</CurrentMedia>
	<MachineGuid>{0061D708-CD9B-4D56-B64B-FFFAA92FF344}</MachineGuid>
</Data>
```

## With Network IDs
*Since [MSNP14](../versions/msnp14.md).*

### Blank status
```msnp
S: UBX anotheruser@hotmail.com 1 118
<Data>
	<PSM></PSM>
	<CurrentMedia></CurrentMedia>
	<MachineGuid>{0061D708-CD9B-4D56-B64B-FFFAA92FF344}</MachineGuid>
</Data>
```

### With PSM
```msnp
S: UBX anotheruser@hotmail.com 1 140
<Data>
	<PSM>example status message</PSM>
	<CurrentMedia></CurrentMedia>
	<MachineGuid>{0061D708-CD9B-4D56-B64B-FFFAA92FF344}</MachineGuid>
</Data>
```

### With playing media
```msnp
S: UBX anotheruser@hotmail.com 1 202
<Data>
	<PSM>example status message</PSM>
	<CurrentMedia>\0Music\01\0{0} - {1}\0Song Title\0Song Artist\0Song Album\0\0</CurrentMedia>
	<MachineGuid>{0061D708-CD9B-4D56-B64B-FFFAA92FF344}</MachineGuid>
</Data>
```

## Invalid context
*Inherited from being an unimplemented command.*
```msnp
C: UBX 1 0
```
Server disconnects client.

# Known changes
* [MSNP13](../versions/msnp13.md): Added `<MachineGuid>` to payload.
* [MSNP14](../versions/msnp14.md): Added a new parameter for the Network ID related to this update (parameter 2).
