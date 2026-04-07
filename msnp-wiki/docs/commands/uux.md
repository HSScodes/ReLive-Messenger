# Introduction
`UUX` is a command introduced with [MSNP11](../versions/msnp11.md).

It is a Notification Server command, WITH a request payload and WITH a response payload.

Updates the current user's XML data.  
For the version of the command that is sent from the server that relates to another user, read [UBX](ubx.md).

# Client/Request
```
UUX TrID length
payload
```

Where `length` is the size (in bytes) of the `payload`.

Where `payload` is the combined XML data you would like to publish,
contained in a `<Data>` element:
* `<PSM>`: Your new Personal Status Message.
* `<CurrentMedia>`: Your new currently playing media status.
* `<MachineGuid>`: The GUID of the computer you are using.
  Added since [MSNP13](../versions/msnp13.md).

# Server/Response
`UUX TrID length`

Where `length` is always `0`.

# Examples
*NOTE: The XML in these examples has been exploded for visibility and formatting reasons.  
The payload sizes provided are to represent the size of the unexploded payloads.*

## Without MachineGuid
*Only in [MSNP11](../versions/msnp11.md) and [MSNP12](../versions/msnp12.md).*

### Blank status
```msnp
C: UUX 1 53
<Data>
	<PSM></PSM>
	<CurrentMedia></CurrentMedia>
</Data>
S: UUX 1
```

### With PSM
```msnp
C: UUX 2 75
<Data>
	<PSM>example status message</PSM>
	<CurrentMedia></CurrentMedia>
</Data>
S: UUX 2
```

### With playing media
```msnp
C: UUX 3 137
<Data>
	<PSM>example status message</PSM>
	<CurrentMedia>\0Music\01\0{0} - {1}\0Song Title\0Song Artist\0Song Album\0\0</CurrentMedia>
</Data>
S: UUX 3
```

## With MachineGuid
*Since [MSNP13](../versions/msnp13.md).*

### Blank status
```msnp
C: UUX 4 118
<Data>
	<PSM></PSM>
	<CurrentMedia></CurrentMedia>
	<MachineGuid>{44BFD5A4-7450-4BDA-BA3A-C51B3031126D}</MachineGuid>
</Data>
S: UUX 4
```

### With PSM
```msnp
C: UUX 5 140
<Data>
	<PSM>example status message</PSM>
	<CurrentMedia></CurrentMedia>
	<MachineGuid>{44BFD5A4-7450-4BDA-BA3A-C51B3031126D}</MachineGuid>
</Data>
S: UUX 5
```

### With playing media
```msnp
C: UUX 6 202
<Data>
	<PSM>example status message</PSM>
	<CurrentMedia>\0Music\01\0{0} - {1}\0Song Title\0Song Artist\0Song Album\0\0</CurrentMedia>
	<MachineGuid>{44BFD5A4-7450-4BDA-BA3A-C51B3031126D}</MachineGuid>
</Data>
S: UUX 6
```

## Invalid data
```msnp
C: UUX 7 19
<invalid></invalid>
```
Server disconnects client.

# Known changes
* [MSNP13](../versions/msnp13.md): Added `<MachineGuid>` to payload.
