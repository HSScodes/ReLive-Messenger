# Introduction

`TWN` (Tweener) is the authentication scheme used from MSNP8 to MSNP14. Instead of sending the password directly over the notification session,
TWN clients authenticate by using a ticket supplied by the notification server to obtain a Passport Compact Token from a compatible HTTPS web service (see below).

# Procedure

## Initial USR Exchange
The client sends the initial USR request, and the server responds with an authentication ticket:

```msnp
C: USR TrID TWN I {user-handle}
S: USR TrID TWN S {ticket}
```
Where {user-handle} is the Passport ID (email address) the client is authenticating with.

Where {ticket} is the authentication ticket. This string is opaque to the client and does not have a guaranteed format, although the official servers supplied comma-separated `{key}={value}` tickets.

## Passport Authentication

Using the provided authentication ticket, the client should now authenticate with Passport to retreive a Passport Compact Token. This can be done via one of the following web services:

* [Passport SSI 1.4](../services/passport14.md) (Used in official clients from versions 5.0.0537 until 7.5.0160)
* [Passport SOAP (RST)](../services/rst.md) (Used in official clients from version 7.5.0160 onward)

The token must be requested for `messenger.msn.com`.

## Subsequent USR Exchange

The client completes the authentication flow by sending the Passport Compact Token to the notification server:

```msnp
C: USR TrID TWN S {compact-token}
S: USR TrID OK (...)
```