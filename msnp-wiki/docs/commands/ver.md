# Introduction
`VER` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Dispatch Server and Notification Server command, without either a request payload or response payload.

It specifies which protocols the client can accept, and which one the server likes the best.

This command can only be sent once.
Any further uses of this command in the same session is Undefined Behaviour.

# Client/Request
`VER TrID dialect-name {dialect-name ...}`

Where (possibly multiple) `dialect-name` parameters being the versions of the protocol your client can use.

# Server/Response
`VER TrID preferred-dialect-name`

Where `preferred-dialect-name` is the preferred version of the protocol the server will continue to use. The highest is usually preferred, unless it isn't supported by the server.

If the server's `preferred-dialect-name` is `0`, that means it doesn't want to use any of the protocols you have specified. A forced disconnect is to be expected in this circumstance.

# Examples

## No supported protocols
```msnp
C: VER 1 DISREGARDANCE FOR A REAL PROTOCOL
S: VER 1 0
```
Server disconnects client.

## Supported fallback protocol
```msnp
C: VER 2 MSNP2 CVR0
S: VER 2 CVR0
```

## Supported primary protocol
```msnp
C: VER 3 MSNP8 CVR0
S: VER 3 MSNP8
```

# Known changes
* Removed in MSNP24.
