# Introduction
`JOI` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Switchboard Server command, without a response payload.

Notifies that a new user has joined the Switchboard session.

# Client/Request
This command can not be sent from the client.

# Server/Response
`JOI user-handle friendly-name {client-capabilities}`

Where `user-handle` is the joined user's handle.

Where `friendly-name` is the joined user's Friendly Name.

Where `client-capabilities` is the related user's Client Capabilities. Included since [MSNP12](../versions/msnp12.md).

# Examples

## Without Client Capabilities
```msnp
S: JOI anotheruser@hotmail.com another%20user
```

## With Client Capabilities
*Since [MSNP12](../versions/msnp12.md)*
```msnp
S: JOI anotheruser@hotmail.com another%20user 1342554172
```

## Invalid context
*Inherited from being an unimplemented command.*
```msnp
C: JOI 2
```
Server disconnects client.

# Known changes
* [MSNP12](../versions/msnp12.md): Added the Client Capabilities parameter (parameter 3).
