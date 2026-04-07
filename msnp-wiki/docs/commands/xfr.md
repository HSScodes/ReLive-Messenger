# Introduction
`XFR` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Dispatch Server and Notification Server command, without either a request or response payload.

It tells the client what server to connect to for the request.

# Client/Request
`XFR TrID server-type`

Where `server-type` is either `SB` (for a Switchboard Server), or `NS` (for a new Notification Server).

# Server/Response
`XFR TrID server-type address:port {...}`

Where `server-type` is either `SB` (for Switchboard), or `NS` (for a Notification Server).

Where `address:port` is the server you have requested or being referred to is.
If this is set to `0`, proceed to **ignore** the `server-type` parameter
and restart the login process on the current server from [VER](ver.md).

## XFR NS
`XFR TrID NS address:port {0|U} {current-server|D}`

In [MSNP3](../versions/msnp3.md) and above until [MSNP13](../versions/msnp13.md),
`0` is always set to `0`.

In [MSNP7](../versions/msnp7.md) and above until [MSNP13](../versions/msnp13.md),
`current-server` is the current server you are connected to.

In [MSNP13](../versions/msnp13.md) and higher,
the `0` is replaced with a constant `U`,
and the `current-server` is replaced with a constant `D`.

## XFR SB
`XFR TrID SB address:port authentication-method authentication-parameter {U} {domain} {direct-connect}`

Where `authentication-method` is always `CKI`.

Where `authentication-parameter` is the "cookie" you need to log in to Switchboard.

Where `U` is always set to `U`. Since [MSNP13](../versions/msnp13.md).  
No use documented.

Where `domain` is always set to `messenger.msn.com`. Since [MSNP13](../versions/msnp13.md).  
No use documented.

Where `direct-connect` is set to one of these two values, Since [MSNP14](../versions/msnp14.md):
* `0`: This `address:port` can only be accessed only via the HTTP Gateway.
* `1`: This `address:port` can be connected to via TCP as well as the HTTP Gateway.

# Examples

## Before rework
*Only in [MSNP2](../versions/msnp2.md) to [MSNP12](../versions/msnp12.md).*

### Client requests a new Switchboard session
```msnp
C: XFR 1 SB
S: XFR 1 SB 10.0.1.200:1865 CKI 123456789.123456789.123456789
```

### Client requests a new Notification server
*Only used as-is in Beta 2 as the first command sent to a Dispatch Server.*
```msnp
C: XFR 2 NS
S: XFR 2 NS 10.0.0.5:1863
```
Client disconnects from server.

Client opens a connection to `10.0.0.5:1863`.

### Client referred from Dispatch Server

#### Very Old
*Only in [MSNP2](../versions/msnp2.md).*
```msnp
C: USR 3 MD5 I example@hotmail.com
S: XFR 3 NS 10.0.0.5:1863
```
Client disconnects from server.

Client opens a connection to `10.0.0.5:1863`.

#### Classic
*Only in [MSNP3](../versions/msnp3.md) to [MSNP6](../versions/msnp6.md).*
```msnp
C: USR 4 MD5 I example@hotmail.com
S: XFR 4 NS 10.0.0.5:1863 0
```
Client disconnects from server.

Client opens a connection to `10.0.0.5:1863`.

#### Modern
*Only in [MSNP7](../versions/msnp7.md) to [MSNP12](../versions/msnp12.md).*
```msnp
C: USR 5 MD5 I example@hotmail.com
S: XFR 5 NS 10.0.0.5:1863 0 10.0.0.1:1863
```
Client disconnects from server.

Client opens a connection to `10.0.0.5:1863`.

## After rework
*Since [MSNP13](../versions/msnp13.md).*

### Client requests a new Switchboard session

#### Without direct connect parameter
*Only in [MSNP13](../versions/msnp13.md).*
```msnp
C: XFR 6 SB
S: XFR 6 SB 10.0.1.200:1865 CKI 123456789.123456789.123456789 U messenger.msn.com
```

#### With direct connect parameter
*Since [MSNP14](../versions/msnp14.md).*
```msnp
C: XFR 7 SB
S: XFR 7 SB 10.0.1.200:1865 CKI 123456789.123456789.123456789 U messenger.msn.com 1
```

### Client referred from Dispatch Server
```msnp
C: USR 8 TWN I example@hotmail.com
S: XFR 8 NS 10.0.0.5:1863 U D
```

## Forced soft reset
*Applies for any protocol version.*
```msnp
S: XFR 0 NS 0
C: VER 9 MSNP7 MSNP6 MSNP5 MSNP4
```

## You can not be hidden or semi-offline while requesting a new Switchboard session
*Applies for any protocol version.*
```msnp
C: XFR 10 SB
S: 913 10
```

# Known changes
* [MSNP3](../versions/msnp3.md): Added a new parameter that is always `0` to [XFR NS](#xfr-ns).
* [MSNP7](../versions/msnp7.md): Added a new parameter that is the current server you are communicating with to [XFR NS](#xfr-ns).
* [MSNP13](../versions/msnp13.md): Replaced `0` and the current server parameter with `U` and `D` respectively in [XFR NS](#xfr-ns),
  and also added two parameters to [XFR SB](#xfr-sb), one that is always `U`,
  and one that is a domain name, which is always `messenger.msn.com`.
* [MSNP14](../versions/msnp14.md): Added a new parameter that is either `0` or `1` to [XFR SB](#xfr-sb)
  to denote whenever the client should directly connect to the address, or use the HTTP Gateway to connect instead.
