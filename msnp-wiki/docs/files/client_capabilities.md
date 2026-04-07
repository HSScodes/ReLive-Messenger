# Information
Client Capabilities are a feature introduced with [MSNP8](../versions/msnp8.md)
to notify other clients what optional features your client supports.

This was expanded in [MSNP16](../versions/msnp16.md) with Extended Client Capabilities.

# Client Capabilities
*Since [MSNP8](../versions/msnp8.md).*

| `hexadecimal` | `decimal`    | meaning |
| ------------- | ------------ | ------- |
| `0x00000001`  | `1`          | The user is on a mobile device. |
| `0x00000002`  | `2`          | The user is on the MSN Desktop client, version 8 or above. |
| `0x00000004`  | `4`          | The user's client supports receiving written messages in GIF (Graphics Interchange Format). |
| `0x00000008`  | `8`          | The user's client supports sending and receiving written messages in ISF (Ink Serialized Format). |
| `0x00000010`  | `16`         | The user has a webcam and is sharing the information that they have one. |
| `0x00000020`  | `32`         | The user's client supports messages sent over multiple packets. |
| `0x00000040`  | `64`         | The user can be messaged via their mobile device. |
| `0x00000080`  | `128`        | The user can be messaged via their Web Watch. |
| `0x00000100`  | `256`        | ? |
| `0x00000200`  | `512`        | The user is on a web-based client. |
| `0x00000400`  | `1024`       | ? |
| `0x00000800`  | `2048`       | The user is using Microsoft Office Communicator via a cross-platform gateway. |
| `0x00001000`  | `4096`       | The user has a blog. |
| `0x00002000`  | `8192`       | The user is using a media center client. |
| `0x00004000`  | `16384`      | The user's client supports opening a direct connection for instant messaging. |
| `0x00008000`  | `32768`      | The user's client supports sending and receiving Winks (flash animations). |
| `0x00010000`  | `65536`      | The user's client supports the shared search feature. |
| `0x00020000`  | `131072`     | This client is using a provisioned user. (The user is a bot.) |
| `0x00040000`  | `262144`     | The user's client supports sending and receiving Voice Clips. |
| `0x00080000`  | `524288`     | The user's client supports encrypted conversations. |
| `0x00100000`  | `1048576`    | ... |
| `0x00200000`  | `2097152`    | ... |
| `0x00400000`  | `4194304`    | The user's client supports sharing folders. |
| `0x00800000`  | `8388608`    | ... |
| `0x01000000`  | `16777216`   | ... |
| `0x02000000`  | `33554432`   | ... |
| `0x04000000`  | `67108864`   | ... |
| `0x08000000`  | `134217728`  | ... |
| `0x10000000`  | `268435456`  | The user's client supports MSNC1.            (Client Version 6.0+)  |
| `0x20000000`  | `536870912`  | The user's client supports MSNC2 and below.  (Client Version 6.1+)  |
| `0x30000000`  | `805306368`  | The user's client supports MSNC3 and below.  (Client Version 6.2+)  |
| `0x40000000`  | `1073741824` | The user's client supports MSNC4 and below.  (Client Version 7.0+)  |
| `0x50000000`  | `1342177280` | The user's client supports MSNC5 and below.  (Client Version 7.5+)  |
| `0x60000000`  | `1610612736` | The user's client supports MSNC6 and below.  (Client Version 8.0+)  |
| `0x70000000`  | `1879048192` | The user's client supports MSNC7 and below.  (Client Version 8.1+)  |
| `0x80000000`  | `2147483648` | The user's client supports MSNC8 and below.  (Client Version 8.5+)  |
| `0x90000000`  | `2415919104` | The user's client supports MSNC9 and below.  (Client Version 9.0+)  |
| `0xA0000000`  | `2684354560` | The user's client supports MSNC10 and below. (Client Version 14.0+) |
| `0xB0000000`  | `2952790016` | The user's client supports MSNC11 and below. (Client Version 14.1+) |
| `0xC0000000`  | `3221225472` | The user's client supports MSNC12 and below. (Client Version 15.0+) |
| `0xD0000000`  | `3489660928` | The user's client supports MSNC13 and below. |
| `0xE0000000`  | `3758096384` | The user's client supports MSNC14 and below. |
| `0xF0000000`  | `4026531840` | The user's client supports MSNC15 and below. |

# Extended Client Capabilities
*Since [MSNP16](../versions/msnp16.md).*

**TODO: this**

| `hexadecimal` | `decimal`    | meaning |
| ------------- | ------------ | ------- |
| `0x00000001`  | `1`          | ... |
