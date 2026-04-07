# Introduction
`IMS` is a command introduced with [MSNP3](../versions/msnp3.md).

It is a Notification Server command, without either a request or response payload.

It enables or disables switchboard access without modifying the user's current status.  
This command is only sent by WebTV clients.

# Client/Request
`IMS TrID [ ON | OFF ]`

# Server/Response
`IMS TrID 0 [ ON | OFF ]`

Where `0` has an unknown purpose.
Rumored to be a timeout of some kind. [TODO: Please confirm this.]

# Examples

## Turning Switchboard access on
```msnp
C: IMS 1 ON
S: IMS 1 0 ON
```

## Turning Switchboard access off
```msnp
C: IMS 2 OFF
S: IMS 2 0 OFF
```

## Invalid argument
*NOTE: There is no defined behaviour for this command specifically.*
```msnp
C: IMS 3 TOMORROW
```
Server disconnects client.

# Known changes
None.
