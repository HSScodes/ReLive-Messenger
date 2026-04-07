# Introduction
Passport SSI 1.4, or "Tweener", as it's sometimes called,
is an HTTP-based authentication system that was introduced with [MSNP8](../versions/msnp8.md).

The official protocol specification for Passport SSI 1.4 is available [here](https://winprotocoldoc.z19.web.core.windows.net/MS-PASS/%5bMS-PASS%5d.pdf). The relevant parts are documented here in terms of how Messenger behaves.

Clients from version 7.5.0160 and up use the [Passport SOAP (RST) service](rst.md) instead.  
For [MSNP18](../versions/msnp18.md) and above, read the Request Security Token service, version 2 article.

# Nexus
The Passport Nexus is a server that provides information to other parties about how to use Passport.

It's default domain is `nexus.passport.com`.

## pprdr.asp
The Passport Redirection service returns the `PassportURLs` header, which contains the `DALogin` parameter
that is used to specify which server to attempt Passport 1.4 authentication with.

### Client/Request
```http
GET /rdr/pprdr.asp HTTP/1.1
Host: nexus.passport.com

```

### Server/Response
```http
HTTP/1.1 200 OK
Cache-Control: private
Content-Type: text/html
Content-Length: 0
PassportURLs: DARealm=Passport.Net,DALogin=login.passport.com/login2.srf,ConfigVersion=15

```

Where `PassportURLs` (case-**sensitive**) contains the following parameters:
* `DARealm`: The Domain Authority's realm name.
* `DALogin`: The Domain Authority's login endpoint without the scheme prefix.
* `ConfigVersion`: Increases by 1 every time that PassportURLs is updated to flush the URL cache.

# Passport Login
The Passport Login server is a HTTPS server that provides the login service (default is `login2.srf`)
specified in `DALogin` from the [Nexus](#nexus) response.

## login2.srf
The `login2.srf` endpoint is used for programmatic authentication.

### Client/Request
```http
GET /login2.srf HTTP/1.1
Authorization: Passport1.4 OrgVerb=GET,OrgURL=http%3A%2F%2Fmessenger%2Emsn%2Ecom,sign-in={user-handle},pwd={password},{server-args}
User-Agent: MSMSGS
Host: login.passport.com
Connection: Keep-Alive
Cache-Control: no-cache

```

Where `user-handle` is the URL-encoded user handle of the user to authenticate.

Where `password` is the URL-encoded password of the user to authenticate.

Where `server-args` is the parameter given to the server's response to the initial [USR](../commands/usr.md).

### Server/Response

#### Authentication Redirection
If the server you are authenticating to does not support your account type,
but knows a server that does, this is used, otherwise [Authentication Successful](#authentication-successful) is.

If you are redirected, you have to send the `Authorization` header again to the new server specified in `Location`.

```http
HTTP/1.1 302 Found
Cache-Control: no-cache
cachecontrol: no-store
Connection: close
Authentication-Info: Passport1.4 da-status=redir
Location: https://loginnet.passport.com/login2.srf?lc=1033

```

#### Authentication Successful
The `from-PP` field contains a Passport Compact Token valid for `messenger.msn.com` that can be used for [TWN](../authschemes/twn.md) authentication.

Despite the RFC specifying that any status code can be used with this endpoint, Messenger will break if the status code and content type are not `200 OK` and `text/html` respectively.

```http
HTTP/1.1 200 OK
Cache-Control: no-cache
cachecontrol: no-store
Connection: close
Content-Type: text/html
Authentication-Info: Passport1.4 dastatus=success,tname=MSPAuth,tname=MSPProf,tname=MSPSec,from-PP='t=token&p=profile',ru=http://messenger.msn.com
Content-Length: 0

```

#### Authentication Failure
The `dastatus` may instead be `failed-noretry`.
```http
HTTP/1.1 401 Unauthorized
Cache-Control: no-cache
cachecontrol: no-store
WWW-Authenticate: Passport1.4 dastatus=failed,srealm=Passport.NET,ts=-1,prompt,cburl=http://www.passportimages.com/XPPassportLogo.gif
Content-Type: text/html
Content-Length: 154

<HTML><HEAD><META HTTP-EQUIV="REFRESH" CONTENT="0; URL=https://login.passport.com/pp25/login2.srf?f=11"><script>function OnBack(){}</script></HEAD></HTML>
```
