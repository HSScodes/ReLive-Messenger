# Introduction
`USR` is a command introduced with [MSNP2](../versions/msnp2.md).

The command exists in all services, without a request or response payload.

Specifies a user that wants to authenticate to the service.
For the command that is used when sending this to a Dispatch Server, read [XFR](xfr.md).

This command can only be sent once.
Any further uses of this command in the same session is Undefined Behaviour.

# Client/Request

## Dispatch Server or Notification Server

### The Initial request
`USR TrID security-package I user-handle`

`security-package` defines the authentication scheme, which varies depending on client and protocol version:
* [CTP](../authschemes/ctp.md): Clear Text Password. Only in [MSNP2](../versions/msnp2.md).
* [MD5](../authschemes/md5.md): MD5-based authentication. Only in [MSNP2](../versions/msnp2.md) to [MSNP7](../versions/msnp7.md).
* [TWN](../authschemes/twn.md): "Tweener", Passport Compact Token based authentication. Since [MSNP8](../versions/msnp8.md).
* [SSO](../authschemes/sso.md): Single Sign On, like TWN but using policy challenges instead of authentication tickets. Since [MSNP15](../versions/msnp15.md).

### The Subsequent request
`USR TrID security-package S {...response-args}`

Where `response-args` can be anything, but based on `security-package` it can be:
* [CTP](../authschemes/ctp.md): Your password in plain text.
* [MD5](../authschemes/md5.md): The server's login challenge concatenated with your password.
* [TWN](../authschemes/twn.md): A Passport Compact Token. For [Passport SSI 1.4](../services/passport14.md), this is the `from-PP` parameter in the `Authentication-Info` header. 
  For [Passport SOAP (RST)](../services/rst.md), this is the `<wsse:BinarySecurityToken>` of the relevant `<wst:RequestSecurityTokenResponse>`.
* [SSO](../authschemes/sso.md): The same as the arguments used for `TWN`, but with the extra parameter being the custom challenge response encoded as base64.

## Switchboard Server
`USR TrID user-handle cookie`

Where `user-handle` is your current user handle.

Where `cookie` is the relevant parameter given from [XFR](xfr.md) or [RNG](rng.md).

# Server/Response

## Dispatch Server or Notification Server

### Requesting a Subsequent action
`USR TrID OK security-package S {...challenge}`

Where `challenge`, based on the `security-package` is:
* `CTP`: Nothing. This parameter is omitted.
* `MD5`: The login challenge to concatenate with your password.
* `TWN`: The Passport login parameters.
* `SSO`: The Passport login policy and a base64-encoded key.

### Successfully authenticated
`USR TrID OK user-handle {friendly-name} {verified} {account-restricted}`

Where `OK` is always `OK`.

Where `user-handle` is your user handle.

Where `friendly-name` is your current Friendly Name. Removed in [MSNP10](../versions/msnp10.md).

Where `verified` is the account's verification status,
where 0 is unverified, and 1 is verified. Added since [MSNP6](../versions/msnp6.md).

Where `account-restricted` is the account's restricted status,
where 0 is unrestricted, and 1 is restricted. Added since [MSNP8](../versions/msnp8.md).
If this is set, the Client may log out automatically and ask to use MSN Explorer.

## Switchboard Server
`USR TrID OK user-handle friendly-name`

Where `user-handle` is your current user handle.

Where `friendly-name` is your current friendly name.

# Examples

## Notification Server

### Using CTP
*Only in [MSNP2](../versions/msnp2.md).*
```msnp
C: USR 1 CTP I example@hotmail.com
S: USR 1 CTP S
C: USR 2 CTP S password
S: USR 2 OK example@hotmail.com example%20user
```

### Using MD5
*Only in [MSNP2](../versions/msnp2.md) to [MSNP7](../versions/msnp7.md).*
```msnp
C: USR 3 MD5 I example@hotmail.com
S: USR 3 MD5 S 1234567890.123456789
C: USR 4 MD5 S f59af8f2fa91d38aff7c870c17f99903
S: USR 4 OK example@hotmail.com example%20user 1
```

### Using TWN
*Since [MSNP8](../versions/msnp8.md).*
```msnp
C: USR 5 TWN I example@hotmail.com
S: USR 5 TWN S passport=parameters,neat=huh,lc=1033,id=507
```
*The HTTPS interlude has been moved to the [Passport SSI 1.4](../services/passport14.md) article.*
```msnp
C: USR 6 TWN S t=token&p=profile
S: USR 6 OK example@hotmail.com example%20user 1 0
```

### Using SSO
*Since [MSNP15](../versions/msnp15.md).*

*NOTE: This has been line-broken.
Lines beginning with `..` followed by a space are continuations of the previous line.*
```msnp
C: USR 7 SSO I example@hotmail.com
S: USR 7 SSO S MBI_KEY_OLD AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
```

*The HTTPS interlude has been moved to the
[Passport SOAP (RST)](../services/rst.md) article.*

*The key-encryption interlude has been removed from here and is to reinstated as another article.*

*An implementation of the response generation is provided as `SolveSSOChallenge`
in [`msnp_challenges.cs`](../files/msnp_challenges.cs.md).*

```msnp
C: USR 8 SSO S t=ticket&p=HAAAAAEAAAADZgAABIAAAAgAAAAUAAAASAAAA
.. AAAAAAAAAAA7XgT5ohvaZdoXdrWUUcMF2G8OK2JohyYcK5l5MJSitab33scx
.. JeK/RQXcUr0L+R2ZA9CEAzn0izmUzSMp2LZdxSbHtnuxCmptgtoScHp9E26H
.. jQVkA9YJxgK/HM=
S: USR 8 OK example@hotmail.com
```

### Invalid authentication method
```msnp
C: USR 9 BAD I example@hotmail.com
```
Server disconnects client.

### Invalid username or password
```msnp
C: USR 10 TWN I example@hotmail.com
S: USR 10 TWN S passport=parameters,neat=huh,lc=1033,id=507
C: USR 11 TWN S t=not*a*passport*ticket&p=not*a*profile*either
S: 911 11
```
Server disconnects client.

### Child account not authorized
*Since [MSNP4](../versions/msnp4.md).*
```msnp
C: USR 12 MD5 I example@hotmail.com
S: USR 12 MD5 S 1234567890.123456789
C: USR 13 MD5 S f59af8f2fa91d38aff7c870c17f99903
S: 923 13
```
Server disconnects client.

### Account not verified

#### Hard block
*Since [MSNP5](../versions/msnp5.md).*

*NOTE: This will show the Account Verification dialog.*
```msnp
C: USR 14 MD5 I example@hotmail.com
S: USR 14 MD5 S 1234567890.123456789
C: USR 15 MD5 S f59af8f2fa91d38aff7c870c17f99903
S: 924 15
```
Server disconnects client.

#### Soft warning
*Since [MSNP6](../versions/msnp6.md).*
```msnp
C: USR 16 MD5 I example@hotmail.com
S: USR 16 MD5 S 1234567890.123456789
C: USR 17 MD5 S f59af8f2fa91d38aff7c870c17f99903
S: USR 17 OK example@hotmail.com example%20user 0
```

### Account restricted
*Since [MSNP8](../versions/msnp8.md).*

*NOTE: This will automatically log you out and force you to use MSN Explorer instead.*
```msnp
C: USR 18 TWN I example@hotmail.com
S: USR 19 TWN S passport=parameters,neat=huh,lc=1033,id=507
C: USR 19 TWN S t=token&p=profile
S: USR 19 OK example@hotmail.com example%20user 1 1
```
Client disconnects from server.

### Wrong server for this account
```msnp
C: USR 20 TWN I example@hotmail.com
S: 931 20
```
Server disconnects client.

## Switchboard Server
```msnp
C: USR 21 example@passport.com 1234567890.1234567890.1234567890
S: USR 21 OK example@passport.com example%20user
```

# Known changes
* [MSNP3](../versions/msnp3.md): Removed the `CTP` security package.
* [MSNP6](../versions/msnp6.md): Added account verification bit to [USR OK](#successfully-authenticated).
* [MSNP8](../versions/msnp8.md): Added account restriction bit to [USR OK](#successfully-authenticated) and
  removed the `MD5` security package, and replaced with the `TWN` security package.
* [MSNP15](../versions/msnp15.md): Added support for the `SSO` security package.
