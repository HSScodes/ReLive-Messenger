# Introduction

`SSO` (Single Sign On) is the authentication scheme used from MSNP15 onward. Like its predecessor [TWN](twn.md), it authenticates
using a Passport Compact Token. However, authentication tickets have been replaced with policy challenges.
Additionally, the token domain has been changed.

# Procedure

## Initial USR Exchange

The client sends the initial USR request, and the notification server provides a policy (usually `MBI_KEY_OLD`) and a base64 nonce:

```msnp
C: USR TrID SSO I {user-handle}
S: USR TrID SSO S {policy} {nonce}
```

## Passport Authentication

The client now authenticates with passport and completes the policy challenge using the provided nonce. This process is documented at [Passport SOAP (RST)](../services/rst.md).

The token must be requested for `messengerclear.live.com`.

Note that SSO no longer supports Passport SSI 1.4 due to the use of policy challenges.

## Subsequent USR Exchange

The client completes the authentication flow by sending the Passport Compact Token and the completed policy challenge to the notification server:

```msnp
C: USR TrID SSO S {compact-token} {challenge}
S: USR TrID OK (...)
```