# Introduction
`PRP` is a command introduced with [MSNP5](../versions/msnp5.md).

It is a Notification Server command, without either a request or response payload.

It sets or gets (during [SYN](syn.md)) a personal user property. Other users are handled via [BPR](bpr.md).

# Client/Request
`PRP TrID property value`

Where `property` can be any of these values:
* `PHH`: Home Phone number. Has a maximum of 95 bytes.
* `PHW`: Work Phone number. Has a maximum of 95 bytes.
* `PHM`: Mobile Phone number. Has a maximum of 95 bytes.
* `MOB`: Allow users to contact me via MSN Mobile.
* `MFN`: [[MSNP10](../versions/msnp10.md)+] My Friendly Name, Has a maximum of 387 bytes.

The data of the `property` parameter cannot be longer than 3 bytes.

Where `value` is the URL-encoded value to set the related `property` to.

# Server/Response
`PRP TrID {list-version} property value`

Where `list-version` is the new List Version. Removed since [MSNP10](../versions/msnp10.md) in `ABCHMigrated: 1` mode.

The following `property` values are only set by the server:
* `MBE`: MSN Mobile enabled.
* `WWE`: [[MSNP9](../versions/msnp9.md)+] MSN Direct / Web Watch enabled.
* `HSB`: [[MSNP11](../versions/msnp11.md)+] Has Blog (MSN Space).

# Examples

## Setting PHH
```msnp
C: PRP 1 PHH 1%20(222)%203333
S: PRP 1 256 PHH 1%20(222)%203333
```

## Unknown property
```msnp
C: PRP 2 NEW very%20yes
S: 715 2
```

## Property key is too long
```msnp
C: PRP 3 NICE Y
```
Server disconnects client.

## Property value is too long
*NOTE: This has been line-broken.
Lines beginning with `..` followed by a space are continuations of the previous line.*
```msnp
C: PRP 4 PHM this%20is%20way%20too%20long%20of%20a
.. %20phone%20number%20not%20like%20it%20is%20one%20anyway...
```
Server disconnects client.

# Known changes
* [MSNP8](../versions/msnp8.md): During [SYN](syn.md), the current List Version is omitted.
* [MSNP10](../versions/msnp10.md): Added `MFN` property, "My Friendly Name",
  List Version removed from response in `ABCHMigrated: 1` mode.
