# Introduction
`PAG` is a command introduced with [MSNP5](../versions/msnp5.md).

It is a Notification Server command, WITH a request payload.

It sends a text message to a mobile device.  
For the version of this command that supports Web Watches, read [PGD](pgd.md).  
For the command that is sent when you receive a page, read [IPG](ipg.md).

# Client/Request
```
PAG TrID user-handle length
payload
```

Where `user-handle` is the target user for this page.

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

## Sending without a callback number
```msnp
C: PAG 1 anotheruser@hotmail.com 61
<TEXT xml:space="preserve">This is an example message.</TEXT>
```

## Sending with a home callback number
*NOTE: The number used was `1 (555) 111-4444`.*
```msnp
C: PAG 2 anotheruser@hotmail.com 149
<PHONE pri="1"><LOC>HOME</LOC><NUM>15551114444</NUM></PHONE><TEXT xml:space="preserve">This is an example message with a home callback number.</TEXT>
```
## Sending with a work callback number
*NOTE: The number used was `1 (555) 222-5555`.*
```msnp
C: PAG 3 anotheruser@hotmail.com 149
<PHONE pri="1"><LOC>WORK</LOC><NUM>15552225555</NUM></PHONE><TEXT xml:space="preserve">This is an example message with a work callback number.</TEXT>
```

## Sending with a mobile callback number
*NOTE: The number used was `1 (555) 333-6666`.*
```msnp
C: PAG 4 anotheruser@hotmail.com 153
<PHONE pri="1"><LOC>MOBILE</LOC><NUM>15553336666</NUM></PHONE><TEXT xml:space="preserve">This is an example message with a mobile callback number.</TEXT>
```

## Failed to send
*This error may be a generic server error.*
```msnp
C: PAG 5 anotheruser@hotmail.com 61
<TEXT xml:space="preserve">This is an example message.</TEXT>
S: 800 5
```

## Command removed
*Since [MSNP9](../versions/msnp9.md).*
```msnp
C: PAG 6 anotheruser@hotmail.com 61
<TEXT xml:space="preserve">This is an example message.</TEXT>
S: 715 6
```

# Known changes
* [MSNP9](../versions/msnp9.md): Removed (error 715), use [PGD](pgd.md) instead.
