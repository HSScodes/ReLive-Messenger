# Introduction
`FQY` is a command introduced with [MSNP14](../versions/msnp14.md).

It is a Notification Server command, WITH a request and WITH a response payload.

Requests the server on which Network ID the user is assigned to.

# Client/Request
```
FQY TrID length
payload
```

Where `payload` is a [`<ml>`](#ml) document, without any support for whitespace outside of element parameters.

## ml
This element supports one or multiple `<d>` elements.

### d
This element has one attribute:
* `n`: The domain (`...@this`) of the user handle.

This element contains one or multiple `<c>` elements.

#### c
This element has two attributes:
* `n`: The local part (`this@...`) of the user handle.
* `t`: The Network ID that this user is associated with.
  This parameter is to be omitted by the client, but not the server.

# Server/Response
```
FQY TrID length
payload
```

Where payload is a [`<ml>`](#ml) document, without any support for whitespace outside of element parameters.

# Examples
*NOTE: The XML in these examples has been exploded for visibility and formatting reasons.  
No whitespace is allowed in FQY's payload and the payload size reflects this,
and is set to the correct value.*

## User on the same service
```msnp
C: FQY 1 53
<ml>
	<d n="hotmail.com">
		<c n="anotheruser" />
	</d>
</ml>
S: FQY 1 59
<ml>
	<d n="hotmail.com">
		<c n="anotheruser" t="1" />
	</d>
</ml>
```

## User on another service
```msnp
C: FQY 2 53
<ml>
	<d n="hotmail.com">
		<c n="anotheruser" />
	</d>
</ml>
S: FQY 2 60
<ml>
	<d n="hotmail.com">
		<c n="anotheruser" t="32" />
	</d>
</ml>
```

## No services specified
```msnp
C: FQY 3 9
<ml></ml>
S: 240 3
```

## No domain name specified
```msnp
C: FQY 4 16
<ml>
	<d>
	</d>
</ml>
S: 241 4
```

## Target user not found
```msnp
C: FQY 5 47
<ml>
	<d n="hotmail.com">
		<c n="ghost" />
	</d>
</ml>
S: 208 5
```

# Known changes
None.
