# Error codes and HRESULTs
The following is a list of all **known** MSNP error codes and related `HRESULT` values.  
If you know any error that isn't listed, please contact me.

For valid MSNP commands, read the [Table of Commands](table_of_commands.md).

## MSNP error codes
| `MSNP ERROR CODE` | related `HRESULT` value | related `HRESULT`'s name | `DRAFT` name | Description / Known reason? |
| ----- | ------------ | -------------------------------------- | ------------------------------ | ------------------ |
| `200` | N/A          | N/A                                    | `ERR_SYNTAX_ERROR`             | Syntax error. |
| `201` | `0x81000435` | `MSGR_E_MSNP_INVALID_PARAMETER`        | `ERR_INVALID_PARAMETER`        | Invalid parameter in command. |
| `203` | `0x810003c0` | `MSGR_E_INVALID_FEDERATED_USER`        | N/A                            | ? |
| `204` | `0x8100037c` | `MSGR_E_UNROUTABLE_USER`               | N/A                            | The network specified for the user is unavailable or does not exist. |
| `205` | `0x8100030a` | `MSGR_E_USER_NOT_FOUND`                | `ERR_INVALID_USER`             | The user is invalid. |
| `206` | `0x8100030a` | `MSGR_E_USER_NOT_FOUND`                | `ERR_FQDN_MISSING`             | The domain name of the user handle is missing. |
| `207` | `0x81000304` | `MSGR_E_ALREADY_LOGGED_ON`             | `ERR_ALREADY_LOGIN`            | You are already logged in. |
| `208` | `0x8100030a` | `MSGR_E_USER_NOT_FOUND`                | `ERR_INVALID_USERNAME`         | The username of the user handle is invalid. |
| `209` | `0x81000324` | `MSGR_E_INVALID_FRIENDLY_NAME`         | `ERR_INVALID_FRIENDLY_NAME`    | You cannot use the specified friendly name. |
| `210` | `0x81000307` | `MSGR_E_LIST_FULL`                     | `ERR_LIST_FULL`                | The specified list is full. |
| `212` | `0x8100030d` | `MSGR_E_UNEXPECTED`                    | N/A                            | ? |
| `213` | `0x81000392` | `MSGR_E_USER_DOESNT_EXIST`             | N/A                            | ? |
| `215` | `0x8100030b` | `MSGR_E_ALREADY_IN_LIST`               | `ERR_ALREADY_THERE`            | The specified user is already added to that list. |
| `216` | `0x8100030a` | `MSGR_E_USER_NOT_FOUND`                | `ERR_NOT_ON_LIST`              | The specified user is not on any of your lists. |
| `217` | `0x81000430` | `MSGR_E_MSNP_NOT_ACCEPTING_IMS`        | N/A                            | The specified user is currently not accepting instant messages. |
| `218` | `0x01000301` | `MSGR_S_ALREADY_IN_THE_MODE`           | `ERR_ALREADY_IN_THE_MODE`      | You are already in the mode specified. |
| `219` | `0x81000431` | `MSGR_E_MSNP_ALREADY_IN_OPPOSITE_LIST` | `ERR_ALREADY_IN_OPPOSITE_LIST` | The user is in a mutually exclusive list and therefore can not be added to the specified one. |
| `220` | `0x81000335` | `MSGR_E_NOT_ACCEPTING_PAGES`           | N/A                            | The specified user is currently not accepting paged messages. |
| `232` | `0x810003b5` | `MSGR_E_INVALID_MSISDN`                | N/A                            | The specified mobile number is invalid. |
| `233` | `0x810003b6` | `MSGR_E_UNKNOWN_MSISDN`                | N/A                            | The specified mobile number is unknown to the Messenger Service. |
| `234` | `0x81000439` | `MSGR_E_MSNP_UNKNOWN_KEITAI_DOMAIN`    | N/A                            | The specified Japanese mobile address has a domain that is unknown to the Messenger Service. |
| `240` | `0x8100043b` | `MSGR_E_MSNP_INVALID_XML`              | N/A                            | ? |
| `241` | `0x8100043a` | `MSGR_E_MSNP_INVALID_XML_DATA`         | N/A                            | ? |
| `280` | `0x81000436` | `MSGR_E_MSNP_SWITCHBOARD_FAILED`       | `ERR_SWITCHBOARD_FAILED`       | Internal server error: A Switchboard Server (SB) has failed to negotiate. |
| `281` | N/A          | N/A                                    | `ERR_NOTIFY_XFR_FAILED`        | ? |
| `300` | N/A          | N/A                                    | `ERR_REQUIRED_FIELDS_MISSING`  | ? |
| `302` | N/A          | N/A                                    | `ERR_NOT_LOGGED_IN`            | You need to log in to perform that action. |
| `400` | `0x81000376` | `MSGR_E_ABCH_READ_ONLY`                | N/A                            | Your Address Book is read-only and can not be used. |
| `402` | `0x81000377` | `MSGR_E_ABCH_TOO_BUSY`                 | N/A                            | The Address Book service is currently too busy. |
| `403` | `0x81000378` | `MSGR_E_ABCH_UNAVAILABLE`              | N/A                            | The Address Book service is currently unavailable. |
| `413` | `0x810003a5` | `MSGR_E_SUBSCRIPTION_NEEDED`           | N/A                            | A subscription is required to use the feature associated with your command. |
| `414` | `0x810003a6` | `MSGR_E_SUBSCRIPTION_DISABLED`         | N/A                            | ? |
| `416` | `0x810003c1` | `MSGR_E_MARKET_DISABLED`               | N/A                            | The feature associated with your command is disabled in your region. |
| `417` | `0x810003c2` | `MSGR_E_DISABLED_EVERYWHERE`           | N/A                            | The feature associated with your command is disabled in all regions. |
| `418` | `0x810003c3` | `MSGR_E_TRY_AGAIN_LATER`               | N/A                            | The operation failed and you should try again later. |
| `419` | `0x810003c4` | `MSGR_E_NO_MARKET_SPECIFIED`           | N/A                            | You have not specified a region, which is required for this feature. |
| `420` | `0x810003cc` | `MSGR_E_INVITE_REQUIRED`               | N/A                            | You need an invitation to use this version of the Official Client. |
| `500` | `0x810003a8` | `MSGR_E_INTERNAL_SERVER_ERROR`         | `ERR_INTERNAL_SERVER`          | Unspecified internal server error. |
| `501` | N/A          | N/A                                    | `ERR_DB_SERVER`                | Internal server error: Unspecified database failure. |
| `503` | `0x80004005` | `MSGR_E_FAIL` / `E_FAIL`               | N/A                            | Unspecified failure. |
| `504` | `0x810003c5` | `MSGR_E_UPS_UNAVAILABLE`               | N/A                            | ? |
| `505` | `0x810003c6` | `MSGR_E_SCS_UNAVAILABLE`               | N/A                            | ? |
| `508` | `0x81000433` | `MSGR_E_MSNP_FEDERATED_SERVER_ERROR`   | N/A                            | Unspecified federated service failure. |
| `509` | `0x81000434` | `MSGR_E_MSNP_UUM_ERROR`                | N/A                            | ? |
| `510` | N/A          | N/A                                    | `ERR_FILE_OPERATION`           | Internal server error: A file operation has failed. |
| `511` | `0x81000603` | `MSGR_E_PPLATFORM_SERVER_511`          | N/A                            | ? |
| `520` | `0x810003a8` | `MSGR_E_INTERNAL_SERVER_ERROR`         | `ERR_MEMORY_ALLOC`             | Internal server error: Failed to allocate memory for this operation. |
| `540` | `0x8100036d` | `MSGR_E_LOCKANDKEY_FAILED`             | N/A                            | The challenge response was incorrect against what the server expected. |
| `600` | `0x8100030e` | `MSGR_E_SERVER_TOO_BUSY`               | `ERR_SERVER_BUSY`              | The server is too busy to handle this request. |
| `601` | `0x81000314` | `MSGR_E_SERVER_UNAVAILABLE`            | `ERR_SERVER_UNAVAILABLE`       | The server is unavailable at this time. |
| `602` | N/A          | N/A                                    | `ERR_PEER_NS_DOWN`             | Internal server error: The peered Notification Server (NS) is offline. |
| `603` | N/A          | N/A                                    | `ERR_DB_CONNECT`               | Internal server error: Failed to connect to database. |
| `604` | N/A          | N/A                                    | `ERR_SERVER_GOING_DOWN`        | Internal server error: The server is stopping. |
| `606` | `0x81000339` | `MSGR_E_PAGING_UNAVAILABLE`            | N/A                            | ? |
| `707` | N/A          | N/A                                    | `ERR_CREATE_CONNECTION`        | Internal server error: Failed to create a connection. |
| `710` | `0x81000339` | `MSGR_E_PAGING_UNAVAILABLE`            | N/A                            | ? |
| `711` | N/A          | N/A                                    | `ERR_BLOCKING_WRITE`           | Internal server error: A operation has failed because a blocking write operation is occuring. |
| `712` | N/A          | N/A                                    | `ERR_SESSION_OVERLOAD`         | Internal server error: The server can no longer handle the amount of sessions. |
| `713` | N/A          | N/A                                    | `ERR_USER_TOO_ACTIVE`          | You are being too active. You have been rate limited. |
| `714` | N/A          | N/A                                    | `ERR_TOO_MANY_SESSIONS`        | Internal server error: You have too many sessions. |
| `715` | `0x81000438` | `MSGR_E_MSNP_NOT_EXPECTED`             | `ERR_NOT_EXPECTED`             | Command not expected at that time. |
| `717` | N/A          | N/A                                    | `ERR_BAD_FRIEND_FILE`          | Internal server error: Your contact list is corrupt. |
| `718` | `0x8100035a` | `MSGR_E_RESTRICTED_USER`               | N/A                            | ? |
| `719` | `0x810003c7` | `MSGR_E_FEDERATED_SESSION`             | N/A                            | ? |
| `726` | `0x8100037d` | `MSGR_E_USER_FEDERATED`                | N/A                            | The specified user is on a federated network and does not support the operation. |
| `729` | `0x8100030e` | `MSGR_E_SERVER_TOO_BUSY`               | N/A                            | ? |
| `800` | `0x81000398` | `MSGR_E_RATE_LIMIT_EXCEEDED`           | N/A                            | You are being rate limited. |
| `910` | `0x8100030e` | `MSGR_E_SERVER_TOO_BUSY`               | N/A                            | The server is too busy to authenticate your user. |
| `911` | `0x81000395` | `MSGR_E_MSNP_911`                      | `ERR_AUTHENTICATION_FAILED`    | Generic authentication failure. |
| `913` | `0x8100043c` | `MSGR_E_MSNP_NOT_ALLOWED_WHEN_OFFLINE` | `ERR_NOT_ALLOWED_WHEN_OFFLINE` | You may not perform that action while appearing offline (hidden) or in semi-offline mode. |
| `917` | `0x81000327` | `MSGR_E_INVALID_DOMAIN`                | N/A                            | The domain specified at authentication is invalid. |
| `918` | `0x810003a8` | `MSGR_E_INTERNAL_SERVER_ERROR`         | N/A                            | ? |
| `919` | `0x810003a8` | `MSGR_E_INTERNAL_SERVER_ERROR`         | N/A                            | ? |
| `920` | `0x81000326` | `MSGR_E_NOT_ALLOWING_NEW_USERS`        | `ERR_NOT_ACCEPTING_NEW_USERS`  | The server is too full and is no longer accepting new authentication requests. |
| `921` | `0x8100030e` | `MSGR_E_SERVER_TOO_BUSY`               | N/A                            | The server is too busy to authenticate your user. |
| `922` | `0x8100030e` | `MSGR_E_SERVER_TOO_BUSY`               | N/A                            | ? |
| `923` | `0x81000331` | `MSGR_E_CHILD_WITHOUT_CONSENT`         | N/A                            | Child account does not have authorization to use the Messenger Service. |
| `924` | `0x81000336` | `MSGR_E_EMAIL_PASSPORT_NOT_VALIDATED`  | N/A                            | You need to verify your account before using the Messenger Service. |
| `926` | `0x81000359` | `MSGR_E_MANAGED_USER_INVALID_CVR`      | N/A                            | The account's permissions could not be verified. |
| `927` | `0x8100035a` | `MSGR_E_RESTRICTED_USER`               | N/A                            | The parent or guardian of this account has blocked access of the Messenger Service using this account. |
| `928` | `0x81000303` | `MSGR_E_INVALID_PASSWORD`              | N/A                            | The password provided is invalid. |
| `929` | `0x81000385` | `MSGR_E_LOCKANDKEY_FAILED_FOR_MCAA`    | N/A                            | The challenge response was incorrect for this MCAA (TODO: What is this?) request. |
| `930` | `0x8100037b` | `MSGR_E_FEDERATED_DOMAIN`              | N/A                            | This account belongs to a enterprise domain and can not be used on the Messenger Service. |
| `934` | `0x81000410` | `MSGR_E_FSS_USER_NO_ACCESS`            | N/A                            | ? |

## All Messenger HRESULTs
Some of the "First seen in" values may be inaccurate,
due to being sourced from the type libraries included with Client Versions 1.0 to 4.7.

| `HRESULT` value | `HRESULT`'s name | First seen in (version) | Description / Known reason? |
| --------------- | ---------------- | ------------- | --------------------------- |
| `0x00000000` | `MSGR_S_OK`                               | 1.0.0452 | The operation was successful. |
| `0x80004005` | `MSGR_E_FAIL`                             | 1.0.0452 | Unspecified failured. |
| `0x81000301` | `MSGR_E_CONNECT`                          | 1.0.0452 | ? |
| `0x81000302` | `MSGR_E_INVALID_SERVER_NAME`              | 1.0.0452 | ? |
| `0x81000303` | `MSGR_E_INVALID_PASSWORD`                 | 1.0.0452 | The password provided is invalid. |
| `0x81000304` | `MSGR_E_ALREADY_LOGGED_ON`                | 1.0.0452 | You are already logged in. |
| `0x81000305` | `MSGR_E_SERVER_VERSION`                   | 1.0.0452 | ? |
| `0x81000306` | `MSGR_E_LOGON_TIMEOUT`                    | 1.0.0452 | The login process could not be completed in a reasonable time and has been aborted. |
| `0x81000307` | `MSGR_E_LIST_FULL`                        | 1.0.0452 | The specified list is full. |
| `0x81000308` | `MSGR_E_AI_REJECT`                        | 1.0.0452 | ? |
| `0x81000309` | `MSGR_E_AI_REJECT_NOT_INST`               | 1.0.0452 | ? |
| `0x8100030a` | `MSGR_E_USER_NOT_FOUND`                   | 1.0.0452 | The specified user could not be found. |
| `0x8100030b` | `MSGR_E_ALREADY_IN_LIST`                  | 1.0.0452 | The specified user is already added to that list. |
| `0x8100030c` | `MSGR_E_DISCONNECTED`                     | 1.0.0452 | You are disconnected. |
| `0x8100030d` | `MSGR_E_UNEXPECTED`                       | 1.0.0452 | An unexpected error has occured. |
| `0x8100030e` | `MSGR_E_SERVER_TOO_BUSY`                  | 1.0.0452 | The server is too busy to handle this request. |
| `0x8100030f` | `MSGR_E_INVALID_AUTH_PACKAGES`            | 1.0.0452 | ? |
| `0x81000310` | `MSGR_E_NEWER_CLIENT_AVAILABLE`           | 1.0.0452 | A newer version of the client is avaliable. |
| `0x81000311` | `MSGR_E_AI_TIMEOUT`                       | 1.0.0452 | ? |
| `0x81000312` | `MSGR_E_CANCEL`                           | 1.0.0452 | An operation has been cancelled. |
| `0x81000313` | `MSGR_E_TOO_MANY_MATCHES`                 | 1.0.0452 | The specified query has too many matches. Try being more specific. |
| `0x81000314` | `MSGR_E_SERVER_UNAVAILABLE`               | 1.0.0452 | The server is unavaliable. |
| `0x81000315` | `MSGR_E_LOGON_UI_ACTIVE`                  | 1.0.0452 | The "Login as..." dialog is open. |
| `0x81000316` | `MSGR_E_OPTION_UI_ACTIVE`                 | 1.0.0452 | The "Options" dialog is open. |
| `0x81000317` | `MSGR_E_CONTACT_UI_ACTIVE`                | 1.0.0452 | The "Add a Contact" dialog is open. |
| `0x81000318` | `MSGR_E_PRIMARY_SERVICE_NOT_LOGGED_ON`    | 1.0.0863 | ? |
| `0x81000319` | `MSGR_E_LOGGED_ON`                        | 1.0.0863 | You are logged in. |
| `0x8100031a` | `MSGR_E_CONNECT_PROXY`                    | 1.0.0863 | Failed to connect to a proxy. |
| `0x8100031b` | `MSGR_E_PROXY_AUTH`                       | 1.0.0863 | Failed to authenticate to a proxy. |
| `0x8100031c` | `MSGR_E_PROXY_AUTH_TYPE`                  | 1.0.0863 | ? |
| `0x8100031d` | `MSGR_E_INVALID_PROXY_NAME`               | 1.0.0863 | ? |
| `0x81000320` | `MSGR_E_NOT_PRIMARY_SERVICE`              | 1.0.0863 | ? |
| `0x81000321` | `MSGR_E_TOO_MANY_SESSIONS`                | 1.0.0863 | ? |
| `0x81000322` | `MSGR_E_TOO_MANY_MESSAGES`                | 1.0.0863 | ? |
| `0x81000323` | `MSGR_E_REMOTE_LOGIN`                     | 1.0.0863 | You logged in from another location. |
| `0x81000324` | `MSGR_E_INVALID_FRIENDLY_NAME`            | 1.0.0863 | You cannot use the specified friendly name. |
| `0x81000325` | `MSGR_E_SESSION_FULL`                     | 1.0.0863 | ? |
| `0x81000326` | `MSGR_E_NOT_ALLOWING_NEW_USERS`           | 1.0.0863 | The server is too full and is no longer accepting new authentication requests. |
| `0x81000327` | `MSGR_E_INVALID_DOMAIN`                   | 2.0.0085 | ? |
| `0x81000328` | `MSGR_E_TCP_ERROR`                        | 2.0.0085 | ? |
| `0x81000329` | `MSGR_E_SESSION_TIMEOUT`                  | 2.0.0085 | ? |
| `0x8100032a` | `MSGR_E_MULTIPOINT_SESSION_BEGIN_TIMEOUT` | 2.0.0085 | ? |
| `0x8100032b` | `MSGR_E_MULTIPOINT_SESSION_END_TIMEOUT`   | 2.0.0085 | ? |
| `0x8100032c` | `MSGR_E_REVERSE_LIST_FULL`                | 2.1.1047 | Your Reverse List (RL) is full. |
| `0x8100032d` | `MSGR_E_SERVER_ERROR`                     | 2.1.1047 | ? |
| `0x8100032e` | `MSGR_E_SYSTEM_CONFIG`                    | 2.1.1047 | ? |
| `0x8100032f` | `MSGR_E_NO_DIRECTORY`                     | 2.1.1047 | ? |
| `0x81000330` | `MSGR_E_CHILD_WITHOUT_CONSENT`            | 2.2.1053 | (Obsolete, use `0x81000331` instead) Child account does not have authorization to use this feature. |
| `0x81000330` | `MSGR_E_RETRY_SET`                        | 3.0.0080 | ? |
| `0x81000331` | `MSGR_E_CHILD_WITHOUT_CONSENT`            | 3.0.0080 | Child account does not have authorization to use this feature. |
| `0x81000332` | `MSGR_E_USER_CANCELLED`                   | 3.0.0080 | An operation has been cancelled by a user. |
| `0x81000333` | `MSGR_E_CANCEL_BEFORE_CONNECT`            | 3.0.0080 | A connection was cancelled before attempting to open it. |
| `0x81000334` | `MSGR_E_VOICE_IM_TIMEOUT`                 | 3.0.0283 | A voice communication has timed out and has been cancelled. |
| `0x81000335` | `MSGR_E_NOT_ACCEPTING_PAGES`              | 3.0.0283 | The specified user is currently not accepting paged messages. |
| `0x81000336` | `MSGR_E_EMAIL_PASSPORT_NOT_VALIDATED`     | 3.0.0283 | You need to verify your account before performing that operation. |
| `0x81000337` | `MSGR_E_AUDIO_UI_ACTIVE`                  | 3.0.0283 | The "Audio Tuning Wizard" dialog is open. |
| `0x81000338` | `MSGR_E_NO_HARDWARE`                      | 3.0.0283 | You are missing the required hardware for this feature. |
| `0x81000339` | `MSGR_E_PAGING_UNAVAILABLE`               | 3.0.0283 | You cannot page the specified user at this time. |
| `0x8100033a` | `MSGR_E_PHONE_INVALID_NUMBER`             | 3.0.0283 | The specified phone number is invalid. |
| `0x8100033b` | `MSGR_E_PHONE_NO_FUNDS`                   | 3.0.0283 | You need to purchase funds to use the phone service. |
| `0x8100033c` | `MSGR_E_VOICE_NO_ANSWER`                  | 3.0.0283 | ? |
| `0x8100033d` | `MSGR_E_VOICE_WAVEIN_DEVICE`              | 3.0.0283 | ? |
| `0x8100033e` | `MSGR_E_FT_TIMEOUT`                       | 3.0.0283 | A file transfer has timed out and has been cancelled. |
| `0x8100033f` | `MSGR_E_MESSAGE_TOO_LONG`                 | 3.0.0283 | A message was specified that was too long. |
| `0x81000340` | `MSGR_E_VOICE_FIREWALL`                   | 3.0.0283 | ? |
| `0x81000341` | `MSGR_E_VOICE_NETCONN`                    | 3.0.0283 | ? |
| `0x81000342` | `MSGR_E_PHONE_CIRCUITS_BUSY`              | 3.0.0283 | ? |
| `0x81000343` | `MSGR_E_SERVER_PROTOCOL`                  | 3.5.0077 | ? |
| `0x81000344` | `MSGR_E_UNAVAILABLE_VIA_HTTP`             | 3.5.0077 | The feature requested is not avaliable via HTTP. |
| `0x81000345` | `MSGR_E_PHONE_INVALID_PIN`                | 3.5.0077 | An invalid PIN was specified when trying to use the phone service. |
| `0x81000346` | `MSGR_E_PHONE_PINPROCEED_TIMEOUT`         | 3.5.0077 | ? |
| `0x81000347` | `MSGR_E_SERVER_SHUTDOWN`                  | 3.5.0077 | The server is shutting down. |
| `0x81000348` | `MSGR_E_CLIENT_DISALLOWED`                | 3.5.0077 | This client is not allowed to use this feature. |
| `0x81000349` | `MSGR_E_PHONE_CALL_NOT_COMPLETE`          | 3.5.0077 | ? |
| `0x8100034a` | `MSGR_E_GROUPS_NOT_ENABLED`               | 4.5.0121 | The contact list is currently sorted by status, and not by groups. |
| `0x8100034b` | `MSGR_E_GROUP_ALREADY_EXISTS`             | 4.5.0121 | The specified group already exists. |
| `0x8100034c` | `MSGR_E_TOO_MANY_GROUPS`                  | 4.5.0121 | You have too many groups. |
| `0x8100034d` | `MSGR_E_GROUP_DOES_NOT_EXIST`             | 4.5.0121 | The specified group does not exist. |
| `0x8100034e` | `MSGR_E_USER_NOT_GROUP_MEMBER`            | 4.5.0121 | The specified object is a user, and not a group member. |
| `0x8100034f` | `MSGR_E_GROUP_NAME_TOO_LONG`              | 4.5.0121 | The specified name was too long for a group. |
| `0x81000350` | `MSGR_E_GROUP_NOT_EMPTY`                  | 4.5.0121 | The operation failed because the group was not empty. |
| `0x81000351` | `MSGR_E_BAD_GROUP_NAME`                   | 4.5.0121 | The group name specified is invalid. |
| `0x81000352` | `MSGR_E_PHONESERVICE_UNAVAILABLE`         | 4.5.0121 | The phone service is unavailable at this time. |
| `0x81000353` | `MSGR_E_CANNOT_RENAME`                    | 4.5.0121 | You cannot rename the specified object. |
| `0x81000354` | `MSGR_E_CANNOT_DELETE`                    | 4.5.0121 | You cannot delete the specified object. |
| `0x81000355` | `MSGR_E_INVALID_SERVICE`                  | 4.5.0121 | ? |
| `0x81000356` | `MSGR_E_POLICY_RESTRICTED`                | 4.6.0071 | The operation failed because of an active policy. |
| `0x81000367` | `MSGR_E_BUSY`                             | 4.6.0071 | The operation failed because the application was busy. |
| `0x01000301` | `MSGR_S_ALREADY_IN_THE_MODE`              | 1.0.0863 | You are already in the mode specified. |
| `0x01000302` | `MSGR_S_TRANSFER_SEND_BEGUN`              | 3.0.0283 | An outgoing file transfer has started. |
| `0x01000303` | `MSGR_S_TRANSFER_SEND_FINISHED`           | 3.0.0283 | An outgoing file transfer has completed. |
| `0x01000304` | `MSGR_S_TRANSFER_RECEIVE_BEGUN`           | 3.0.0283 | An incoming file transfer has started. |
| `0x01000305` | `MSGR_S_TRANSFER_RECEIVE_FINISHED`        | 3.0.0283 | An incoming file transfer has completed. |
| `0x01000306` | `MSGR_S_GROUP_ALREADY_EXISTS`             | 4.5.0121 | The group already exists. |

## Common HRESULTs without related MSNP error codes
| `HRESULT` value | `HRESULT`'s name | Description / Known reason? |
| ------------ | ------------------------------------------------- | ------------- |
| `0x80004005` | `E_FAIL`                                          | Unspecified failure. |
| `0x00048802` | `PPCRL_AUTHSTATE_S_AUTHENTICATED_OFFLINE`         | You are logged in, but working offline. |
| `0x00048803` | `PPCRL_AUTHSTATE_S_AUTHENTICATED_PASSWORD`        | You are logged in using a password. |
| `0x80048810` | `PPCRL_AUTHREQUIRED_E_PASSWORD`                   | Please input your password. |
| `0x80048800` | `PPCRL_AUTHSTATE_E_UNAUTHENTICATED`               | You are not logged in. |
| `0x80048801` | `PPCRL_AUTHSTATE_E_EXPIRED`                       | Your session has expired. Please log in again. |
| `0x80048820` | `PPCRL_REQUEST_E_AUTH_SERVER_ERROR`               | Authentication server error. |
| `0x80048821` | `PPCRL_REQUEST_E_BAD_MEMBER_NAME_OR_PASSWORD`     | Invalid email address or password. |
| `0x80048823` | `PPCRL_REQUEST_E_PASSWORD_LOCKED_OUT`             | This account's password is disabled and needs to be reset. |
| `0x80048825` | `PPCRL_REQUEST_E_TOU_CONSENT_REQUIRED`            | You must accept the service's Terms of Use before using this account.|
| `0x80048826` | `PPCRL_REQUEST_E_FORCE_RENAME_REQUIRED`           | Your account details needs to be revised. |
| `0x80048827` | `PPCRL_REQUEST_E_FORCE_CHANGE_PASSWORD_REQUIRED`  | Your account's password needs to be changed. |
| `0x8004882a` | `PPCRL_REQUEST_E_PARTNER_NOT_FOUND`               | The authentication partner does not exist. Are you trying to use unmodified Windows Live Messenger 2011 or 2012, by chance? |
| `0x80048831` | `PPCRL_REQUEST_E_PASSWORD_EXPIRED`                | Your account's password has expired and needs to be changed. |
| `0x80048836` | `PPCRL_REQUEST_E_EMAIL_VALIDATION_REQUIRED`       | Your account's e-mail address must be verified. |
| `0x80048862` | `PPCRL_E_UNABLE_TO_RETRIEVE_SERVICE_TOKEN`        | Failed to retrieve the service token. |
| `0x80070002` | System Error `ERROR_FILE_NOT_FOUND`               | A file could not be found. |
| `0x80070057` | System Error `ERROR_INVALID_PARAMETER`            | One or more parameters have invalid values. |
| `0x800701f6` | System Error `HTTP_STATUS_BAD_GATEWAY`            | The remote HTTP server returned the "502 Bad Gateway" status. |
| `0x80071392` | System Error `ERROR_OBJECT_ALREADY_EXISTS`        | Something is seriously wrong with your installation. Consider uninstalling, rebooting, and re-installing, and then try again. |
| `0x80072ee7` | System Error `ERROR_INTERNET_NAME_NOT_RESOLVED`   | The domain could not be resolved. (Is your client not patched?) |
| `0x80072efd` | System Error `ERROR_WINHTTP_CANNOT_CONNECT`       | WinHTTP could not connect to the server specified. |
| `0x80072f7d` | System Error `ERROR_WINHTTP_SECURE_CHANNEL_ERROR` | Any possible secure channel (SSL) error from WinHTTP. |
