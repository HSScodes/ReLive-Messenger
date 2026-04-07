# Introduction
The `<contactInfo>` element is the main associative element of a `<Contact>` node.

# contactInfo
This element can contain many children, all of which optional:
* `<quickName>`: The sorting name of this contact
* `<passportName>`: The user handle of this contact.
* `<IsPassportNameHidden>` Are the contents of `<passportName>` hidden to the user (`true` or `false`)?
* `<isMessengerUser>`: Is this contact a part of the Messenger Service Network (`true` or `false`)?
* `<contactType>`: The type of contact this is related to:
	* `Regular`: This contact does not automatically update.
	* `Live`: This contact is in a synchronized relationship,
	and has their information automatically updated to your address book.
	* `LivePending`: This contact has not yet accepted your request to start a synchronized relationship.
	* `LiveRejected`: This contact has denied your request to start a synchronized relationship.
	* `LiveDropped`: This contact has broken their synchronized relationship with you.
	and is no longer having their information automatically updated to your address book.
	* `Me`: This contact is you.
* `<displayName>`: The display name for this contact.
* `<puid>`: Unused. Always 0.
* `<CID>`: The Common ID of this contact, which is a signed 64-bit integer.
* `<IsNotMobileVisible>`: Is this contact not visible as a mobile user (`true` or `false`)?
* `<isMobileIMEnabled>`: Does this contact allow me to talk to them via their mobile device (`true` or `false`)?
* `<isFavorite>`: Is this contact in the "Favorites" group (`true` or `false`)?
* `<isSmtp>`: Is this contact using a Japanese mobile phone (`true` or `false`)?
* `<hasSpace>`: Does this contact have a blog (`true` or `false`)?
* `<spotWatchState>`: Does this contact have a web watch, if not, set to `NoDevice`.
* `<birthdate>`: This contact's birthday as a ISO 8601 timestamp.
* `<PendingAnnotations>`: ([`ABContactAdd`](abcontactadd.md) only)
  A list of [`<Annotation>`](#annotation) elements you would like to add.
* `<firstName>`: The first name for this contact.
* `<lastName>`: The last name for this contact.
* `<comment>`: The user attached comment for this contact. New lines are included as-is.
* `<MiddleName>`: The middle name for this contact.
* `<annotations>`: Contains one or multiple [`<Annotation>`](#annotation) element(s).
* `<primaryEmailType>`: Can be any of the following:
	* `ContactEmailPersonal`
	* `ContactEmailMessenger`
	* `ContactEmailBusiness`
	* `ContactEmailOther`
	* `Passport`
* `<emails>`: Contains one or multiple [`<ContactEmail>`](#contactemail) element(s).
* `<PrimaryPhone>`: Can be any of the following:
	* `ContactPhonePersonal`
	* `ContactPhonePager`
	* `ContactPhoneFax`
	* `ContactPhoneBusiness`
	* `ContactPhoneOther`
	* `ContactPhoneMobile`
* `<phones>`: Contains one or multiple [`<ContactPhone>`](#contactphone) element(s).
* `<PrimaryLocation>`: Can be any of the following:
	* `ContactLocationBusiness`
	* `ContactLocationPersonal`
* `<locations>`: Contains one or multiple [`<ContactLocation>`](#contactlocation) element(s).
* `<webSites>`: Contains one or multiple [`<ContactWebSite>`](#contactwebsite) element(s).
* `<IsPrivate>`: Is this contact private (`true` or `false`).
* `<Gender>`: What gender is this contact, if unsure, set to `Unspecified`.
* `<TimeZone>`: What time zone is this contact in?, if unsure, set to `None`.

## Annotation
This element contains two children:
* `<Name>`: The key of this property:
	* `MSN.IM.MBEA`: (Only for you) Do I have a mobile device associated with my account? (`0` or `1`).
	* `MSN.IM.GTC`: (Only for you) Do I automatically add users to the AL or ask first? (`0` or `1`).
	* `MSN.IM.BLP`: (Only for you) Are all users blocked or allowed by default to talk to me? (`0` or `1`).
	* `AB.JobTitle`: The job title of this contact.
	* `AB.NickName`: The user-provided nick-name for this contact.
	* `AB.Spouse`: The contact's spouse's name.
* `<Value>`: The value of this property.

## ContactEmail
This element contains two children:
* `<contactEmailType>`: Can be any of the following:
	* `ContactEmailPersonal`
	* `ContactEmailMessenger`
	* `ContactEmailBusiness`
	* `ContactEmailOther`
* `<email>`: The e-mail address associated with the `<contactEmailType>`.

## ContactPhone
This element contains two children:
* `<contactPhoneType>`: Can be any of the following:
	* `ContactPhonePersonal`
	* `ContactPhonePager`
	* `ContactPhoneFax`
	* `ContactPhoneBusiness`
	* `ContactPhoneOther`
	* `ContactPhoneMobile`
* `<number>`: The phone number associated with the `<contactPhoneType>`.

## ContactLocation
This element contains two children:
* `<contactLocationType>`: Can be any of the following:
	* `ContactLocationBusiness`
	* `ContactLocationPersonal`
* `<name>`: The name associated with the `<contactLocationType>`.
* `<street>`: The street associated with the `<contactLocationType>`.
* `<city>`: The city associated with the `<contactLocationType>`.
* `<state>`: The state associated with the `<contactLocationType>`.
* `<country>`: The country associated with the `<contactLocationType>`.
* `<postalCode>`: The postal code associated with the `<contactLocationType>`.
* `<Changes>`: A space delimited list of changed elements in this `<ContactLocation>`:
	* `Name`
	* `Street`
	* `City`
	* `State`
	* `Country`
	* `PostalCode`

## ContactWebSite
This element contains two children:
* `<contactWebSiteType>`: Can be any of the following:
	* `ContactWebSiteBusiness`
	* `ContactWebSitePersonal`
* `<webURL>`: The location of the website associated with the `<contactWebSiteType>`.
