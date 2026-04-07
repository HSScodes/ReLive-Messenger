# Introduction
`SYN` is a command introduced with [MSNP2](../versions/msnp2.md)

It is a Notification Server command, without a request or response payload.

Synchronizes user options and every contact list.

This command can only be sent once.
Any further uses of this command in the same session is Undefined Behaviour.

# Client/Request
`SYN TrID list-version {settings-version}`

Where `list-version` is the last saved List Version this client remembers.
If the client doesn't remember any information, this is `0`.
With [MSNP10](../versions/msnp10.md) and `ABCHMigrated: 1`,
this is changed from a numerical value to a timestamp.

Where `settings-version` is the last saved Settings Version this client remembers.
If the client doesn't remember any settings, this is set to `0`.
Added since [MSNP10](../versions/msnp10.md).
With `ABCHMigrated: 1`, this is changed from a numerical value to a timestamp.

# Server/Response
`SYN TrID list-version {settings-version} {amount-of-users} {amount-of-groups}`

Where `list-version` is either the current or new List Version, depending if the client's
version of this parameter is the same as the one the server has.
With [MSNP10](../versions/msnp10.md) and `ABCHMigrated: 1`,
this is changed from a numerical value to a timestamp.

Where `settings-version` is either the current or new Settings Version,
depending if the client's version of this parameter is the same as the one the server has.
Added since [MSNP10](../versions/msnp10.md).
With `ABCHMigrated: 1`, this is changed from a numerical value to a timetstamp.

Where `amount-of-users` is the amount of unique [LST](lst.md) responses
your client is going to have to expect. Added since [MSNP8](../versions/msnp8.md).

Where `amount-of-groups` is the amount of [LSG](lsg.md) responses
your client is going to have to expect. Adec since [MSNP8](../versions/msnp8.md).

# Examples

## First generation
*Only in [MSNP2](../versions/msnp2.md) to [MSNP4](../versions/msnp4.md).*

Used commands:
* [GTC](gtc.md)
* [BLP](blp.md)
* [LST](lst.md)

```msnp
C: SYN 1 0
S: SYN 1 255
S: GTC 1 255 A
S: BLP 1 255 AL
S: LST 1 FL 255 1 1 anotheruser@hotmail.com another%20user
S: LST 1 AL 255 1 1 anotheruser@hotmail.com another%20user
S: LST 1 BL 255 0 0
S: LST 1 RL 255 1 1 anotheruser@hotmail.com another%20user
```

## Second generation
*Only in [MSNP5](../versions/msnp5.md) and [MSNP6](../versions/msnp6.md).*

Used commands:
* [GTC](gtc.md)
* [BLP](blp.md)
* [PRP](prp.md)
* [LST](lst.md)
* [BPR](bpr.md)

```msnp
C: SYN 2 0
S: SYN 2 255
S: GTC 2 255 A
S: BLP 2 255 AL
S: PRP 2 255 PHH 123%20(4567)
S: PRP 2 255 PHW
S: PRP 2 255 PHM
S: PRP 2 255 MOB N
S: PRP 2 255 MBE N
S: LST 2 FL 255 1 1 anotheruser@hotmail.com another%20user
S: BPR 255 anotheruser@hotmail.com PHH 1%20(222)%20333%204444
S: BPR 255 anotheruser@hotmail.com PHW
S: BPR 255 anotheruser@hotmail.com PHM
S: BPR 255 anotheruser@hotmail.com MOB N
S: LST 2 AL 255 1 1 anotheruser@hotmail.com another%20user
S: LST 2 BL 255 0 0
S: LST 2 RL 255 1 1 anotheruser@hotmail.com another%20user
```

## Third generation
*Only in [MSNP7](../versions/msnp7.md).*

Used commands:
* [GTC](gtc.md)
* [BLP](blp.md)
* [PRP](prp.md)
* [LSG](lsg.md)
* [LST](lst.md)
* [BPR](bpr.md)

```msnp
C: SYN 3 0
S: SYN 3 255
S: GTC 3 255 A
S: BLP 3 255 AL
S: PRP 3 255 PHH 123%20(4567)
S: PRP 3 255 PHW
S: PRP 3 255 PHM
S: PRP 3 255 MOB N
S: PRP 3 255 MBE N
S: LSG 3 255 1 2 0 Other%20Contacts 0
S: LSG 3 255 2 2 1 Friends 0
S: LST 3 FL 255 1 1 anotheruser@hotmail.com another%20user 0
S: BPR 255 anotheruser@hotmail.com PHH 1%20(222)%20333%204444
S: BPR 255 anotheruser@hotmail.com PHW
S: BPR 255 anotheruser@hotmail.com PHM
S: BPR 255 anotheruser@hotmail.com MOB N
S: LST 3 AL 255 1 1 anotheruser@hotmail.com another%20user
S: LST 3 BL 255 0 0
S: LST 3 RL 255 1 1 anotheruser@hotmail.com another%20user
```

### No groups specified
*This only happens if the only group is `~`,
and you set the client to sort by groups.*

Used commands:
* [REG](reg.md)
* [ADG](adg.md)

```msnp
S: LSG 3 255 1 1 0 ~ 0
```
...
```msnp
C: REG 4 0 Other%20Contacts 0
S: REG 4 256 0 Other%20Contacts 0
C: ADG 5 Coworkers 0
C: ADG 6 Friends 0
C: ADG 7 Family 0
S: ADG 5 257 1 Coworkers 0
S: ADG 6 258 2 Friends 0
S: ADG 7 259 3 Family 0
```

## Fourth generation
*Only in [MSNP8](../versions/msnp8.md) and [MSNP9](../versions/msnp9.md).*

Used commands:
* [GTC](gtc.md)
* [BLP](blp.md)
* [PRP](prp.md)
* [LSG](lsg.md)
* [LST](lst.md)
* [BPR](bpr.md)

```msnp
C: SYN 8 0
S: SYN 8 255 1 2
S: GTC A
S: BLP AL
S: PRP PHH 123%20(4567)
S: LSG 0 Other%20Contacts 0
S: LSG 1 Friends 0
S: LST anotheruser@hotmail.com another%20user 11 0
S: BPR PHH 1%20(222)%20333%204444
```

### No groups specified
*This only happens if the only group is `~`,
and you set the client to sort by groups.*

Used commands:
* [REG](reg.md)
* [ADG](adg.md)

```msnp
S: LSG 0 ~ 0
```
...
```msnp
C: REG 9 0 Other%20Contacts 0
S: REG 9 256 0 Other%20Contacts 0
C: ADG 10 Coworkers 0
C: ADG 11 Friends 0
C: ADG 12 Family 0
S: ADG 10 257 1 Coworkers 0
S: ADG 11 258 2 Friends 0
S: ADG 12 259 3 Family 0
```

## Fifth generation
*Only in [MSNP10](../versions/msnp10.md) and [MSNP11](../versions/msnp11.md).*

Used commands:
* [GTC](gtc.md)
* [BLP](blp.md)
* [PRP](prp.md)
* [LSG](lsg.md)
* [LST](lst.md)
* [BPR](bpr.md)

### Without GUIDs
*Only with `ABCHMigrated: 0`.*
```msnp
C: SYN 13 0 0
S: SYN 13 255 255 1 2
S: GTC A
S: BLP AL
S: PRP MFN example%20user
S: PRP PHH 123%20(4567)
S: LSG Other%20Contacts 0
S: LSG Friends 1
S: LST N=anotheruser@hotmail.com F=another%20user C=anotheruser@hotmail.com 11 0
S: BPR PHH 1%20(222)%20333%204444
```

### With GUIDs
*Only with `ABCHMigrated: 1`.*
```msnp
C: SYN 14 0 0
S: SYN 14 2024-10-23T14:02:48.5360000-07:00 2024-10-23T14:02:48.5360000-07:00 1 2
S: GTC A
S: BLP AL
S: PRP MFN example%20user
S: PRP PHH 123%20(4567)
S: LSG Other%20Contacts d6deeacd-7849-4de4-93c5-d130915d0042
S: LSG Friends f60efbe7-94af-4b16-b926-e4e10878d32
S: LST N=anotheruser@hotmail.com F=another%20user C=c1f9a363-4ee9-4a33-a434-b056a4c55b98 11 d6deeacd-7849-4de4-93c5-d130915d0042
S: BPR PHH 1%20(222)%20333%204444
```

## Sixth generation
*Only in [MSNP12](../versions/msnp12.md).*
```msnp
C: SYN 15 0 0
S: SYN 15 2024-10-23T14:06:20.5360000-07:00 2024-10-23T14:02:48.5360000-07:00 1 2
S: GTC A
S: BLP AL
S: PRP MFN example%20user
S: PRP PHH 123%20(4567)
S: LSG Other%20Contacts d6deeacd-7849-4de4-93c5-d130915d0042
S: LSG Friends f60efbe7-94af-4b16-b926-e4e10878d32
S: LST N=anotheruser@hotmail.com F=another%20user C=c1f9a363-4ee9-4a33-a434-b056a4c55b98 11 1 d6deeacd-7849-4de4-93c5-d130915d0042
S: BPR PHH 1%20(222)%20333%204444
```

## Command removed
*Since [MSNP13](../versions/msnp13.md).*
```msnp
C: SYN 16 0 0
```
Server disconnects client.

# Known changes
* [MSNP5](../versions/msnp5.md): Added [PRP](prp.md) and [BPR](bpr.md) support.
* [MSNP7](../versions/msnp7.md): Added [LSG](lsg.md) and groups support in [LST](lst.md).
* [MSNP8](../versions/msnp8.md): Unset properties are omitted,
  added new response parameters to replace [LSG](lsg.md) and [LST](lst.md) iterator parameters.
  Transaction IDs and List Versions were removed from used commands.
* [MSNP10](../versions/msnp10.md): Added new parameters for the current settings version.
  With `ABCHMigrated: 1`, the List Version and Settings Version are changed to ISO 8601 timestamps.
* [MSNP12](../versions/msnp12.md): [LST](lst.md): Added support for Network IDs.
* [MSNP13](../versions/msnp13.md): Removed (automatic disconnection).
  Use both the [Address Book Service](../services/abservice.md)'s
  [`ABFindAll`](../services/abservice/abfindall.md)
  and the [Contact Sharing Service](../services/sharingservice.md)'s
  [`FindMembership`](../services/sharingservice/findmembership.md) actions instead.
