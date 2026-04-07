# Introduction
`MSG` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Notification and Switchboard Server command, WITH a request and WITH a response payload.

Used to transfer MIME-headered data to other parties, whenever that be you or other users.

# Client/Request
*This command can only be sent in a Switchboard session.*
```
MSG TrID [ U | N | A | D ] length
payload
```
## Acknowledgement Types
* U: Unacknowledged, no response is sent.
* A: Acknowledged, a [ACK](ack.md) response is sent if the message is sent successfully.
* N: Negative-Acknowledged, a [NAK](nak.md) response is sent if the messaged failed to send successfully.
* D: Data, a version of Acknowledged that also has a response of error 282 if the message was poorly formatted.

Acknowledgement Type `D` is defined since [MSNP9](../versions/msnp9.md).

Where `length` is the size (in bytes) of the `payload`.

Where `payload` is the body of the message,
usually containing a `MIME-Version` header and a `Content-Type`.

# Server/Response
```
MSG user-handle friendly-name length
payload
```

Where `user-handle` is either the senders's handle,
or `Hotmail`, if sent from the Notification Server itself.

Where `friendly-name` is either the URL-encoded Friendly Name of the sender,
or `Hotmail`, if sent from the Notification Server itself.

Where `length` is the size (in bytes) of the `payload`.

Where `payload` is the body of the message,
usually containing a `MIME-Version` header and a `Content-Type`.

# Examples

## Client initiated

### Unacknowledged message
```msnp
C: MSG 1 U 76
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8

unacknowledged
```

### Acknowledged message
```msnp
C: MSG A 2 74
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8

acknowledged
S: ACK 2
```

### Negative-Acknowledged message
```msnp
C: MSG 3 2 86
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8

negatively acknowledged?
S: NAK 3
```

### Data message
*Since [MSNP9](../versions/msnp9.md).*
```msnp
C: MSG 4 D 73
MIME-Version: 1.0
Content-Type: application/octet-stream

data message
S: ACK 4
```

### Poorly formatted data message
*Since [MSNP9](../versions/msnp9.md).*
```msnp
C: MSG 5 D 75
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8

data message?
S: 282 5
```

### Invalid context (Notification Server)
*Inherited from being an unimplemented command.*
```msnp
C: MSG 6 U 0
```
Server disconnects client.

## Server initiated

### Notification Server

#### Initial profile
*NOTE: This profile is from [MSNP2](../versions/msnp2.md), later versions have longer initial profiles.*
```msnp
S: MSG Hotmail Hotmail 95
MIME-Version: 1.0
Content-Type: text/x-msmsgsprofile; charset=UTF-8
LoginTime: 1726321960

```

#### Initial e-mail configuration
*NOTE: In [MSNP2](../versions/msnp2.md) only, the type of the initial e-mail configuration was
`application/x-msmsgsemailnotification`, which was changed in [MSNP3](../versions/msnp3.md) to
`text/x-msmsgsinitialemailnotification`.*
```msnp
S: MSG Hotmail Hotmail 221
MIME-Version: 1.0
Content-Type: text/x-msmsgsinitialemailnotification; charset=UTF-8

Inbox-Unread: 1
Folders-Unread: 0
Inbox-URL: /cgi-bin/HoTMaiL
Folders-URL: /cgi-bin/folders
Post-URL: http://www.hotmail.com

```

#### New e-mail
*NOTE: In [MSNP2](../versions/msnp2.md) only, the type of the e-mail notifications was
`application/x-msmsgsemailnotification`, which was changed in [MSNP3](../versions/msnp3.md) to
`text/x-msmsgsemailnotification`, and also added the `id` header for automatic Passport authentication,
and the `Post-URL` was also changed from `http://www.hotmail.com` to
either the passport `md5auth.srf` of your account server or provided by a Hotmail `law` server.*
```msnp
S: MSG Hotmail Hotmail 359
MIME-Version: 1.0
Content-Type: text/x-msmsgsemailnotification; charset=UTF-8

From: Example User
Message-URL: /cgi-bin/getmsg?msg=MSG1728932553.00&start=1&len=12&curmbox=ACTIVE
Post-URL: https://loginnet.passport.com/ppsecure/md5auth.srf?lc=1033
Subject: =?"us-ascii"?Q?Just saying hello.?=
Dest-Folder: ACTIVE
From-Addr: example@hotmail.com
id: 2

```

#### Mailbox activity
```msnp
S: MSG Hotmail Hotmail 146
MIME-Version: 1.0
Content-Type: text/x-msmsgsactivemailnotification; charset=UTF-8

Src-Folder: ACTIVE
Dest-Folder: ACTIVE
Message-Delta: 1

```

#### System message
*NOTE: There may be other types of system messages, `Type` 1 is for a server shutdown message,
`Arg1` in this case would be the minutes before the server is set to shutdown.*
```msnp
S: MSG Hotmail Hotmail 88
MIME-Version: 1.0
Content-Type: application/x-msmsgssystemmessage

Type: 1
Arg1: 5

```

### Switchboard Server
```msnp
S: MSG example@hotmail.com example%20user 73
MIME-Version: 1.0
Content-Type: text/plain;charset=UTF-8

acknowledged
```

# Known changes
* [MSNP3](../versions/msnp3.md): Switchboard: Added support for the `X-MMS-IM-Format` header.
* [MSNP9](../versions/msnp9.md): Switchboard: Added acknowledgement type D.
