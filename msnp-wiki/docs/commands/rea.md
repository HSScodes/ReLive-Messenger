# Introduction
`REA` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Notification Server command, without either a request or response payload.

Renames a user.  
For the commands that replaced REA with a `MFN` property, read [PRP](prp.md) and [SBP](sbp.md).

# Client/Request
`REA TrID user-handle new-friendly-name`

Where `user-handle` is the user handle that you'd like to change the friendly name of.  
If this is the current user's handle, the change will be announced via
[NLN](nln.md) to all users on your Reverse List (RL) if they are not in your Block List (BL).

Where `new-friendly-name` is the friendly name you'd like to set,
which may be rejected for any reason by the server.

# Server/Response
`REA TrID list-version user-handle new-friendly-name`

Where `list-version` is the new List Version.

# Examples

## Changing my friendly name
```msnp
C: REA 1 example@hotmail.com new%20name
S: REA 1 256 example@hotmail.com new%20name
```

## Changing a stored friendly name
```msnp
S: NLN NLN anotheruser@hotmail.com different%20name
C: REA 2 anotheruser@hotmail.com different%20name
S: REA 2 257 anotheruser@hotmail.com different%20name
```

## You are not allowed to have that name
```msnp
C: REA 3 example@hotmail.com bad
S: 209 3
```

## You can not change the friendly name of a user that is not on any of your Lists
```msnp
C: REA 4 ghost@hotmail.com ghost
S: 216 4
```

## You have been rate limited, try again later
```msnp
C: REA 5 example@hotmail.com new%20name%201
S: REA 5 258 example@hotmail.com new%20name%201
C: REA 6 example@hotmail.com new%20name%202
S: REA 6 259 example@hotmail.com new%20name%202
C: REA 7 example@hotmail.com new%20name%203
S: REA 7 260 example@hotmail.com new%20name%203
C: REA 8 example@hotmail.com new%20name%204
S: REA 8 261 example@hotmail.com new%20name%204
C: REA 9 example@hotmail.com new%20name%205
S: REA 9 262 example@hotmail.com new%20name%205
C: REA 10 example@hotmail.com new%20name%206
S: 800 10
```

# Known changes
* [MSNP10](../versions/msnp10.md): Removed (automatic disconnection?).
  Use [PRP](prp.md) `MFN` to change your own friendly name, and [SBP](sbp.md) `MFN` to change stored friendly names.
