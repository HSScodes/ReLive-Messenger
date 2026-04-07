# Introduction
`BPR` is a command introduced with [MSNP5](../versions/msnp5.md).

It is a Notification Server command, without a response payload.

It specifies another user's properties. For your own properties, use [PRP](prp.md).

# Client/Request
This command can not be sent from the client.

# Server/Response
`BPR {list-version} {user-handle} property value`

Where `list-version` is the new List Version. Removed since [MSNP10](../versions/msnp10.md) in `ABCHMigrated: 1` mode.

Where `user-handle` is the related user's handle. Removed in [SYN](syn.md) since [MSNP8](../versions/msnp8.md).

Where `property` can be any of these values:
* `PHH`: Home Phone number.
* `PHW`: Work Phone number.
* `PHM`: Mobile Phone number.
* `MOB`: Allow users to contact me via MSN Mobile.
* `WWE`: [[MSNP9](../versions/msnp9.md)+] MSN Direct / Web Watch enabled.
* `HSB`: [[MSNP11](../versions/msnp11.md)+] Has Blog (MSN Space).

Where `value` is the URL-encoded value that is assigned to `property`.

# Examples

## Receive new PHH from user
```msnp
S: BPR 256 anotheruser@hotmail.com PHH 1%20(444)%20222%203333
```

## Invalid context
*Inherited from being an unimplemented command.*
```msnp
C: BPR example@hotmail.com
```
Server disconnects client.

# Known changes
* [MSNP8](../versions/msnp8.md): Removed the user's handle when used in [SYN](syn.md).
* [MSNP10](../versions/msnp10.md): Removed the List Version in `ABCHMigrated: 1` mode.
