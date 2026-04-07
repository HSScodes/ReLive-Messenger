# Introduction
`FLN` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Notification Server command, without either a request or response payload.

It specifies that another user in your contact list has gone offline.

# Client/Request
This command can not be sent from the client.

# Server/Response
`FLN user-handle {network-id} {client-capabilities{:extended-client-capabilities}} {presence-icon-url}`

Where `user-handle` is the related user's handle.

Where `network-id` is the Network Identification Number that this user is from.
Added since [MSNP14](../versions/msnp14.md).

Where `client-capabilities` are the relevant user's new Client Capabilities.
Optional? Added since [MSNP14](../versions/msnp14.md).

Where `extended-client-capabilities` are the relevant user's Extended Client Capabilities.
Optional. Added since [MSNP16](../versions/msnp16.md).

Where `presence-icon-url` is an image that is rendered to this client that replaces the default user icon.
Optional. Added since [MSNP14](../versions/msnp14.md).

# Examples

## User goes offline

### Without Network IDs
*Only in [MSNP2](../versions/msnp2.md) to [MSNP13](../versions/msnp13.md).*
```msnp
S: FLN anotheruser@hotmail.com
```

### With Network IDs and Preesense Icon URLs and Client Capabilities
*Since [MSNP14](../versions/msnp14.md).*
```msnp
S: FLN anotheruser@hotmail.com 1 0 http://example.com/interop/offline.png
```

### With Extended Client Capabilities
*Since [MSNP16](../versions/msnp16.md).*
```msnp
S: FLN anotheruser@hotmail.com 1 0:0 http://example.com/interop/offline.png
```

## Invalid context
*Inherited from being an unimplemented command.*
```msnp
C: FLN Hotmail
```
Server disconnects client.

# Known changes
* [MSNP14](../versions/msnp14.md): Added several new parameters that denotes the following:
	* Network ID of the user that is now offline.
	* The new client capabilities of the user that is now offline.
	* A way to override the default presence icon.
* [MSNP16](../versions/msnp16.md): Added Extended Client Capabilities support to the Client Capabilities parameter, delimited by a colon.
