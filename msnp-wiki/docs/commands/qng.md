# Introduction
`QNG` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Notification Server command, without either a request or response payload.

It is the server's response to the [PNG](png.md) command.

# Client/Request
This command can not be sent from the client.

# Server/Response
`QNG {next-seconds}`

Where `next-seconds` is the amount of seconds until the client should send another [PNG](png.md). Added since [MSNP9](../versions/msnp9.md).

# Examples

## Server reply, without next seconds parameter
*Only in [MSNP2](../versions/msnp2.md) to [MSNP8](../versions/msnp8.md).*
```msnp
C: PNG
S: QNG
```

## Server reply, with next seconds parameter
*Since [MSNP9](../versions/msnp9.md).*
```msnp
C: PNG
S: QNG 50
```

## Invalid context
*Inherited from being an unimplemented command.*
```msnp
C: QNG
```
Server disconnects client.

# Known changes
* [MSNP9](../versions/msnp9.md): Added a next seconds parameter (parameter 1).
