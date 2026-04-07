# Introduction
CVR0 is a subprotocol of the Mobile Status Notification Protocol.  
It was introduced officially in Client Version 1.0.0863, along with [MSNP2](msnp2.md).

It is used for requesting the latest client information in case no other protocols were supported.

# Command information
It introduces the commands:
* [CVQ](../commands/cvq.md)

*No commands were known to be removed in this version.*

# Known changes
(from Beta 2):
* Changed [CVR](../commands/cvr.md) to [CVQ](../commands/cvq.md).
* [CVQ](../commands/cvq.md): Added fallback URL to response (parameter 5).
* Since [MSNP4](msnp4.md): Added an empty parameter that is meant to be the
  client codebase identification parameter added in [CVR](../commands/cvr.md) (parameter 7).
* Since [MSNP8](msnp8.md): Fixed client codebase identification parameter (parameter 7)
  to be no longer always empty, and added current user handle to request (parameter 8).

# Client-server communication examples
*NOTE: This has been line-broken.
Lines beginning with `..` followed by a space are continuations of the previous line.*

## Older protocols
*Only in[MSNP2](msnp2.md) to [MSNP7](msnp7.md), example using Client Version 1.0.*
```msnp
C: VER 1 MSNP2 CVR0
S: VER 1 CVR0
C: CVQ 2 0x0409 win 4.10 i386 MSMSGS 1.0.0863
S: CVQ 2 5.0.0537 5.0.0537 1.0.0863
.. http://download.microsoft.com/download/msnmessenger/install/5.0/w98nt42kmexp/en-us/setupdl.exe
.. http://messenger.microsoft.com
```
Server disconnects client.

## Newer protocols
*Since [MSNP8](msnp8.md), example using Client Version 6.1.*
```msnp
C: VER 1 MSNP10 MSNP9 CVR0
S: VER 1 CVR0
C: CVQ 2 0x0409 winnt 5.1 i386 MSNMSGR 6.1.0211 MSMSGS example@hotmail.com
S: CVQ 2 7.0.0813 7.0.0813 6.2.0205
.. http://msgr.dlservice.microsoft.com/download/5/d/9/5d9bb5b2-49c7-4890-94ab-d1d5e44a0e6d/Install_MSN_Messenger.exe
.. http://messenger.msn.com
```
Server disconnects client.
