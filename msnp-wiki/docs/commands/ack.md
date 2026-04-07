# Introduction
`ACK` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Switchboard Server command, without a response payload.

Used as a positive response to [MSG](msg.md) A, and later [MSG](msg.md) D commands.

# Client/Request
This command can not be sent from the client.

# Server/Response
`ACK TrID`

# Examples

## As a response to MSG A
```msnp
C: MSG 1 A 69
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8

message
S: ACK 1
```

## As a response to MSG D
*Since [MSNP9](../versions/msnp9.md).*
```msnp
C: MSG 2 D 73
MIME-Version: 1.0
Content-Type: application/octet-stream

data message
S: ACK 2
```

## Invalid context
*Inherited from being an unimplemented command.*
```msnp
C: ACK 3
```
Server disconnects client.

# Known changes
* [MSNP9](../versions/msnp9.md): Now happens as a response to MSG D.
