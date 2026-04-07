# Introduction
`GTC` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Notification Server command, without either a request or response payload.

It modifies whenever your client handles new users in your Reverse List (RL).

# Client/Request
`GTC TrID [ A | N ]`

# Server/Response
`GTC TrID {list-version} [ A | N ]`

Where `list-version` is the new List Version. Removed since [MSNP10](../versions/msnp10.md) in `ABCHMigrated: 1` mode.

# Examples

## Setting to A (Ask before adding to AL/BL)
```msnp
C: GTC 1 A
S: GTC 1 256 A
```

## Setting to N (Automatically add to AL)
```msnp
C: GTC 2 N
S: GTC 2 257 N
```

## Already in that mode
```msnp
C: GTC 3 A
S: GTC 3 258 A
C: GTC 4 A
S: 218 4
```

## Invalid argument
```msnp
C: GTC 5 B
```
Server disconnects client.

## Command removed
*Since [MSNP13](../versions/msnp13.md).*
```msnp
C: GTC 6 A
```
Server disconnects client.

# Known changes
* [MSNP10](../versions/msnp10.md) and higher: List Versions are dropped in `ABCHMigrated: 1` mode.
* [MSNP13](../versions/msnp13.md): Removed (automatic disconnect),
  set the `MSN.IM.GTC` annotation's value to either 0 or 1 with the
  [Address Book Service](../services/abservice.md)'s
  [`ABContactUpdate`](../services/abservice/abcontactupdate.md) action on your own GUID instead.
