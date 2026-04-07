# Introduction
`RNG` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Notification Server command, without a response payload.

Used to invite ("ring") you to a Switchboard session.

# Client/Request
This command can not be sent from the client.

# Server/Response
`RNG session-id address:port CKI cookie inviter-handle inviter-friendly-name {U} {domain} {direct-connect}`

Where `session-id` is the Switchboard session identification number you need in [ANS](ans.md).

Where `address:port` is the server you need to connect to join the conversation.

Where `CKI` is always `CKI`.

Where `cookie` is the Switchboard cookie, to be used in [USR](usr.md) and [ANS](ans.md).

Where `inviter-handle` is the inviter's handle.

Where `inviter-handle` is the inviter's friendly name.

Where `U` is always `U`. Since [MSNP13](../versions/msnp13.md).  
The use of this parameter is unknown.

Where `domain` is always `messenger.hotmail.com`. Since [MSNP13](../versions/msnp13.md).  
The use of this parameter is unknown.

Where `direct-connect` is set to one of these two values, Since [MSNP14](../versions/msnp14.md):
* `0`: This `address:port` can only be accessed only via the HTTP Gateway.
* `1`: This `address:port` can be connected to via TCP as well as the HTTP Gateway.

# Examples

## Getting a Switchboard invite
*NOTE: This has been line-broken.
Lines beginning with `..` followed by a space are continuations of the previous line.*

### Old
*Only in [MSNP2](../versions/msnp2.md) to [MSNP12](../versions/msnp12.md).*
```msnp
S: RNG 987654331 10.0.1.200:1865 CKI 123456789.123456789.123456789
.. anotheruser@hotmail.com another%20user
```

### New
*Only in [MSNP13](../versions/msnp13.md).*
```msnp
S: RNG 987654331 10.0.1.200:1865 CKI 123456789.123456789.123456789
.. anotheruser@hotmail.com another%20user U messenger.hotmail.com
```

### Modern
*Since [MSNP14](../versions/msnp14.md).*
```msnp
S: RNG 987654331 10.0.1.200:1865 CKI 123456789.123456789.123456789
.. anotheruser@hotmail.com another%20user U messenger.hotmail.com 1
```

## Invalid context
*Inherited from being an unimplemented command.*
```msnp
C: RNG 1
```
Server disconnects client.

# Known changes
* [MSNP13](../versions/msnp13.md): Added two new parameters,
  one of which is always `U`, and the other is always `messenger.hotmail.com`.
* [MSNP14](../versions/msnp14.md): Added a new parameter that is either `0` or `1`
  to denote whenever the client should directly connect to the address, or use the HTTP Gateway to connect instead. 
