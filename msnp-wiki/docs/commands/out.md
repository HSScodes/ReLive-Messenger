# Introduction
`OUT` is a command introduced with [MSNP2](../versions/msnp2.md).

It exists in all servers, without either a request or response payload.

It disconnects either the server or the client gracefully.

This command does not require a Transaction ID.

# Client/Request
`OUT`

# Server/Response
`OUT {reason}`

Where `reason` can be:
* `OTH`: Other client logged in to this account.
* `SSD`: Server is shutting down.
* `MIG`: [MSNP10](../versions/msnp10.md) and higher: Contact list has been migrated.
* `TOU`: [MSNP10](../versions/msnp10.md) and higher: You need to accept the Terms Of Use.
* `RCT`: [MSNP11](../versions/msnp11.md) and higher: Temporary server closure, please reconnect in (parameter 2) minutes.

`OUT RCT {minutes}`

Where `minutes` is the amount of minutes the client should wait before trying to log in automatically again.

# Examples

## Client-initiated
```msnp
C: OUT
```
Client disconnects from server.  
Server disconnects client.

## Logged in from another client
```msnp
S: OUT OTH
```
Server disconnects client.

## Server is shutting down
```msnp
S: OUT SSD
```
Server disconnects client.

## ABCH migration
*Only in [MSNP10](../versions/msnp10.md).*
```msnp
S: OUT MIG
```
Server disconnects client.

## Terms of Use update
*Since [MSNP10](../versions/msnp10.md).*
```msnp
S: OUT TOU
```
Server disconnects client.

## Forced reconnect
*Since [MSNP11](../versions/msnp11.md).*
```msnp
S: OUT RCT 6
```
Server disconnects client.

# Known changes
* [MSNP10](../versions/msnp10.md): Added `MIG` (Migrated) and `TOU` (Terms of Use) reasons.
* [MSNP11](../versions/msnp11.md): Added `RCT` (Reconnect) reason.
