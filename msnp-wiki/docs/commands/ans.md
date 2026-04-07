# Introduction
`ANS` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Switchboard Server command, without either a request or response payload.

Used to join ("answer") a Switchboard session ("call").  
The response of this command sent after the [IRO](iro.md) list has been sent,
or instantly if the [IRO](iro.md) list is empty.

# Client/Request
`ANS TrID my-handle{;machine-guid} cookie session-id`

Where `my-handle` is the current user's handle.

Where `machine-guid` is a bracketed Machine GUID. Added since [MSNP16](../versions/msnp16.md).

Where `cookie` is the `cookie` from the [RNG](rng.md) command sent to you.

Where `session-id` is the `session-id` from the [RNG](RNG) command sent to you.

# Server/Response
`ANS TrID OK`

Where `OK` is always `OK`.

# Examples

## Answering a RNG
*NOTE: This has been line-broken.
Lines beginning with .. followed by a space are continuations of the previous line.*
```msnp
S: RNG 987654331 10.0.1.200:1865 CKI 123456789.123456789.123456789
.. anotheruser@hotmail.com another%20user
C: ANS 1 example@hotmail.com 123456789.123456789.123456789 987654321
S: IRO 1 1 1 anotheruser@hotmail.com another%20user
S: ANS 1 OK
```

## Invalid session
*NOTE: There is no defined behaviour for this command specificially.*
```msnp
C: ANS 2 example@hotmail.com bad data
```
Server disconnects client.

## Invalid context (Notification Server)
*Inherited from being an unimplemented command.*
```msnp
C: ANS 3 example@hotmail.com wrong server
```
Server disconnects client.

# Known changes
* [MSNP16](../versions/msnp16.md): Added the current MPOP Machine ID to the `my-handle` parameter.
