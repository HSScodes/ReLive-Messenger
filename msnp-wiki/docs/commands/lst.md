# Introduction
`LST` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Notification Server command, without a request or response payload.

It retrieves all users in any of the available lists.

# Client/Request
`LST TrID [ FL | AL | BL | RL ]`

*NOTE: There is a possibility that PL can be retrieved this way too.*

# Server/Response

## Outside of SYN
`LST TrID [ FL | AL | BL | RL ] list-version index size-of-list user-handle stored-friendly-name {groups}`

Where `list-version` is the current List Version.

Where `index` is a number that can not go out of `size-of-list`. If the list is empty this is `0`.

Where `size-of-list` is the upper bounds for `index`. If the list is empty this is `0`.

Where `user-handle` is the related user's handle.
If the list is empty this parameter is not in the response.

Where `stored-friendly-name` is the friendly name stored for this contact on the server.
If the list is empty this parameter is not in the response.

Where `groups` is a comma-delimited list of Group IDs this contact is in,
only appended if the list (parameter 1) is set to FL. Defaults to `0`.
Added since [MSNP7](../versions/msnp7.md).

## In SYN

### First generation parameters
*Applies for [MSNP2](../versions/msnp2.md) to [MSNP6](../versions/msnp6.md).*

Same as the response [Outside of SYN](#outside-of-syn).

### Groups support
*Applies for [MSNP7](../versions/msnp7.md).*

`LST TrID [ FL | AL | BL | RL ] list-version index size-of-list user-handle stored-friendly-name {groups}`

Where `groups` is a comma-delimited list of Group IDs this contact is in,
only appended if the list (parameter 1) is set to FL. Defaults to `0`.

### Second generation parameters
*Applies for [MSNP8](../versions/msnp8.md) and [MSNP9](../versions/msnp9.md)*

`LST user-handle stored-friendly-name list-bits {groups}`

Where `list-bits` are in the format:
* 1: Forward List (FL)
* 2: Allow List (AL)
* 4: Block List (BL)
* 8: Reverse List (RL)

Where `groups` is a comma-delimited list of Group IDs this contact is in,
only appended if Forward List (FL) is set in `list-bits`. Defaults to `0`.

### Third generation parameters
*Applies for [MSNP10](../versions/msnp10.md) with `ABCHMigrated: 0`.*

`LST N=user-handle F=stored-friendly-name list-bits {groups}`

Same parameters as the [second generation](#second-generation).

### Fourth generation parameters
*Applies for [MSNP10](../versions/msnp10.md) and [MSNP11](../versions/msnp11.md) with `ABCHMigrated: 1`.*

`LST N=user-handle F=stored-friendly-name C=contact-guid list-bits {groupGuids}`

Where `contact-guid` is the GUID/UUID of the contact.

Where `groupGuids` is a comma-delimited list of Group GUIDs this contact is in,
only appending if Forward List (FL) is set in `list-bits`, defaults to whatever "Other Contacts"'s GUID is.

### Fifth generation parameters
*Applies for [MSNP12](../versions/msnp12.md).*

`LST N=user-handle F=stored-friendly-name C=contact-guid list-bits network-id {groupGuids}`

Where `network-id` is any Network ID bits:
* 1: Messenger
* 2: Office Communicator
* 4: Telephone
* 8: "MNI" or Mobile Network Interop, used for some mobile networks.
* 16: SMTP or Simple Mail Transfer Protocol, used for Japanese mobile networks.
* 32: Yahoo! Messenger network, only seen in [MSNP14](../versions/msnp14.md) and higher.

# Examples

## Client-initiated
```msnp
C: LST 1 FL
S: LST 1 FL 255 1 1 anotheruser@example.com another%20user
C: LST 2 BL
S: LST 2 BL 255 0 0
```

## From SYN

### From the beginning
*Only in [MSNP2](../versions/msnp2.md) to [MSNP6](../versions/msnp6.md).*
```msnp
C: SYN 3 0
S: SYN 3 4
```
...
```msnp
S: LST 3 FL 4 1 1 anotheruser@hotmail.com another%20user
S: LST 3 AL 4 1 1 anotheruser@hotmail.com another%20user
S: LST 3 BL 4 0 0
S: LST 3 RL 4 1 1 anotheruser@hotmail.com another%20user
```

### Using groups
*Only in [MSNP7](../versions/msnp7.md).*
```msnp
C: SYN 4 0
S: SYN 4 5
```
...
```msnp
S: LSG 4 5 1 1 0 Other%20Contacts 0
S: LST 4 FL 5 1 1 anotheruser@hotmail.com another%20user 0
S: LST 4 AL 5 1 1 anotheruser@hotmail.com another%20user
S: LST 4 BL 5 0 0
S: LST 4 RL 5 1 1 anotheruser@hotmail.com another%20user
```

### Using second generation parameters
*Only in [MSNP8](../versions/msnp8.md) and [MSNP9](../versions/msnp9.md).*
```msnp
C: SYN 5 0
S: SYN 5 6 1 1
```
...
```msnp
S: LSG 0 Other%20Contacts 0
S: LST anotheruser@hotmail.com another%20user 11 0
```

### Using third generation parameters
*Only in [MSNP10](../versions/msnp10.md) with `ABCHMigrated: 0`.*

```msnp
C: SYN 6 0 0
S: SYN 6 7 0 1 1
```
...
```msnp
S: LSG Other%20Contacts 0
S: LST N=anotheruser@hotmail.com F=another%20user C=anotheruser@hotmail.com 11 0
```

### Using fourth generation parameters
*Only in [MSNP10](../versions/msnp10.md) and [MSNP11](../versions/msnp11.md) with `ABCHMigrated: 1`.*
```msnp
C: SYN 7 0 0
S: SYN 7 2024-10-15T14:49:40.1100000-07:00 2024-10-15T14:49:40.1100000-07:00 1 1
```
...
```msnp
S: LSG Other%20Contacts d6deeacd-7849-4de4-93c5-d130915d0042
S: LST N=anotheruser@hotmail.com F=another%20user C=c1f9a363-4ee9-4a33-a434-b056a4c55b98 11 d6deeacd-7849-4de4-93c5-d130915d0042
```

### Using fifth generation parameters
*Only in [MSNP12](../versions/msnp12.md).*
```msnp
C: SYN 8 0 0
S: SYN 8 2024-10-15T15:01:30.1200000-07:00 2024-10-15T15:01:30.1200000-07:00 1 1
```
...
```msnp
S: LSG Other%20Contacts d6deeacd-7849-4de4-93c5-d130915d0042
S: LST N=anotheruser@hotmail.com F=another%20user C=c1f9a363-4ee9-4a33-a434-b056a4c55b98 11 1 d6deeacd-7849-4de4-93c5-d130915d0042
```

# Known changes
* [MSNP7](../versions/msnp7.md): Added support for groups.
* [MSNP8](../versions/msnp8.md): Changed format in [SYN](syn.md) considerably, dropping the iterator parameters and
  merging all lists into a single parameter instead of multiple calls.
* [MSNP10](../versions/msnp10.md): Added prefixes for user handle, stored friendly name to [SYN](syn.md) version, added `C=` for contact ID.
  Changed `C=` to contact GUID and changed group ID list to group GUID list with `ABCHMigrated: 1` to SYN version.
* [MSNP12](../versions/msnp12.md): Added Network IDs to [SYN](syn.md) version.
* [MSNP13](../versions/msnp13.md): Removed [SYN](syn.md).
  Use both the [Address Book Service](../services/abservice.md)'s
  [`ABFindAll`](../services/abservice/abfindall.md) and the
  [Contact Sharing Service](../services/sharingservice.md)'s
  [`FindMembership`](../services/sharingservice/findmembership.md) actions instead.
* Hard-removed in November 2003, Removed outside of [SYN](syn.md), now just automatically disconnects.
