# Introduction
`CAL` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Switchboard Server command, without either a request or response payload.

It invites ("calls") a user to a Switchboard session.

# Client/Request
`CAL TrID user-handle`

Where `user-handle` is the user that you'd like to invite.

# Server/Response
`CAL TrID RINGING session-id`

Where `RINGING` is always `RINGING`, as there are no other states available.

Where `session-id` is the Switchboard session identification number.

# Examples

## Inviting a user successfully
```msnp
C: CAL 1 anotheruser@hotmail.com
S: CAL 1 RINGING 987654321
```

## User already invited
```msnp
C: CAL 2 anotheruser@hotmail.com
S: 215 2
```

## User to invite was invalid
```msnp
C: CAL 3 hello
S: 208 3
```

## User is not accepting Instant Messages at this time
```msnp
C: CAL 4 anotheruser@hotmail.com
S: 217 4
```

## That user does not allow you to contact them
*All instances that returned this have been changed to a 217.
This response is obsolete and should **NOT** be sent.*
```msnp
C: CAL 5 anotheruser@hotmail.com
S: 216 5
```

## You are being rate limited
```msnp
C: CAL 6 anotheruser@hotmail.com
S: 217 6
C: CAL 7 anotheruser@hotmail.com
S: 217 7
C: CAL 8 anotheruser@hotmail.com
S: 217 8
C: CAL 9 anotheruser@hotmail.com
S: 217 9
C: CAL 10 anotheruser@hotmail.com
S: 217 10
C: CAL 11 anotheruser@hotmail.com
S: 713 11
```

## Invalid context (Notification Server)
*Inherited from being an unimplemented command.*
```msnp
C: CAL 12 anotheruser@hotmail.com
```
Server disconnects client.

# Known changes
None.
