# Introduction
`xxx` is a command introduced with [MSNPx](../versions/msnpx.md).

It is a Notification Server command, without either a request or response payload.

Description.

# Client/Request
`xxx TrID {...}`

# Server/Response
`xxx TrID {...}`

# Examples

## blah
```msnp
C: xxx 3
S: xxx 3
```

## bleh
```msnp
C: xxx 3
S: xxx 3
```

## bluh?
```msnp
C: xxx 3
S: xxx 3
```

## Invalid argument
*NOTE: This is an assumption. The actual error code here is unknown.
It may also lead to an Instant Disconnection.*  
*NOTE: There is no defined behavour for this command specifically.*
```msnp
C: xxx 4 something wrong to go here
S: 201
```
Server disconnects client.

# Known changes
* Removed in MSNP24.
