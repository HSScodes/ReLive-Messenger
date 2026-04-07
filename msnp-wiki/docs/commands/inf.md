# Introduction
`INF` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Dispatch Server and Notification Server command, without either a request or response payload.

It specifies which authentication methods the client is allowed to use.

This command can only be sent once.
Any further uses of this command in the same session is Undefined Behaviour.

# Client/Request
`INF TrID`

# Server/Response
`INF TrID security-package {security-package ...}`

Where one or more `security-package` parameters being the available authentication methods your client is allowed to use.

# Examples

## Two types supported
*This configuration is only supported in [MSNP2](../versions/msnp2.md).*
```msnp
C: INF 1
S: INF 1 MD5 CTP
```

## One type supported
```msnp
C: INF 2
S: INF 2 MD5
```

## Command removed
*Since [MSNP8](../versions/msnp8.md).*
```msnp
C: INF 3
```
Server disconnects client.

# Known changes
* [MSNP3](../versions/msnp3.md): Removed `CTP` support.
* [MSNP8](../versions/msnp8.md). Removed. [USR](usr.md) always assumes the authentication method is `TWN`.
