# Introduction
`RML` is a command introduced with [MSNP13](../versions/msnp13.md).

It is a Notification Server command, WITH a request and WITH a response payload.

Removes a user from a list during a session.  
For the actions that removes a user from the address book or the membership lists,
read either the [`ABContactDelete`](../services/abservice/abcontactdelete.md) article
or the [`DeleteMember`](../services/sharingservice/deletemember.md) article respectively.

# Client/Request
```
RML TrID length
payload
```

Where `payload` is a [`<ml>`](#ml) document, without any support for whitespace outside of element parameters.

## ml
This element has one optional attribute:
* `l`: If this is the initial list, this is set to `1`.

This element optionally supports one or multiple `<d>` elements,
and optionally only one `<t>` element.

### d
This element has one attribute:
* `n`: The domain (`...@this`) of the user handle.

This element contains one or multiple `<c>` elements.

#### c
This element has three attributes:
* `n`: The local part (`this@...`) of the user handle.
* `l`: A bitfield that denotes what list this user is in:
	* `1` (bit 0): Forward List (FL).
	* `2` (bit 1): Allow List (AL).
	* `4` (bit 2): Block List (BL).
	* `8` (bit 3): Reverse List (RL). This value can only be set from the server.
	* `16` (bit 4): Pending List (PL). This value can only be set from the server.
* `t`: The Network ID that this user is associated with.

### t
This element contains one or multiple `<c>` elements.

#### c
This element has two attributes:
* `n`: The phone number as a `tel:` URI, with the `+` prefix.
* `l`: A bitfield that denotes what list this user is in:
	* `1` (bit 0): Forward List (FL).
	* `2` (bit 1): Allow List (AL).
	* `4` (bit 2): Block List (BL).
	* `8` (bit 3): Reverse List (RL). This value can only be set from the server.
	* `16` (bit 4): Pending List (PL). This value can only be set from the server.

# Server/Response

## As a response
`RML TrID OK`

No payload is attached in this scenario.

## Asynchronously
```
RML 0 length
payload
```

Where payload is a [`<ml>`](#ml) document, without any support for whitespace outside of element parameters.

# Examples
*NOTE: The XML in these examples has been exploded for visibility and formatting reasons.  
No whitespace is allowed in RML's payload and the payload size reflects this,
and is set to the correct value.*

## Normal use

### Remove a user handle
```msnp
C: RML 1 65
<ml>
	<d n="hotmail.com">
		<c n="anotheruser" l="1" t="1" />
	</d>
</ml>
S: RML 1 OK
```

### Remove a telephone number
```msnp
C: RML 2 48
<ml>
	<t>
		<c n="tel:+15551111222" l="1" />
	</t>
</ml>
S: RML 2 OK
```

## No services specified
```msnp
C: RML 3 9
<ml></ml>
S: 240 3
```

## No domain name specified
```msnp
C: RML 4 16
<ml>
	<d>
	</d>
</ml>
S: 241 4
```

## Out of bounds Network ID
```msnp
C: RML 5 67
<ml>
	<d n="hotmail.com">
		<c n="anotheruser" l="1" t="256" />
	</d>
</ml>
S: 204 5
```

## You cannot remove from the Reverse List or Pending List
```msnp
C: RML 6 65
<ml>
	<d n="hotmail.com">
		<c n="anotheruser" l="8" t="1" />
	</d>
</ml>
S: 241 6
```

## Target user not on that list
```msnp
C: RML 7 59
<ml>
	<d n="hotmail.com">
		<c n="ghost" l="1" t="1" />
	</d>
</ml>
S: 216 7
```

## Asynchronous update
```msnp
S: RML 0 65
<ml>
	<d n="hotmail.com">
		<c n="anotheruser" l="8" t="1" />
	</d>
</ml>
```

# Known changes
* [MSNP17](../versions/msnp17.md): Now manages circles?
