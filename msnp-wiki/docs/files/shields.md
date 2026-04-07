# Introduction
`Shields.xml` contains the Shields Configuration Data, and was first seen in [MSNP11](../versions/msnp11.md).

It is provided by the [GCF](../commands/gcf.md) command.

# Content
*If this is in [MSNP13](../versions/msnp13.md) or above, this element will be contained in the following:*
```xml
<Policies><Policy type="SHIELDS"><config>...</config></Policy></Policies>
```

*Otherwise, it is prefixed with the following:*
```xml
<?xml version="1.0" encoding="utf-8" ?>
```

## config
The root element of the document. Nothing special.
Contains the `<shield>` and `<block>` elements.

### shield
Contains many `<cli>` elements.

#### cli
This empty attribute has 5 parameters:
* `maj`: The major version that this block applies to.
* `min`: The minor version that this block applies to.
* `minbld`: Lowest bound of builds that this block applies to.
* `maxbld`: Highest bound of builds that this block applies to
* `deny`: What features are disabled:
	* `SharingFolders`: Sharing Folders. Since [MSNP13](../versions/msnp13.md).
	* `protocolhandler`: Unknown.
	* `dynamicbackgrounds`: Dynamic Backgrounds (Flash chat backgrounds).
	* `phone`: Calling features. Since [MSNP13](../versions/msnp13.md).
	* `voiceim`: Voice Clips.
	* `camera`: Video Conversations.
	* `audio`: Audio Conversations.
	* `filexfer`: File transfer.
	* `hotlinks`: Web links.
	  If this feature is blocked URLs sent in conversation windows will not be formatted as links.
	* `ddp`: Dynamic Display Pictures (Flash-based profile pictures).
	* `winks`: Winks (Flash-based full conversation window animations).

### block
*Since [MSNP12](../versions/msnp12.md).*

Contains either `<hashes>` or `<regexp>` elements.

#### hashes
This element blocks files from being sent based on their cryptographic (TODO: Confirm this) hashes.

(TODO: Does anyone have an example of things that go here?)

#### regexp
This element contains multiple `<imtext>` elements.

##### imtext
This empty element only has the `value` attribute, which is the regular expression
to search instant message text for. This attribute is base64-encoded.
