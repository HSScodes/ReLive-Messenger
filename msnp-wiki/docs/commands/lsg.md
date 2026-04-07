# Introduction
`LSG` is a command introduced with [MSNP7](../versions/msnp7.md).

It is a Notification Server command, without a request or response payload.

It retrieves all groups.

# Client/Request
`LSG TrID`

# Server/Response

## Outside of SYN
`LSG TrID list-version index size-of-list group-id group-name 0`

Where `list-version` is the current List Version.

Where `index` is a number that can not go out of `size-of-list`.
If you have not added any groups, this value is always `1`.

Where `size-of-list` is the upper bounds for `index`.
If you have not added any groups, this value is always `1`.

Where `group-id` is the relevant group's identification number, allowed values are `0` to `29`.
If you have not added any groups, this value is always `0`.

Where `group-name`is the relevant group's display name, URL encoded if needed, up to 61 bytes.
If you have not added any groups, this value is always `~`.

Where `0` is always `0`.

## In SYN

### First generation
*Applies for [MSNP7](../versions/msnp7.md).*

Same as the response [outside of SYN](#outside-of-syn).

### Second generation
*Applies for [MSNP8](../versions/msnp8.md) and [MSNP9](../versions/msnp9.md).*

`LSG group-id group-name 0`

### Third generation
*Since [MSNP10](../versions/msnp10.md).*

`LSG group-name [ group-id | group-guid ]`

Where `group-id` is the group's identification number.
If `ABCHMigrated: 1` is set in the initial profile,
it is instead `group-guid`, which is the group's GUID.

# Examples

## Client-initiated

### No groups created
*NOTE: Specifiying this as the LSG in [SYN](syn.md) will cause the client to attempt to re-initialize the default groups.
Please review the [SYN](syn.md) page for what the client attempts to do here.*
```msnp
C: LSG 1
S: LSG 1 255 1 1 0 ~ 0
```

### Have created groups
```msnp
C: LSG 2
S: LSG 2 255 1 2 0 Other%20Contacts 0
S: LSG 2 255 2 2 1 Friends 0
```

## From SYN
*Main article: [SYN](syn.md).*

### Using first generation
*Only in [MSNP7](../versions/msnp7.md).*
```msnp
C: SYN 3 0
S: SYN 3 4
```
...
```msnp
S: LSG 3 4 1 2 0 Other%20Contacts 0
S: LSG 3 4 2 2 1 Friends 0
```

### Using second generation
*Only in [MSNP8](../versions/msnp8.md) and [MSNP9](../versions/msnp9.md).*
```msnp
C: SYN 4 0
S: SYN 4 5
```
...
```msnp
S: LSG 0 Other%20Contacts 0
S: LSG 1 Friends 0
```

### Using third generation, with IDs
*Only in [MSNP10](../versions/msnp10.md) with `ABCHMigrated: 0`.*
```msnp
C: SYN 5 0 0
S: SYN 5 6 0 1 2
```
...
```msnp
S: LSG Other%20Contacts 0
S: LSG Friends 1
```

### Using third generation, with GUIDs
*Since [MSNP10](../versions/msnp10.md) with `ABCHMigrated: 1`.*
```msnp
C: SYN 6 0 0
S: SYN 6 2024-10-17T11:46:35.1100000-07:00 2024-10-17T11:46:35.1100000-07:00 1 2
```
...
```msnp
S: LSG Other%20Contacts d6deeacd-7849-4de4-93c5-d130915d0042
S: LSG Friends f60efbe7-94af-4b16-b926-e4e10878d329
```

# Known changes
* [MSNP8](../versions/msnp8.md): Removed iterator and List Version parameters from [SYN](syn.md) version.
* [MSNP10](../versions/msnp10.md): Removed unused `0` parameter and support for the `~` quasi-group.
  Changed group IDs to group GUIDs if `ABCHMigrated: 1`.
* [MSNP13](../versions/msnp13.md): Removed [SYN](syn.md).
  Use the [Address Book Service](../services/abservice.md)'s
  [`ABFindAll`](../services/abservice/abfindall.md) action instead.
* Hard-removed in November 2003, Removed outside of [SYN](syn.md), now just automatically disconnects.
