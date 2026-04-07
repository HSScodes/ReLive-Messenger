# Introduction
`RMG` is a command introduced with [MSNP7](../versions/msnp7.md).

It is a Notification Server command, without either a request or response payload.

Removes all users from a group and the group itself.
Replaced with [Address Book Service](../services/abservice.md)'s
[`ABGroupDelete`](../services/abservice/abgroupdelete.md) in [MSNP13](../versions/msnp13.md).

# Client/Request
`RMG TrID group-id`

Where `group-id` is the identification number of the group you would like to remove.
With `ABCHMigrated: 1`, this parameter is instead the GUID of the group you'd like to remove.
You cannot remove the "Other Contacts" group (group ID `0`).

*NOTE: If users are exclusively in the group you remove,
THEY WILL BE ALSO REMOVED FROM THE FORWARD LIST (FL).*

# Server/Response
`RMG TrID {list-version} group-id`

Where `list-version` is the new List Version. Removed in [MSNP10](../versions/msnp10.md).

# Examples

## With List Versions
*Only in [MSNP7](../versions/msnp7.md) to [MSNP9](../versions/msnp9.md).*

## Without List Versions

### Normal use
```msnp
C: RMG 1 1
S: RMG 1 256 1
```

### Group doesn't exist yet
```msnp
C: RMG 2 2
S: 224 2
```

### Can not remove the initial group
```msnp
C: RMG 3 0
S: 230 3
```

### Can not remove out-of-bounds groups
```msnp
C: RMG 4 30
```
Server disconnects client.

### With group IDs
*Only in [MSNP10](../versions/msnp10.md) with `ABCHMigrated: 0`.*

#### Normal use
```msnp
C: RMG 5 1
S: RMG 5 1
```

#### Group doesn't exist yet
```msnp
C: RMG 6 2
S: 224 6
```

#### Can not remove the initial group
```msnp
C: RMG 7 0
S: 230 7
```

#### Can not remove out-of-bounds groups
```msnp
C: RMG 8 30
```
Server disconnects client.

### With group GUIDs
*Since [MSNP10](../versions/msnp10.md) with `ABCHMigrated: 1`.*

#### Normal use
```msnp
C: RMG 9 f60efbe7-94af-4b16-b926-e4e10878d329
S: RMG 9 f60efbe7-94af-4b16-b926-e4e10878d329
```

#### Group doesn't exist yet
```msnp
C: RMG 10 11111111-2222-3333-4444-555555555555
S: 224 10
```

#### Can not remove the initial group
```msnp
C: RMG 11 d6deeacd-7849-4de4-93c5-d130915d0042
S: 230 11
```

#### Can not remove out-of-bounds groups
```msnp
C: RMG 12 THIS0IS0-NOT0-A0VA-LID0-GUID0AT0ALL!
```
Server disconnects client.

## Command removed
*Since [MSNP13](../versions/msnp13.md).*
```msnp
C: RMG 13 f60efbe7-94af-4b16-b926-e4e10878d329
```
Server disconnects client.

# Known changes
* [MSNP10](../versions/msnp10.md): Removed the List Version parameter, and with `ABCHMigrated: 1`
* [MSNP13](../versions/msnp13.md): Removed (automatic disconnect),
  use [Address Book Services](../services/abservice.md)'s
  [`ABGroupDelete`](../services/abservice/abgroupdelete.md) instead.
