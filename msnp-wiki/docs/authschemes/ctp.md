# Introduction

`CTP` (Cleartext Password) an authentication scheme used in very early versions (1.0.0452 to 1.0.0893) of messenger. Is is only supported in MSNP2

CTP offers very little security, with the password being sent unobfuscated and unencrypted to the notification server, so it's understandable why it was ditched so quickly.

# Procedure

```msnp
C: USR TrID CTP I {user-handle}
S: USR TrID CTP S
C: USR TrID CTP S {password}
S: USR TrID OK (...)
```

Where {user-handle} is the handle (email address) the client is authenticating with.

Where {password} is the user's account password.