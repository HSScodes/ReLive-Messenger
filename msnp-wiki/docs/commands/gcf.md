# Introduction
`GCF` is a command introduced with [MSNP11](../versions/msnp11.md).

It is a Notification Server command, without a request payload and WITH a response payload.

It gets configuration data from a file on the server.

# Client/Request
*Only in [MSNP11](../versions/msnp11.md) and [MSNP12](../versions/msnp12.md).*

`GCF TrID filename`

Where filename is the file to retrieve. Only `Shields.xml` is known to be this parameter.

# Server/Response

## From filename
```
GCF TrID filename length
payload
```

Where `length` is the size (in bytes) of the `payload`.

Where `payload` is the data for this file.

## Asynchronously
```
GCF 0 length
payload
```

Being an asynchronous command, the Transaction ID is set to `0`.

### Policies
This element contains one or multiple `<Policy>` elements.

#### Policy
This element has two attributes:
* `type`: The type of policy:
    * `SHIELDS": The [Shields Configuration Data](../files/shields.md).
    * `ABCH`: [Address Book Service](../services/abservice.md) policies.
    * `ERRORRESPONSETABLE`: The same as the [Messenger Config](../services/msgrconfig.md)'s
      [`<ErrorResponseTable>`](../services/msgrconfig.md#errorresponsetable).
    * `P2P`: Peer-to-peer policies.
* `checksum`: A capitalized MD5 hash of the inner contents of this element.

# Examples

## Downloading shields
*For more information read the [Shields Configuration Data](../files/shields.md) article.*

### By filename
*Only in [MSNP11](../versions/msnp11.md) and [MSNP12](../versions/msnp12.md).*
```msnp
C: GCF 1 Shields.xml
S: GCF 1 Shields.xml 145
<?xml version="1.0" encoding="utf-8" ?><config><shield><cli maj="7" min="0" minbld="0" maxbld="9999" deny=" " /></shield><block></block></config>
```

### Automatically
*Since [MSNP13](../versions/msnp13.md).*
```msnp
C: USR 2 TWN I example@hotmail.com
S: GCF 0 203
<Policies><Policy type="SHIELDS" checksum="94A347C122C483F8BEAD525832DB2F71"><config><shield><cli maj="7" min="0" minbld="0" maxbld="9999" deny=" " /></shield><block></block></config></Policy></Policies>
S: USR 2 TWN S passport=parameters,neat=huh,lc=1033,id=507
```

## By filename after removal
*NOTE: I don't know if this is correct.*
```msnp
C: GCF 3 Shields.xml
```
Server disconnects client.

# Known changes
* [MSNP13](../versions/msnp13.md): Dropped support for getting a response via filenames,
  and changed how the Shields configuration data is contained.
