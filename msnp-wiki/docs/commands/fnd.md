# Introduction
`FND` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Notification Server command, without either a request or response payload.

Searches for other users on the Network Directory.

# Client/Request
`FND TrID fname=first lname=last city=city state=ST country=CC`

Where `first` is the URL-encoded string representation of the first name to search users for.

Where `last` is the URL-encoded string representation of the last name to search users for.

Where `city` is the URL-encoded string representation of the city to search users in (`*` is allowed, and required for countries (`CC` parameter) outside of `US`.).

Where `ST` is a 2-character string representation of the state to search users in (`*` is allowed, and required for countries (`CC` parameter) outside of `US`.).

Where `CC` is a 2-character string representation of the country to search users in (`*` is allowed).

# Server/Response
`FND TrID 1 1 fname=Example lname=Name city=Somewhere state=OK country=US`

This command, despite having an iterator, can not span across multiple packets.
Instead, error 301 is returned in cases where the result would be too large to respond as one packet.

# Examples

## Valid, with users
```msnp
C: FND 1 fname=Another lname=User city=* state=* country=US
S: FND 1 1 2 fname=Another lname=User city=New%20York state=NY country=US
FND 1 2 2 fname=Another lname=User city=Stillwater state=OK country=US
```

## Valid, no users
```msnp
C: FND 2 fname=Another lname=User city=* state=* country=DE
S: FND 2 0 0
```

## Invalid parameter
```msnp
C: FND 3 fname=Another lname=* city=* state=* country=*
S: 201 3
```

## Too many users
```msnp
C: FND 4 fname=Another lname=User city=* state=* country=*
S: 301 4
```

## Command removed
```msnp
C: FND 5 fname=Another lname=User city=* state=* country=US
S: 502 5
```

# Known changes
* [MSNP5](../versions/msnp5.md): Changed related [SND](snd.md) command to [SDC](sdc.md).
* Soft-removed in April 2003, uses error 502, which was added in [MSNP7](../versions/msnp7.md).
