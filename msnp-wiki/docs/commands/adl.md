# Introduction
`ADL` is a command introduced with [MSNP13](../versions/msnp13.md).

It is a Notification Server command, WITH a request and WITH a response payload.

Adds a user to a list during a session or initialises the states of the Forward List (FL),
Allow List (AL) and Block List (BL) after retrieving the current state of all lists from the
[Address Book Service](../services/abservice.md) and the
[Contact Sharing Service](../services/sharingservice.md).  
For the actions that add a user to the address book or the membership lists,
read either the [`ABContactAdd`](../services/abservice/abcontactadd.md) article
or the [`AddMember`](../services/sharingservice/addmember.md) article respectively.

# Client/Request
```
ADL TrID length
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
	* `8` (bit 3): Reverse List (RL). This value can only be set by the server.
	* `16` (bit 4): Pending List (PL). This value can only be set by the server.
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
	* `8` (bit 3): Reverse List (RL). This value can only be set by the server.
	* `16` (bit 4): Pending List (PL). This value can only be set by the server.

This element also has one optional attribute:
* `f`: The friendly name of this user. This attribute can only be set by the server.

# Server/Response

## As a response
`ADL TrID OK`

No payload is attached in this scenario.

## Asynchronously
```
ADL 0 length
payload
```

Where payload is a [`<ml>`](#ml) document, without any support for whitespace outside of element parameters.

# Examples
*NOTE: The XML in these examples has been exploded for visibility and formatting reasons.  
No whitespace is allowed in ADL's payload and the payload size reflects this,
and is set to the correct value.*

## Initial list
```msnp
C: ADL 1 110
<ml l="1">
	<d n="hotmail.com">
		<c n="anotheruser" l="3" t="1" />
	</d>
	<t>
		<c n="tel:+15551111222" l="3" />
	</t>
</ml>
S: ADL 1 OK
```

## Normal use

### Add a user handle
```msnp
C: ADL 2 65
<ml>
	<d n="hotmail.com">
		<c n="anotheruser" l="1" t="1" />
	</d>
</ml>
S: ADL 2 OK
```

### Add a telephone number
```msnp
C: ADL 3 48
<ml>
	<t>
		<c n="tel:+15551111222" l="1" />
	</t>
</ml>
S: ADL 3 OK
```

## No services specified
```msnp
C: ADL 4 9
<ml></ml>
S: 240 4
```

## No domain name specified
```msnp
C: ADL 5 16
<ml>
	<d>
	</d>
</ml>
S: 241 5
```

## Out of bounds Network ID
```msnp
C: ADL 6 67
<ml>
	<d n="hotmail.com">
		<c n="anotheruser" l="1" t="256" />
	</d>
</ml>
S: 204 6
```

## You cannot add to the Reverse List or Pending List
```msnp
C: ADL 7 65
<ml>
	<d n="hotmail.com">
		<c n="anotheruser" l="8" t="1" />
	</d>
</ml>
S: 241 7
```

## Target user not found
```msnp
C: ADL 8 59
<ml>
	<d n="hotmail.com">
		<c n="ghost" l="1" t="1" />
	</d>
</ml>
S: 208 8
```

## Target list is full
```msnp
C: ADL 9 61
<ml>
	<d n="hotmail.com">
		<c n="stuffed" l="1" t="1" />
	</d>
</ml>
S: 210 9
```

## Asynchronous update
```msnp
S: ADL 0 82
<ml>
	<d n="hotmail.com">
		<c n="anotheruser" l="8" t="1" f="another user" />
	</d>
</ml>
```

# Known changes
* [MSNP17](../versions/msnp17.md): Now manages circles?
