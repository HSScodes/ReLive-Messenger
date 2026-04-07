# Introduction
`BLP` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Notification Server command, without either a request or response payload.

It modifies if messages sent to you by users not on your Allow List (AL) are allowed to be received.

# Client/Request
`BLP TrID [ AL | BL ]`

# Server/Response
`BLP TrID {list-version} [ AL | BL ]`

Where `list-version` is the new List Version. Removed since [MSNP10](../versions/msnp10.md) in `ABCHMigrated: 1` mode.

# Examples

## Setting to AL (Allow messages by default)
```msnp
C: BLP 1 AL
S: BLP 1 256 AL
```

## Setting to BL (Block messages by default)
```msnp
C: BLP 2 BL
S: BLP 2 257 BL
```

## Already in that mode
```msnp
C: BLP 3 AL
S: BLP 3 258 AL
C: BLP 4 AL
S: 218 4
```

## Invalid argument
```msnp
C: BLP 5 CL
```
Server disconnects client.

# Known changes
* [MSNP10](../versions/msnp10.md) and higher: List Versions are dropped in `ABCHMigrated: 1` mode.
