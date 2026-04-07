# Introduction
`CVQ` is a command introduced with [CVR0](../versions/cvr0.md).

It is a Dispatch Server command, without either a request or response payload.

Sends the current client information and retrieves the latest available version of the client when there are no other available protocols.  
For the version of this command that is sent in the main protocols, read [CVR](cvr.md).

# Client/Request
`CVQ TrID locale system-type system-ver system-arch requesting-library client-version {client-identification} {user-handle}`

Where `locale` is a 16-bit hexadecimally encoded LCID. `0x0409` is the LCID for English, United States.

Where `system-type` is a string that defines the operating system you are using, such as `winnt`.

Where `system-ver` is the major and minor version of the operating system, such as `5.1`.

Where `system-arch` is the architecture of the processor that is used to run the client, usually `i386`.

Where `requesting-library` is the name of the library that requested this CVQ, usually `MSMSGS` or `MSNMSGR`.

Where `client-version` is the current client's major, minor and patch version, should be in the format of "{M}M.m.pppp".

Where `client-identification` is the internal name of the codebase used to create `requesting-library`, usually `MSMSGS`, or an empty parameter.
Added since [MSNP4](../versions/msnp4.md), but is empty until [MSNP8](../versions/msnp8.md).

Where `user-handle` is the user's handle. Added since [MSNP8](../versions/msnp8.md).

# Server/Response
`CVQ TrID recommended-version recommended-version-2 minimum-allowed-version download-url fallback-url`

Where `recommended-version` is the current version of the client for this system.

Where `recommended-version-2` is (usually) the same as `recommended-version`,
Could possibly be a maximum allowed version? (forced downgrade)

Where `minimum-allowed-version` is the lowest version the server considers "safe" to connect with.  
If the client's `client-version` is lower than the server's `minimum-allowed-version`,
the client should automatically disconnect from the server,
and request an forced upgrade using the binary provided in `download-url`.

Where `download-url` is the file to download and open to update this client to `recommended-version`.

Where `fallback-url` is the URL the client opens if it failed to download `download-url` for any reason.

# Examples
*NOTE: This has been line-broken.
Lines beginning with `..` followed by a space are continuations of the previous line.*

## Old
*Only used in the [CVR0](../versions/cvr0.md) implementation of [MSNP2](../versions/msnp2.md) to [MSNP7](../versions/msnp2.md).*
```msnp
C: CVQ 1 0x0409 win 4.10 i386 MSMSGS 1.0.0863 MSMSGS
S: CVQ 1 5.0.0537 5.0.0537 1.0.0863
.. http://download.microsoft.com/download/msnmessenger/install/5.0/w98nt42kmexp/en-us/setupdl.exe
.. http://messenger.microsoft.com
```
Client disconnects from server, since it sees that `minimum-allowed` is above it's `client-version`.

## New
*Since [CVR0](../versions/cvr0.md) in [MSNP8](../versions/msnp8.md).*
```msnp
C: CVQ 2 0x0409 winnt 5.1 i386 MSNMSGR 6.0.0602 MSMSGS example@hotmail.com
S: CVQ 2 7.0.0813 7.0.0813 6.2.0205
.. http://msgr.dlservice.microsoft.com/download/5/d/9/5d9bb5b2-49c7-4890-94ab-d1d5e44a0e6d/Install_MSN_Messenger.exe
.. http://messenger.msn.com
```
Client disconnects from server, since it sees that `minimum-allowed` is above it's `client-version`.

## Invalid client identification or version
*This response may or may not disconnect you.*
```msnp
C: CVQ 3 0x0409 winnt 5.0 i386 MSNMSGR 99.9.9999 MSMSGS
S: 420 3
C: CVQ 4 0x0409 winnt 5.0 i386 YCOMM 0.1.0023 MSMSGS
S: 420 4
```

## Invalid language ID
```msnp
C: CVQ 5 0x1111 winnt 5.1 MSNMSGR 6.0.0602 MSMSGS example@hotmail.com
S: 710 5
```

## Invalid parameters
```msnp
C: CVQ 6 spaghetti
S: 731 6
```
Server disconnects client.

# Known changes
* [MSNP2](../versions/msnp2.md): Added a fallback URL parameter to the response (parameter 5).  
  In [CVR0](../versions/cvr0.md) Only: Changed [CVR](cvr.md) to [CVQ](cvq.md) carrying the previous change. 
* [MSNP4](../versions/msnp4.md): Added a client codebase identification parameter (parameter 7), which is always empty.
* [MSNP8](../versions/msnp8.md): Fixed client codebase identification parameter (parameter 7), is now filled correctly and added a current user parameter (parameter 8).
