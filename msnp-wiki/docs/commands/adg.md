# Introduction
`ADG` is a command introduced with [MSNP7](../versions/msnp7.md).

It is a Notification Server command, without a request or response payload.

Creates a new group.
Replaced with [Address Book Service](../services/abservice.md)'s
[`ABGroupAdd`](../services/abservice/abgroupadd.md) in [MSNP13](../versions/msnp13.md).

# Client/Request
`ADG TrID group-name {0}`

Where `group-name` is the name of the group you'd like to create.
Has a limit of 61 bytes (URL encoded characters count as 3 bytes).

Where `0` is always `0`. Removed in [MSNP10](../versions/msnp10.md).

# Server/Response
`ADG TrID {list-version} group-name group-id {0}`

Where `list-version` is the new List Version. Removed in [MSNP10](../versions/msnp10.md).

Where `group-id` is your new group's identification number.

Where `0` is always `0`. Removed in [MSNP10](../versions/msnp10.md).

# Examples

## With list versions
*Only in [MSNP7](../versions/msnp7.md) to [MSNP9](../versions/msnp9.md).*

### Normal use
```msnp
C: ADG 1 New%20Group%201 0
S: ADG 1 256 New%20Group%201 29 0
```

### Cannot create more than 30 groups
```msnp
C: ADG 2 New%20Group%202 0
S: 223 2
```

### Group name too long
```msnp
C: ADG 3 This%2062%20character%20group%20name%20is%20%invalid.%20There. 0
S: 229 3
```

### Group name extremely long
*NOTE: This has been line-broken.
Lines beginnging with `..` followed by a space are continuations of the previous line.*
```msnp
C: ADG 3 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
.. AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
.. AAAAAAA 0
```
Server disconnects client.

## Without list versions

### With group IDs
*Only in [MSNP10](../versions/msnp10.md) with `ABCHMigrated: 0`.*

#### Normal use
```msnp
C: ADG 4 Friends
S: ADG 4 Friends 1
```

#### Cannot create more than 30 groups
```msnp
C: ADG 5 New%20Group%203
S: 223 2
```

#### Group name too long
```msnp
C: ADG 6 This%2062%20character%20group%20name%20is%20%invalid.%20There.
S: 229 6
```

#### Group name extremely long
*NOTE: This has been line-broken.
Lines beginnging with `..` followed by a space are continuations of the previous line.*
```msnp
C: ADG 7 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
.. AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
.. AAAAAAA
```
Server disconnects client.

### With group GUIDs
*Since [MSNP10](../versions/msnp10.md) with `ABCHMigrated: 1`.*

#### Normal use
```msnp
C: ADG 8 Friends
S: ADG 8 Friends f60efbe7-94af-4b16-b926-e4e10878d329
```

#### Cannot create more than 30 groups
```msnp
C: ADG 9 New%20Group%203
S: 223 9
```

#### Group name too long
```msnp
C: ADG 10 This%2062%20character%20group%20name%20is%20%invalid.%20There.
S: 229 10
```

#### Group name extremely long
*NOTE: This has been line-broken.
Lines beginnging with `..` followed by a space are continuations of the previous line.*
```msnp
C: ADG 11 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
.. AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
.. AAAAAAA
```
Server disconnects client.

## Command removed
*Since [MSNP13](../versions/msnp13.md).*
```msnp
C: ADG 12 Example%20Group
```
Server disconnects client.

# Known changes
* [MSNP10](../versions/msnp10.md): Removed unused `0` parameter,
  Returns a GUID instead of a Group ID if `ABCHMigrated: 1`.
* [MSNP13](../versions/msnp13.md): Removed (automatic disconnect),
  use [Address Book Service](../services/abservice.md)'s
  [`ABGroupAdd`](../services/abservice/abgroupadd.md) instead.
