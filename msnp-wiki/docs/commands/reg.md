# Introduction
`REG` is a command introduced with [MSNP7](../versions/msnp7.md)

It is a Notification Server command, without either a request or response payload.

Renames an existing group. Replaced with [Address Book Service](../services/abservice.md)'s
[`ABGroupUpdate`](../services/abservice/abgroupupdate.md) in [MSNP13](../versions/msnp13.md).

# Client/Request
`REG TrID group-id new-group-name {0}`

Where `group-id` is the group's identification number.
With `ABCHMigrated: 1`, this is instead the group's GUID.

Where `new-group-name` is the name you want to rename `group-id` to.
Has a limit of 127 bytes (URL-encoded characters count as 3 bytes).

Where `0` is always `0`. Removed in [MSNP10](../versions/msnp10.md).

# Server/Response
`REG TrID {list-version} group-id group-name {0}`

Where `list-version` is the new List Version. Removed in [MSNP10](../versions/msnp10.md)

Where` group-name` is the updated name of the group.

# Examples

## With list versions
*Only in [MSNP7](../versions/msnp7.md) to [MSNP9](../versions/msnp9.md).*

### Normal use
```msnp
C: REG 1 0 example%20group%20rename 0
S: REG 1 256 0 example%20group%20rename 0
```

### Cannot rename group that doesn't exist yet
```msnp
C: REG 2 2 non-existant%20group 0
S: 224 2
```

### Cannot rename out-of-bounds groups
```msnp
C: REG 3 30 example%20out%20of%20bounds%20group 0
```
Server disconnects client.

### Group name extremely long
*NOTE: This has been line-broken.
Lines beginnging with `..` followed by a space are continuations of the previous line.*
```msnp
C: REG 4 0 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
.. AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
.. AAAAAAAAA 0
```
Server disconnects client.

## Without list versions

### With group IDs
*Only in [MSNP10](../versions/msnp10.md) with `ABCHMigrated: 0`.*

#### Normal use
```msnp
C: REG 5 0 another%20example%20group%20rename
S: REG 5 0 another%20example%20group%20rename
```

#### Cannot rename group that doesn't exist yet
```msnp
C: REG 6 2 still%20a%20non-existant%20group
S: 224 6
```

#### Cannot rename out-of-bounds groups
```msnp
C: REG 7 30 still%20out%20of%20bounds
```
Server disconnects client.

### Group name extremely long
*NOTE: This has been line-broken.
Lines beginnging with `..` followed by a space are continuations of the previous line.*
```msnp
C: REG 8 0 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
.. AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
.. AAAAAAAAA
```
Server disconnects client.

### With group GUIDs
*Since [MSNP10](../versions/msnp10.md) with `ABCHMigrated: 1`.*

#### Normal use
```msnp
C: REG 9 d6deeacd-7849-4de4-93c5-d130915d0042 yet%20another%20example%20group%20rename
C: REG 9 d6deeacd-7849-4de4-93c5-d130915d0042 yet%20another%20example%20group%20rename
```

#### Cannot rename group that doesn't exist yet
```msnp
C: REG 10 11111111-2222-3333-4444-555555555555 still%20a%20non-existant%20group
S: 224 10
```

#### Cannot use an invalid GUID
```msnp
C: REG 11 THIS0IS0-NOT0-A0VA-LID0-GUID0AT0ALL! very%20invalid%20GUID%20there
```
Server disconnects client.

### Group name extremely long
*NOTE: This has been line-broken.
Lines beginnging with `..` followed by a space are continuations of the previous line.*
```msnp
C: REG 12 d6deeacd-7849-4de4-93c5-d130915d0042 AAAAAAAAAAAAAAAAAAAA
.. AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
.. AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
```
Server disconnects client.

## Command removed
*Since [MSNP13](../versions/msnp13.md).*
```msnp
C: REG 13 f60efbe7-94af-4b16-b926-e4e10878d329 Other%20Friends
```
Server disconnects client.

# Known changes
* [MSNP10](../versions/msnp10.md): Removed unused `0` parameter, removed List Versions,
  and with `ABCHMigrated: 1`, changed group IDs to GUIDs.
* [MSNP13](../versions/msnp13.md): Removed (automatic disconnect),
  use [Address Book Service](../services/abservice.md)'s
  [`ABGroupUpdate`](../services/abservice/abgroupupdate.md) instead.
