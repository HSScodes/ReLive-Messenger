# Introduction
`PGD` is a command introduced with [MSNP9](../versions/msnp9.md).

It is a Notification Server command, WITH a request payload.

It sends a text message to a mobile device/pager or Web Watch.  
For the version of this command that doesn't support Web watches, read [PAG](pag.md).  
For the command that is sent when you receive a page, read [IPG](ipg.md).

# Client/Request
```
PGD TrID user-handle device-type length
payload
```

Where `user-handle` is the target user for this page.

Where `device-type` is a number:
* 1: Mobile Device
* 2: Web Watch

Where `length` is the size (in bytes) of the `payload`.

Where `payload` is a XML-like payload that encodes the following characters:
* `&` turns into `&#x26;`
* `;` turns into `&#x3B;`
* `<` turns into `&#x3C;`
* `>` turns into `&#x3E;`
* `^` turns into `&#x5E;`

# Server/Response
This command only supports negative-acknowledgement responses only.
There is no postive acknowledgement response.

# Examples

## Sending to a mobile device

### Sending without a callback number
```msnp
C: PGD 1 anotheruser@hotmail.com 1 74
<TEXT xml:space="preserve" enc="utf-8">This is an example message.</TEXT>
```

### Sending with a home callback number
*NOTE: The number used was `1 (555) 111-4444`.*
```msnp
C: PGD 2 anotheruser@hotmail.com 1 161
<PHONE pri="1"><LOC>HOME</LOC><NUM>15551114444</NUM></PHONE><TEXT xml:space="preserve" enc="utf-8">This is an example message with a home callback number.</TEXT>
```
### Sending with a work callback number
*NOTE: The number used was `1 (555) 222-5555`.*
```msnp
C: PGD 3 anotheruser@hotmail.com 1 161
<PHONE pri="1"><LOC>WORK</LOC><NUM>15552225555</NUM></PHONE><TEXT xml:space="preserve" enc="utf-8">This is an example message with a work callback number.</TEXT>
```

### Sending with a mobile callback number
*NOTE: The number used was `1 (555) 333-6666`.*
```msnp
C: PGD 4 anotheruser@hotmail.com 1 165
<PHONE pri="1"><LOC>MOBILE</LOC><NUM>15553336666</NUM></PHONE><TEXT xml:space="preserve" enc="utf-8">This is an example message with a mobile callback number.</TEXT>
```

### Failed to send
*This error may be a generic server error.*
```msnp
C: PGD 5 anotheruser@hotmail.com 1 74
<TEXT xml:space="preserve" enc="utf-8">This is an example message.</TEXT>
S: 800 5
```

## To a Web Watch
*NOTE: Trying to do this with the buddy property
`MOB` set to `Y` is impossible in the official client.*

### Normal use
```msnp
C: PGD 6 anotheruser@hotmail.com 2 74
<TEXT xml:space="preserve" enc="utf-8">This is an example message.</TEXT>
```

### Failed to send
*This error may be a generic server error.*
```msnp
C: PGD 7 anotheruser@hotmail.com 2 74
<TEXT xml:space="preserve" enc="utf-8">This is an example message.</TEXT>
S: 800 7
```

## To an invalid device type

### Numeric types
```msnp
C: PGD 8 anotheruser@hotmail.com 0 74
<TEXT xml:space="preserve" enc="utf-8">This is an example message.</TEXT>
S: 201 8
```

### Other character types
```msnp
C: PGD 9 anotheruser@hotmail.com W 74
<TEXT xml:space="preserve" enc="utf-8">This is an example message.</TEXT>
```
Server disconnects client.

# Known changes
None.
