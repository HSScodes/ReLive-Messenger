# Introduction
`CHG` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Notification Server command, without either a request or response payload.

Changes your presence status,
and sets your [Client Capabilities](../files/client_capabilities.md) and MSNObject in later MSNP versions.

# Client/Request
`CHG TrID status {flags} {msnobj}`

Where `status` can be any of the below:
* `NLN`: Online
* `BSY`: Busy
* `IDL`: Idle
* `BRB`: Be Right Back
* `AWY`: Away (previously Away From Keyboard)
* `PHN`: On The Phone
* `LUN`: Out To Lunch
* `HDN`: Appear Offline (previously Invisible)
* `FLN`: Semi-offline. More on this below.

In [MSNP8](../versions/msnp8.md) and higher, `flags`, an optional parameter may be used to
specify your [Client Capabilities](../files/client_capabilities.md).

In [MSNP9](../versions/msnp9.md) and higher, `msnobj`, an optional parameter may be used to
add additional information related to your user. Requires that `flags` MUST be set to use.
The MSNObject itself is a XML-like element.

## Status explanations
All statuses except `HDN` and `FLN` will treat you as online.  
Which means all users on your Allow List (AL) and Reverse List (RL)
will get all presence changes via the NLN command.

The statuses `HDN` and `FLN` will treat you as offline.  
Which means all users on your Allow List (AL) and Reverse List (RL)
will get a FLN command instead of an NLN command.  
Also, all attempts to create a Switchboard session will fail automatically,

Exclusive to the `FLN` state, you are put in a very reduced state where you can
only recieve presence changes from other users and resynchronize your Lists.  
You may be able to execute more commands, but doing so is Undefined Behaviour.

# Server/Response
`CHG TrID status {flags} {msnobj}`

The server may also send this command asynchronously (at any time) with the `TrID` set to `0`.

# Examples

## Changing status to Online
```msnp
C: CHG 1 NLN
S: CHG 1 NLN
```

## Changing status to Idle with Capability Flags
*This only works in [MSNP8](../versions/msnp8.md) and higher.*
```msnp
C: CHG 2 IDL 1
S: CHG 2 IDL 1
```

## Changing status to Busy with Capability Flags and a MSNObject.
*This only works in [MSNP9](../versions/msnp9.md) and higher.*

*NOTE: This has been line-broken.
Lines beginning with `..` followed by a space are continuations of the previous line.*
```msnp
C: CHG 3 BSY 268435500 %3Cmsnobj%20Creator%3D%22example%40hotmail.com%22
.. %20Size%3D%2225235%22%20Type%3D%223%22
.. %20Location%3D%22uexA4DE.dat%22%20Friendly%3D%22AAA%3D%22
.. %20SHA1D%3D%22vP1ppB+xiFQ8ceZivRe0uCaYLIU%3D%22
.. %20SHA1C%3D%22DBRJPnGb+wBYawENkdor1bOdYUs%3D%22%2F%3E
S: CHG 3 BSY 268435500 %3Cmsnobj%20Creator%3D%22example%40hotmail.com%22
.. %20Size%3D%2225235%22%20Type%3D%223%22
.. %20Location%3D%22uexA4DE.dat%22%20Friendly%3D%22AAA%3D%22
.. %20SHA1D%3D%22vP1ppB+xiFQ8ceZivRe0uCaYLIU%3D%22
.. %20SHA1C%3D%22DBRJPnGb+wBYawENkdor1bOdYUs%3D%22%2F%3E
```

## Server asynchronously changes your status to Semi-offline.
```msnp
S: CHG 0 FLN
```

## Invalid argument
*NOTE: There is no defined behaviour for this command specifically.*
```msnp
C: CHG 4 HOT
```
Server disconnects client.

# Known changes
* [MSNP8](../versions/msnp8.md): Added optional [Client Capabilities](../files/client_capabilities.md) parameter (as parameter 2).
* [MSNP9](../versions/msnp9.md): Added optional MSNObject parameter (as parameter 3).
