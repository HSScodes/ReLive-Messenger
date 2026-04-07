# Introduction
`PNG` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Notification Server command, without a request payload.

Makes the server respond with a [QNG](qng.md) command.

# Client/Request
`PNG`

# Server/Response
The server responds to this command via [QNG](qng.md).

# Examples

## Client-initiated
```msnp
C: PNG
S: QNG
```

# Known changes
None.
