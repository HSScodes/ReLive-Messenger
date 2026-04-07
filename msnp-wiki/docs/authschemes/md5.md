# Introduction

`MD5` is the authentication scheme used from MSNP2 (except versions 1.0.0452 to 1.0.0893, which use [CTP](ctp.md)) to MSNP7. As the name implies, the password is sent to the authentication server hashed with MD5, along with a server-provided salt.

The fatal flaw with the MD5 scheme is that, for it to offer full connection security, it necessitates that the server store user passwords
in plain text (no hashing), which is very insecure by today's standards. For this reason, it is recommended that server implementations
use separate, generated app passwords for pre-MSNP8 authentication.

It is technically possible to mitigate the above issue by using a single, hardcoded salt for each user (or globally) and storing it hashed with MD5. 
However, this makes the connection vulnerable to replay attacks. In addition, MD5 is a very insecure hashing algorithm and is easy to break in the modern day.

# Procedure

The client sends the initial USR request, and the server supplies a salt:

```msnp
C: USR TrID MD5 I {user-handle}
S: USR TrID MD5 S {salt}
```

Where {user-handle} is the handle (email address) the client is authenticating with.

Where {salt} is an arbitrary salt.

The client then completes the authentication flow by prepending the salt to the password, hashing it with MD5, and sending the result to the server:

```msnp
C: USR TrID MD5 S {hashed-password}
S: USR TrID OK (...)
```

Where {hashed-password} is the user's password, hashed as described above (something like: `md5Hash(salt + password)`).