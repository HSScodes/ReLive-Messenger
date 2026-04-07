# Introduction
`SDC` is a command introduced with [MSNP5](../versions/msnp5.md).

It is a Notification Server command, WITH a request payload and without a response payload.

Sends a service invitation to an e-mail address or directory user.  
For the version of this command that does not support friendly names, read [SND](snd.md).

# Client/Request
```
SDC TrID target-address translation-lcid requesting-library client-identification X X my-friendly-name length
payload
```

Where `target-address` is the E-mail address or index from the last [FND](fnd.md) response you'd like to invite to the service.

Where `translation-lcid` is the LCID of the translation you'd like the invitation to be in.

Where `requesting-library` is the name of the library that sent this SDC, usually `MSMSGS` or `MSNMSGR`.

Where `client-identification` is the internal name of the codebase used to create `requesting-library`, usually `MSMSGS`.

Where both `X` parameters are always `X`.

Where `my-friendly-name` is your current friendly name.  
Invalid escaped characters are forcefully re-encoded to `%3DXX`,
where `XX` is original escaped character code.

Where `length` is the size (in bytes) of the `payload`.  
Set to `0` if you don't want to add anything else to your invitation.

Where `payload` is plain-text data that is included in the invitation.  
If the `length` is `0`, the `payload` is not to be set.

# Server/Response
`SDC TrID OK`

Where `OK` is always `OK`.

# Examples

## Normal use without extra data
```msnp
C: SDC 1 anotheruser@hotmail.com 0x0409 MSMSGS MSMSGS X X example%20name 0
S: SDC 1 OK
```

## Normal use with extra data
```msnp
C: SDC 2 anotheruser@hotmail.com 0x0409 MSMSGS MSMSGS X X example%20name 37
This will be added to the invitation.
S: SDC 2 OK
```

## From a directory search without extra data
```msnp
C: FND 3 fname=Another lname=User city=* state=* country=US
S: FND 3 1 2 fname=Another lname=User city=New%20York state=NY country=US
FND 3 2 2 fname=Another lname=User city=Stillwater state=OK country=US
C: SDC 4 1 0x0409 MSMSGS MSMSGS X X example%20name 0
S: SDC 4 OK
```

## From a directory search with extra data
```msnp
C: FND 5 fname=Another lname=User city=* state=* country=US
S: FND 5 1 2 fname=Another lname=User city=New%20York state=NY country=US
FND 5 2 2 fname=Another lname=User city=Stillwater state=OK country=US
C: SDC 6 1 0x0409 MSMSGS MSMSGS X X example%20name 54
Hello! I met you the other day and would like to chat.
S: SDC 6 OK
```

## Invalid parameters
```msnp
C: SDC 7 anotheruser@hotmail.com 10
S: 503 7
```
Server disconnects client.

# Known changes
None.
