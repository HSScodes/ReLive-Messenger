# Introduction
`NLN` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Notification Server command, without a response payload.

Specifies that a user has now came online.  
For the version sent with a Transaction ID as a response to some commands, read [ILN](iln.md).

# Client/Request
This command can not be sent from the client.

# Server/Response
`NLN status user-handle {network-id} friendly-name {client-capabilities{:extended-client-capabilities}} {msnobj} {presence-icon-url}`

Where `status` is any of the defined statuses:
* `NLN`: Online
* `BSY`: Busy
* `IDL`: Idle
* `BRB`: Be Right Back
* `AWY`: Away
* `PHN`: On The Phone
* `LUN`: Out To Lunch
* `HDN`: Appear Offline (previously Invisible, Valid but should never be sent.)
* `FLN`: Offline (Valid but should never be sent.)

Where `user-handle` is the relevant user's handle.

Where `network-id` is the Network Identification Number that this user is from.
Added since [MSNP14](../versions/msnp14.md).

Where `friendly-name` is the relevant user's friendly name.

Where `client-capabilities` are the relevant user's Client Capabilities. Optional? Added since [MSNP8](../versions/msnp8.md).

Where `extended-client-capabilities` are the relevant user's Extended Client Capabilities.
Optional. Added since [MSNP16](../versions/msnp16.md).

Where `msnobj` is the MSNObject the relevant user has set. Optional. Added since [MSNP9](../versions/msnp9.md).

Where `presence-icon-url` is an image that is rendered to this client that replaces the default user icon.
Optional. Added since [MSNP14](../versions/msnp14.md).

# Examples

## Only with status
```msnp
S: NLN NLN anotheruser@example.com another%20user
```

## With Client Capabilities
*Since [MSNP8](../versions/msnp8.md).*
```msnp
S: NLN NLN anotheruser@example.com another%20user 0
```

## With a MSNObject
*Since [MSNP9](../versions/msnp9.md).*

*NOTE: This has been line-broken.
Lines beginning with `..` followed by a space are continuations of the previous line.*
```msnp
S: NLN NLN anotheruser@hotmail.com another%20user 268435500 %3Cmsnobj%20Creator%3D%22anotherdude%40hotmail.com%22
.. %20Size%3D%2225235%22%20Type%3D%223%22
.. %20Location%3D%22uexA4DE.dat%22%20Friendly%3D%22AAA%3D%22
.. %20SHA1D%3D%22vP1ppB+xiFQ8ceZivRe0uCaYLIU%3D%22
.. %20SHA1C%3D%22PApbbjkbDSGrt3ybGHRKNaZ8s%2Fw%3D%22%2F%3E
```

## With Network IDs and Presence Icon URLs
*Since [MSNP14](../versions/msnp14.md).*

*NOTE: This has been line-broken.
Lines beginning with `..` followed by a space are continuations of the previous line.*
```msnp
S: NLN NLN anotheruser@hotmail.com 1 another%20user 1611513916 %3Cmsnobj%20Creator%3D%22anotherdude%40hotmail.com%22
.. %20Size%3D%2225235%22%20Type%3D%223%22
.. %20Location%3D%22uexA4DE.dat%22%20Friendly%3D%22AAA%3D%22
.. %20SHA1D%3D%22vP1ppB+xiFQ8ceZivRe0uCaYLIU%3D%22
.. %20SHA1C%3D%22PApbbjkbDSGrt3ybGHRKNaZ8s%2Fw%3D%22%2F%3E
..  http://example.com/interop/online.png
```

## With Extended Client Capabilities
*Since [MSNP16](../versions/msnp16.md).*

*NOTE: This has been line-broken.
Lines beginning with `..` followed by a space are continuations of the previous line.*
```msnp
S: NLN NLN anotheruser@hotmail.com 1 another%20user 2789003324:48 %3Cmsnobj%20Creator%3D%22anotherdude%40hotmail.com%22
.. %20Size%3D%2225235%22%20Type%3D%223%22
.. %20Location%3D%22uexA4DE.dat%22%20Friendly%3D%22AAA%3D%22
.. %20SHA1D%3D%22vP1ppB+xiFQ8ceZivRe0uCaYLIU%3D%22
.. %20SHA1C%3D%22PApbbjkbDSGrt3ybGHRKNaZ8s%2Fw%3D%22%2F%3E
..  http://example.com/interop/online.png
```

## Invalid context
*Inherited from being an unimplemented command.*
```msnp
C: NLN FLN example@hotmail.com example%20user
```
Server disconnects client.

# Known changes
* [MSNP8](../versions/msnp8.md): Added a parameter for Client Capabilities.
* [MSNP9](../versions/msnp9.md): Added a parameter for the MSNObject.
* [MSNP14](../versions/msnp14.md): Added a way to override the default presence icon, and added a new non-optional Network ID parameter.
* [MSNP16](../versions/msnp16.md): Added Extended Client Capabilities support to the Client Capabilities parameter, delimited by a colon.
