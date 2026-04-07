# Introduction
`NAK` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Switchboard Server command, without a response payload.

Used as a negative response to [MSG](msg.md) N.

# Client/Request
This command can not be sent from the client.

# Server/Response
`NAK TrID`

# Examples

## As a response to MSG N
```msnp
C: MSG 1 N 69
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8

message
S: NAK 1
```

## Invalid context
*Inherited from being an unimplemented command.*
```msnp
C: NAK 2
```
Server disconnects client.

# Known changes
None.
