# Introduction
`REM` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Notification Server command, without a request or response payload.

It removes a user from a list.

# Client/Request
`REM TrID [ FL | AL | BL | PL ] [ user-handle | contact-guid ] {group}`

The Pending List (PL) is only available since [MSNP10](../versions/msnp10.md).

Where `user-handle` is the user's handle to remove from the list.

If using [MSNP10](../versions/msnp10.md), if the list to remove from is the Forward List (FL),
`user-handle` is replaced with `contact-guid`, which is the contact's GUID.

If `group` is specified and the list is set to the Forward List (FL),
then the user is only removed from the specified group.
To remove a user from a list entirely, omit the `group` parameter.

# Server/Response
`REM TrID [ FL | AL | BL | RL | PL ] {list-version} {group}`

If this is an asynchronous use of this command, the Transaction ID (or `TrID`) will be set to `0`.

Where `list-version` is the new List Version. Removed since [MSNP10](../versions/msnp10.md).

# Examples

## With List Versions
*Only in [MSNP2](../versions/msnp2.md) to [MSNP9](../versions/msnp9.md).*

### Remove from any modifiable list using a user handle
```msnp
C: REM 1 AL anotheruser@hotmail.com
S: REM 1 AL 256 anotheruser@hotmail.com
C: REM 2 FL anotheruser@hotmail.com
S: REM 2 FL 257 anotheruser@hotmail.com
```

### Remove from group
*Since [MSNP7](../verisons/msnp7.md). NOTE: Only applies to FL.*
```msnp
C: REM 3 FL anotheruser@hotmail.com 1
S: REM 3 FL 258 anotheruser@hotmail.com 1
```

## Without List Versions
*Since [MSNP10](../versions/msnp10.md).*

### Remove from Forward List entirely using a GUID
*NOTE: Only applies to FL.*
```msnp
C: REM 4 FL c1f9a363-4ee9-4a33-a434-b056a4c55b98
S: REM 4 FL c1f9a363-4ee9-4a33-a434-b056a4c55b98
```

### Remove from other lists using a user handle
```msnp
C: REM 5 AL anotheruser@hotmail.com
S: REM 5 AL anotheruser@hotmail.com
```

### Remove from group using two GUIDs
*NOTE: Only applies to FL.*
```msnp
C: REM 6 FL c1f9a363-4ee9-4a33-a434-b056a4c55b98 d6deeacd-7849-4de4-93c5-d130915d0042
S: REM 6 FL c1f9a363-4ee9-4a33-a434-b056a4c55b98 d6deeacd-7849-4de4-93c5-d130915d0042
```

## User not in that list
```msnp
C: REM 7 BL ghost@hotmail.com
S: 216 7
```

## Group does not exist

### Before GUIDs
*Only in [MSNP7](../versions/msnp7.md) to [MSNP9](../versions/msnp9.md). NOTE: Only applies to FL.*
```msnp
C: REM 8 FL anotheruser@hotmail.com 32
S: 224 8
```

### After GUIDS
*Since [MSNP10](../versions/msnp10.md). NOTE: Only applies to FL.*
```msnp
C: REM 9 FL c1f9a363-4ee9-4a33-a434-b056a4c55b98 00000000-0000-0000-0000-000000000000
S: 224 9
```

## Group exists, but user is not in it

### Before GUIDs
*Only in [MSNP7](../versions/msnp7.md) to [MSNP9](../versions/msnp9.md). NOTE: Only applies to FL.*
```msnp
C: REM 10 FL anotheruser@hotmail.com 1
S: 225 10
```

### After GUIDS
*Since [MSNP10](../versions/msnp10.md). NOTE: Only applies to FL.*
```msnp
C: REM 11 FL c1f9a363-4ee9-4a33-a434-b056a4c55b98 f0a0df8f-22a4-452c-9e3c-6252420480e9
S: 225 11
```

## You can not remove from the Reverse List
```msnp
C: REM 12 RL anotheruser@hotmail.com
```
Server disconnects client.

## Command removed
*Since [MSNP13](../versions/msnp13.md).*
```msnp
C: REM 13 FL anotheruser@hotmail.com 
```
Server disconnects client.

## Asynchronous update

### With List Version parameter
*Only in [MSNP2](../versions/msnp2.md) to [MSNP9](../versions/msnp9.md).*
```msnp
S: REM 0 RL 259 anotheruser@hotmail.com
S: REM 0 FL 260 anotheruser@hotmail.com
```

### Without List Version parameter
*Since [MSNP10](../versions/msnp10.md).*
```msnp
S: REM 0 RL anotheruser@hotmail.com
S: REM 0 FL c1f9a363-4ee9-4a33-a434-b056a4c55b98
```

# Known changes
* [MSNP7](../versions/msnp7.md): Added groups support.
* [MSNP10](../versions/msnp10.md): Added GUID support, replacing the user's handle for FL requests
  and removed updating the List Version.
* [MSNP13](../versions/msnp13.md): Removed, use [RML](rml.md) and the
  [Address Book Service](../services/abservice.md)'s
  [`ABContactDelete`](../services/abservice/abcontactdelete.md) action or the
  [Contact Sharing Service](../services/sharingservice.md)'s
  [`DeleteMember`](../services/sharingservice/deletemember.md) action instead.
