# Introduction
`IRO` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Switchboard Server command, without a response payload.

Used to specify what users in are in the Switchboard session after a [ANS](ans.md) request.

# Client/Request
This command can not be sent from the client.

# Server/Response
`IRO TrID index total-participants participant-handle participant-friendly-name {client-capabilities}`

Where `index` is the current indice of the list.

Where `total-participants` is the length of the list.

Where `participant-handle` is the related user's handle.

Where `participant-friendly-name` is the related user's Friendly Name.

Where `client-capabilities` is the related user's Client Capabilities, included since [MSNP12](../versions/msnp12.md).

# Examples

## Without Client Capabilities
```msnp
C: ANS 1 example@hotmail.com 123456789.123456789.123456789 987654321
S: IRO 1 1 1 anotheruser@hotmail.com another%20user
S: ANS 1 OK
```

## With Client Capabilities
*Since [MSNP12](../versions/msnp12.md).*
```msnp
C: ANS 2 example@hotmail.com 123456789.123456789.123456789 987654321
S: IRO 2 1 1 anotheruser@hotmail.com another%20user 1342554172
S: ANS 2 OK
```

## Invalid context
*Inherited from being an unimplemented command.*
```msnp
C: IRO 3
```
Server disconnects client.

# Known changes
* [MSNP12](../versions/msnp12.md): Added the Client Capabilities parameter (parameter 5).
