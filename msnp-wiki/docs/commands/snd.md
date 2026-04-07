# Introduction
`SND` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Notification Server command, without either a request or response payload.

Sends a service invitation to an e-mail address or directory user.  
For the version of this command that supports friendly names that superseded this command, read [SDC](sdc.md).

# Client/Request
`SND TrID target-address {translation-lcid} {requesting-library} {client-identification}`

Where `target-address` is the E-mail address or index from the last [FND](fnd.md) response you'd like to invite to the service.

Where `translation-lcid` is the LCID of the translation you'd like the invitation to be in.
Added since [MSNP3](../versions/msnp3.md).

Where `requesting-library` is the name of the library that sent this SND, usually `MSMSGS` or `MSNMSGR`.
Added since [MSNP3](../versions/msnp3.md).

Where `client-identification` is the internal name of the codebase used to create `requesting-library`, usually `MSMSGS`.
Added since [MSNP4](../versions/msnp4.md).

# Server/Response
`SND TrID OK`

Where `OK` is always `OK`.

# Examples

## Normal use

### E-mail only
*Only in [MSNP2](../versions/msnp2.md).*
```msnp
C: SND 1 anotheruser@hotmail.com
S: SND 1 OK
```

### With language ID and client library name
*Only in [MSNP3](../versions/msnp3.md).*
```msnp
C: SND 2 anotheruser@hotmail.com 0x0409 MSMSGS
S: SND 2 OK
```
### With the client internal name
*Since [MSNP4](../versions/msnp4.md).*
```msnp
C: SND 3 anotheruser@hotmail.com 0x0409 MSMSGS MSMSGS
S: SND 3 OK
```

## From a directory search
```msnp
C: FND 4 fname=Another lname=User city=* state=* country=US
S: FND 4 1 2 fname=Another lname=User city=New%20York state=NY country=US
FND 4 2 2 fname=Another lname=User city=Stillwater state=OK country=US
C: SND 5 1 0x0409 MSMSGS MSMSGS
S: SND 5 OK
```

## Invalid parameters
```msnp
C: SND 6 anotheruser@hotmail.com 10
S: 503 6
```
Server disconnects client.

# Known changes
* [MSNP3](../versions/msnp3.md): Added translation support and requesting library parameters.
* [MSNP4](../versions/msnp4.md): Added client codebase parameter.
* [MSNP5](../versions/msnp5.md): Deprecated. Use [SDC](sdc.md) instead.
