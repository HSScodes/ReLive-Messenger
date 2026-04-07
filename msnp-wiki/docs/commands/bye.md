# Introduction
`BYE` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Switchboard Server command, without a response payload.

Used when a client leaves the current switchboard session.

# Client/Request
This client can not be sent from the client.

# Server/Response
`BYE user-handle {timeout}`

Where `user-handle` is the parting user's handle.

Where `timeout` is `1` if the server disconnected this user automatically. This parameter is optional.

# Examples

## User quit manually
```msnp
S: BYE anotheruser@hotmail.com
```

## User timed out
```msnp
S: BYE anotheruser@hotmail.com 1
```

## Invalid context
*Inherited from being an unimplemented command.*
```msnp
C: BYE 1
```
Server disconnects client.

# Known changes
None.
