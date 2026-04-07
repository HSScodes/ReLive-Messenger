# Introduction
`SBP` is a command introduced with [MSNP10](../versions/msnp10.md).

It is a Notification Server command, without a request or response payload.

Sets a buddy's property in your cache to a specified value.
For the command this replaced, read [REA](rea.md).

# Client/Request
`SBP TrID contact-id property value {unknown}`

Where `contact-id` is the `C=` value from either [ADD](add.md) or [LST](lst.md).
If you are using `ABCHMigrated: 0`, this is the contact's user handle.
If you are instead using `ABCHMigrated: 1`, this is the contact's GUID.

Where `property` are any of the values:
* `MFN`: My Friendly Name
* `MOB`: User can contact me via MSN Mobile, changed by the Client Capability.
* `WWE`: User can contact me via MSN Direct, changed by the Client Capability.
* `PHM`: [MSNP11](../versions/msnp11.md)+: The user's mobile phone number.
* `HSB`: [MSNP11](../versions/msnp11.md)+: Has blog, changed by the Client Capability.

Where `value` is the URL-encoded value to set the related `property` to.

Where `unknown` is set to `1` if setting the `property` of `PHM`. Added since [MSNP11](../versions/msnp11.md)
(TODO: What does this mean?)

# Server/Response
`SBP TrID contact-id property value`

Same parameters as the request.

# Examples

## Without GUIDs
*Only with `ABCHMigrated: 0`.*

### My friendly name
```msnp
C: SBP 1 anotheruser@hotmail.com MFN another%20user
S: SBP 1 anotheruser@hotmail.com MFN anoter%20user
```

## With GUIDs
*Only with `ABCHMigrated: 1`.*

### My friendly name
```msnp
C: SBP 2 c1f9a363-4ee9-4a33-a434-b056a4c55b98 MFN another%20user
S: SBP 2 c1f9a363-4ee9-4a33-a434-b056a4c55b98 MFN another%20user
```

### Contact mobile number
*Since [MSNP11](../versions/msnp11.md).*  
*TODO: Is this correct? Needs mobile stuff enabled in [MsgrConfig](../services/msgrconfig.md).*
```msnp
C: SBP 3 c1f9a363-4ee9-4a33-a434-b056a4c55b98 PHM tel:+15554444333 1
S: SBP 3 c1f9a363-4ee9-4a33-a434-b056a4c55b98 PHM tel:+15554444333 1
```

## Errors
None are currently known. If you know of one, please contact me.

## Command removed
*Since [MSNP13](../versions/msnp13.md).*
```msnp
C: SBP 4 c1f9a363-4ee9-4a33-a434-b056a4c55b98 MFN another%20user
```
Server disconnects client.

# Known changes
* [MSNP11](../versions/msnp11.md): Added support for `HSB` property.
* [MSNP13](../versions/msnp13.md): Removed, use [Address Book Service](../services/abservice.md)'s `ABContactUpdate` action instead.
