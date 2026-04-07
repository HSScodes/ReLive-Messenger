# Introduction
`CHL` is a command introduced with [MSNP6](../versions/msnp6.md).

It is a Notification Server command, without a request or response payload.

A request to generate or solve a challenge.
Respond correctly with [QRY](qry.md) on a new transaction to continue your connection.

# Client/Request
`CHL TrID`

# Server/Response
`CHL TrID challenge`

If this command is sent asynchronously, the Transaction ID will be `0` instead.

Where `challenge` is usually a 20-character numeric value (but can be any valid string)
that is concatenated with the client's Private Key.

# Examples

## Client-initiated challenge
```msnp
C: CHL 1
S: CHL 1 12345678901234567890
```

## From server at any time
```msnp
S: CHL 0 12345678901234567890
```

## Challenge timeout
```msnp
S: CHL 0 12345678901234567890
```
... some time passes ...
```msnp
S: OUT
```
Server disconnects client.

# Known changes
* [MSNP11](../versions/msnp11.md): Changed challenge response ([QRY](qry.md) commands) generation algorithm drastically.
