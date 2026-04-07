# Introduction
`ADD` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Notification Server command, without a request or response payload.

Adds a user to a list. Replaced by [ADC](adc.md) in [MSNP10](../versions/msnp10.md).

# Client/Request
`ADD TrID [ FL | AL | BL ] user-handle custom-friendly-name {group}`

Where `user-handle` is the relevant user's handle.

Where `custom-friendly-name` is the friendly name of this user you'd like to store in this list.

Where `group` is the group to add the user to.
Only applies for Forward List (FL). Since [MSNP7](../versions/msnp7.md).

# Server/Response
`ADD TrID [ FL | AL | BL | RL ] list-version user-handle custom-friendly-name {group}`

If this is an asynchronous use of this command, the Transaction ID (or `TrID`) will be set to `0`.

Where `list-version` is the new List Version.

# Examples

## Normal use

### Without groups
```msnp
C: ADD 1 FL anotheruser@hotmail.com anotheruser@hotmail.com
S: ADD 1 FL 256 anotheruser@hotmail.com anotheruser@hotmail.com
C: ADD 2 AL anotheruser@hotmail anotheruser@hotmail.com
S: ADD 2 AL 257 anotheruser@hotmail.com anotheruser@hotmail.com
```

### With groups
*Since [MSNP7](../versions/msnp7.md).*
```msnp
C: ADD 3 FL anotheruser@hotmail.com anotheruser@hotmail.com 0
S: ADD 3 FL 256 anotheruser@hotmail.com anotheruser@hotmail.com 0
C: ADD 4 AL anotheruser@hotmail anotheruser@hotmail.com
S: ADD 4 AL 257 anotheruser@hotmail.com anotheruser@hotmail.com
```

## Invalid handle
```msnp
C: ADD 5 FL a@b a@b
S: 201 5
```

## Account not found
```msnp
C: ADD 6 FL ghost@hotmail.com ghost@hotmail.com
S: 205 6
```

## Target list is full
```msnp
C: ADD 7 FL stuffed@hotmail.com stuffed@hotmail.com
S: 210 7
```

## User already in that list
```msnp
C: ADD 8 FL anotheruser@hotmail.com anotheruser@hotmail.com
S: 215 8
```

## User can not be in both lists
```msnp
C: ADD 9 BL anotheruser@hotmail.com anotheruser@hotmail.com
S: 219 9
```

## Group does not exist
*Since [MSNP7](../versions/msnp7.md).*
```msnp
C: ADD 10 FL anotheruser@hotmail.com anotheruser@hotmail.com 31
S: 224 10
```

## You can not add to the Reverse List
```msnp
C: ADD 11 RL anotheruser@hotmail.com anotheruser@hotmail.com
```
Server disconnects client.

## Command removed
*Since [MSNP10](../versions/msnp10.md).*
```msnp
C: ADD 12 FL anotheruser@hotmail.com anotheruser@hotmail.com
```
Server disconnects client.

## Asynchronous update
```msnp
S: ADD 0 RL 258 anotheruser@hotmail.com anotheruser@hotmail.com
```

# Known changes
* [MSNP7](../versions/msnp7.md): Now supports groups if target list is Forward List.
* [MSNP10](../versions/msnp10.md): Removed (automatic disconnect). Use [ADC](adc.md) instead.
