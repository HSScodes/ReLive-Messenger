# Introduction
`URL` is a command introduced with [MSNP2](../versions/msnp2.md).

It is a Notification Server command, without a request or response payload.

It retrieves a service URL to open.

# Client/Request
`URL TrID service {param}`

Where `service` is the specified service you'd like to get the URL of:
* `PASSWORD`: Change password
* `INBOX`: Hotmail inbox
* `COMPOSE`: Compose an E-mail
* `MESSAGE`: Likely unused
* `FOLDERS`: MSN home?
* `PERSON`: Modify account details
* `MOBILE`: Setup MSN Mobile
* `CHGMOB`: Edit mobile settings
* `PROFILE`: Edit MSN Member Directory profile
* `N2PACCOUNT`: Net2Phone account management
* `N2PFUND`: Net2Phone payment managmenet
* `CHAT`: Chat rooms
* `ADDRBOOK`: Address Book, unused?
* `ADVSEARCH`: Advanced Search, unused?
* `INTSEARCH`: Interest Search, unused?

Where `param` is an optional parameter to specify extra data about the request:
* `CHAT`: Supports a LCID parameter for localization. Example: `0x0409`.
* `PROFILE`: Supports a LCID parameter for localization. Example: `0x0409`.
* `N2PACCOUNT`: Supports a LCID parameter for localization. Example: `0x0409`.
* `COMPOSE`: Supports a target address. Example: `example@hotmail.com`.

# Server/Response
`URL TrID redirect-url login-url {psid}`

Where `redirect-url` is either a relative URL to `login-url`, using the `rru` form parameter,
or an absolute URL to redirect to, using the `ru` form parameter. Absolute URLs are supported since [MSNP3](../versions/msnp3.md).

Where `login-url` is the service that provides automatic authentication
and accepts redirection form parameters. Usually `https://login(net).passport.com/ppsecure/md5auth.srf?lc=`
followed by your initial profile's `lang_preference` value since [MSNP3](../versions/msnp3.md).

Where `psid` is the `id` parameter passed to `login-url`. and are required to use absolute URLs as the `redirect-url`.
Added since [MSNP3](../versions/msnp3.md). Required since [MSNP5](../versions/msnp5.md).

# Examples
*NOTE: All examples will have Site IDs because I don't know what the login URL was without it.*

## Open E-mail Inbox
```msnp
C: URL 1 INBOX
S: URL 1 /cgi-bin/HoTMaiL https://loginnet.passport.com/ppsecure/md5auth.srf?lc=1033 2
```

## Compose new E-mail

### Without target
```msnp
C: URL 2 COMPOSE
S: URL 2 /cgi-bin/compose https://loginnet.passport.com/ppsecure/md5auth.srf?lc=1033 2
```

### With target
```msnp
C: URL 3 COMPOSE anotheruser@hotmail.com
S: URL 3 /cgi/bin/compose?mailto=1&to=anotheruser%40hotmail%2ecom https://loginnet.passport.com/ppsecure/md5auth.srf?lc=1033 2
```

## Setup MSN Mobile
*Since [MSNP5](../versions/msnp3.md).*
```msnp
C: URL 4 MOBILE
S: URL 4 http://mobile.msn.com/hotmail/confirmUser.asp?URL=%2Fmessengerok.htm&mobID=1 https://loginnet.passport.com/ppsecure/md5auth.srf?lc=1033 961
```

## Edit Member Directory profile
*Since [MSNP6](../versions/msnp3.md).*
```msnp
C: URL 5 PROFILE 0x0409
S: URL 5 http://members.msn.com/Edit.asp?lc=1033 https://loginnet.passport.com/ppsecure/md5auth.srf?lc=1033 4263
```

## Manage Net2Phone account
*Since [MSNP6](../versions/msnp6.md).*
```msnp
C: URL 6 N2PACCOUNT 0x0409
S: URL 6 https://ocs.net2phone.com/account/msnaccount/default.asp?_lang=0x0409 https://loginnet.passport.com/ppsecure/md5auth.srf?lc1033 2823
```

## Open chat rooms
*Since [MSNP7](../versions/msnp7.md).*
```msnp
C: URL 7 CHAT 0x0409
S: URL 7 http://chat.msn.com/Messenger.msnw?lc=1033 https://loginnet.passport.com/ppsecure/md5auth.srf?lc=1033 2260
```

# Known changes
* [MSNP3](../versions/msnp3.md): Added a Passport Site ID parameter to response (parameter 3),
  now supports absolute URLs instead of only relative URLs for the redirect URL.
* Client Version 3.0 ([MSNP5](../versions/msnp5.md)): Made the Passport Site ID parameter mandatory,
* [MSNP5](../versions/msnp5.md): Added `MOBILE` and `CHGMOB` services.
* [MSNP6](../versions/msnp6.md): Added `PROFILE`, `N2PACCOUNT` and `N2PFUND` services.
* [MSNP7](../versions/msnp7.md): Added `CHAT` service.
* [MSNP8](../versions/msnp8.md): Added `ADDRBOOK`, `ADVSEARCH` and `INTSEARCH` services.
