# Introduction
`ADC` is a command introduced with [MSNP10](../versions/msnp10.md).

It is a Notification Server command, without a request or response payload.

Adds a user to a list.
For the command that was replaced with this, read [ADD](add.md).  
For the command that replaced this command in [MSNP13](../versions/msnp13.md), read [ADL](adl.md).  
For the service that complements [ADL](adl.md), read about the [Address Book Service](../services/abservice.md).

# Client/Request

## Add to a list
`ADC TrID [ FL | AL | BL | RL ] N=user-handle {F=stored-friendly-name}`

Where `user-handle` is the target's user handle.

Where `stored-friendly-name` is the friendly name you'd like to store.
Only applies if the target list is the Forward List. It and the `F=` prefix are omitted otherwise.

## Add to a group
`ADC TrID FL C=contact-id group-id`

Where `contact-id` is the contact's ID associated with the user on your Forward List (FL).
If in `ABCHMigrated: 0`, this is the contact's user handle,
otherwise in `ABCHMigrated: 1`, it is the contact's GUID.

Where `group-id` is the identification number of the group you'd like to add the contact to.
If in `ABCHMigrated: 0`, this is the group's numeric ID,
otherwise in `ABCHMigrated: 1`, it is the group's GUID.


# Server/Response

## Successfully added to list
`ADC TrID [ FL | AL | BL | RL ] N=user-handle {F=stored-friendly-name} {C=contact-id}`

If this is an asynchronous use of this command, the Transaction ID (or `TrID`) will be set to `0`.

Where `contact-id` is the contact's ID associated with the user.
Only applies to users added to the Forward List.
If in `ABCHMigrated: 0`, this is the contact's user handle,
otherwise in `ABCHMigrated: 1`, it is the contact's GUID.

## Successfully added to group
`ADC TrID FL C=contact-id group-id`

Same parameters as [the request](#add-to-a-group).

# Examples

## Normal use

### Add to other lists
*Does not apply for the Forward List (FL).*

```msnp
C: ADC 1 AL N=anotheruser@hotmail.com
S: ADC 1 AL N=anotheruser@hotmail.com
```

### Add to the Forward List

#### Without GUIDs
*Only with `ABCHMigrated: 0`.*

```msnp
C: ADC 2 FL N=anotheruser@hotmail.com F=anotheruser@hotmail.com
S: ADC 2 FL N=anotheruser@hotmail.com F=anotheruser@hotmail.com C=anotheruser@hotmail.com
```

#### With GUIDs
*Only with `ABCHMigrated: 1`.*

```msnp
C: ADC 3 FL N=anotheruser@hotmail.com F=anotheruser@hotmail.com
S: ADC 3 FL N=anotheruser@hotmail.com F=anotheruser@hotmail.com C=c1f9a363-4ee9-4a33-a434-b056a4c55b98
```

#### A telephone number
*Since [MSNP11](../versions/msnp11.md) if `<MobileMessaging>`
is set correctly in the [Messenger Config](../services/msgrconfig.md).*
```msnp
C: ADC 4 FL N=tel:15551111222 F=john
S: ADC 4 FL N=tel:15551111222 F=john C=a47e39cf-312c-4100-94a6-f2b33adf5b68
```

### Add to a group
*Only applies to the Forward List (FL).*

#### Without GUIDs
*Only with `ABCHMigrated: 0`.*

```msnp
C: ADC 4 FL C=anotheruser@hotmail.com 1
S: ADC 4 FL C=anotheruser@hotmail.com 1
```

#### With GUIDs
*Only with `ABCHMigrated: 1`.*

```msnp
C: ADC 5 FL C=anotheruser@hotmail.com f60efbe7-94af-4b16-b926-e4e10878d329
S: ADC 5 FL C=anotheruser@hotmail.com f60efbe7-94af-4b16-b926-e4e10878d329
```

## Invalid user handle
```msnp
C: ADC 6 FL N=a@b F=a@b
S: 201 6
```

## Target user not found
```msnp
C: ADC 7 FL N=ghost@hotmail.com F=ghost@hotmail.com
S: 208 7
```

## Target list is full
```msnp
C: ADC 8 FL N=stuffed@hotmail.com F=stuffed@hotmail.com
S: 210 8
```

## User already in that list
```msnp
C: ADC 9 FL N=anotheruser@hotmail.com F=anotheruser@hotmail.com
S: 215 9
```

## User can not be in both lists
```msnp
C: ADC 10 BL N=anotheruser@hotmail.com
S: 219 10
```

## Group doesn't exist

### Without GUIDs
*Only with `ABCHMigrated: 0`.*
```msnp
C: ADC 11 FL C=anotheruser@hotmail.com 31
S: 224 11
```

### With GUIDs
*Only with `ABCHMigrated: 1`.*
```msnp
C: ADC 12 FL C=anotheruser@hotmail.com 00000000-0000-0000-0000-000000000000
S: 224 12
```

## You can not add to the Pending List
```msnp
C: ADC 13 PL N=anotheruser@hotmail.com
```
Server disconnects client.

## Command removed
*Since [MSNP13](../versions/msnp13.md).*
```msnp
C: ADC 14 FL N=anotheruser@hotmail.com F=anotheruser@hotmail.com
```
Server disconnects client.

## Asynchronous update
```msnp
S: ADC 0 RL N=anotheruser@hotmail.com F=another%20user
```

# Known changes
* [MSNP11](../versions/msnp11.md): Now supports phone-only (`tel:`) contacts.
  Requires the `MobileMessaging` element in the
  [Messenger Config](../services/msgrconfig.md) to be configured for the Official Client to use the feature.
* [MSNP13](../versions/msnp13.md): Removed, use [ADL](adl.md) and the
  [Address Book Service](../services/abservice.md)'s
  [`ABContactAdd`](../services/abservice/abcontactadd.md) action or the
  [Contact Sharing Service](../services/sharingservice.md)'s
  [`AddMember`](../services/sharingservice/addmember.md) action instead.
