# Introduction
`QRY` is a command introduced with [MSNP6](../versions/msnp6.md).

It is a Notification Server command, WITH a request payload but without a response payload.

Responds to a challenge request ([CHL](chl.md) command).

# Client/Request
```
QRY TrID public-key length
payload
```

Where `public-key` is your client's Public Key.
For a list of valid Public Keys, read the [Challenge Key Pairs](../files/challenge_keypairs.md) article.

Where `length` is the size (in bytes) of the `payload`.

Where `payload` is the challenge response.

## Challenge responses
Calculating the challenge response depends on the version of the protocol you are using.

For a list of valid Private Keys, read the [Challenge Key Pairs](../files/challenge_keypairs.md) article.

### Basic responses
*Only in [MSNP6](../versions/msnp10.md) to [MSNP10](../versions/msnp10.md).*

Simply MD5 hash the challenge and your client's Private Key concatenated together as a string.

For an implementation of this, review `SolveMSNP6Challenge` in [`msnp_challenges.cs`](../files/msnp_challenges.cs.md).

The output should be 32 bytes and lowercase hexadecimal.

### Advanced responses
*Since [MSNP11](../versions/msnp11.md).*

1. MD5 hash the challenge and your client's Private Key concatenated together as a string.
2. Create an 32-bit integer array with the size of 4, with the contents being each part of the first step put through a bitwise AND of `0x7FFFFFFF`.
3. Concatenate the challenge and Public Key together and save as a new string.
4. Pad the string to the right if it's length can not be divided by 8.
5. Create a new 32-bit integer array with the size of the padded string's length divided by 4, with the contents being 4 bytes of the fourth step put through a bitwise AND of `0x7FFFFFFF`.
6. Initialize three 64-bit variables, one called `temp`, another called `high`, and the last called `low`.
7. In a loop, iterate the array made in step 5, and increase the iterator by 2 every pass.
    1. The `temp` variable should be set to the part of the array created in the fifth step indexed by the iterator.
    2. Multiply and set `temp` by `0x0E79A9C1`.
    3. Modulo (not bitwise AND) and set `temp` by `0x7FFFFFFF`.
    4. Add and set `temp` by the contents of `high`.
    5. Multiply and set `temp` by the first part of the array made in step 2.
    6. Add the value of the second part of the array made in step 2 to `temp`.
    7. Modulo and set `temp` by `0x7FFFFFFF`.
    8. Set `high` to the part of the array created in the fifth step indexed by the iterator plus 1.
    9. Add and set `high` to the value of `temp`.
    10. Modulo `high` by `0x7FFFFFFF`.
    11. Multiply and set `high` by the third part of the array made in step 2.
    12. Add and set `high` by the value of the fourth part of the array made in step 2.
    13. Modulo and set `high` by `0x7FFFFFFF`.
    14. Add and set `low` to the result of `high` and `temp` being added together.
8. We have now finished the loop.
9. Add and set `high` by the value of the second part of the array made in step 2.
10. Modulo `high` by `0x7FFFFFFF`.
11. Swap the endianness of the 32-bit segment of `high`.
12. Add and set `low` by the value of the fourth part of the array made in step 2.
13. Modulo `low` by `0x7FFFFFFF`.
14. Swap the endianness of the 32-bit segment of `low`.
15. Create a new 64-bit variable named key.
16. Set the value of key to the value of `high` shifted 32 bits to the left, and the value of `low`.
17. Swap the endianness of the entire 64-bit segment of `key`.
18. Create two new 64-bit variables, one `resultHigh`, and the other `resultLow`.
19. Set `resultHigh` to the first 64 bits of the value created in step 1.
20. Set `resultLow` to the last 64 bits of the value created in step 1.
21. Bitwise XOR and set `resultHigh` by the value of `key`.
22. Bitwise XOR and set `resultLow` by the value of `key`.
23. Concatenate the values of `resultHigh` and `resultLow` as a set of bytes.
24. Convert the concatenated values into a hex stream.

For an implementation of this, review `SolveMSNP11Challenge` in [`msnp_challenges.cs`](../files/msnp_challenges.cs.md).

The output should be 32 bytes and lowercase hexadecimal.

# Server/Response
`QRY TrID`

# Examples

## Successful response
```msnp
S: CHL 12345678901234567890
C: QRY 1 msmsgs@msnmsgr.com 32
8ba1bb9d6dbf624fee31a2053af5fdd0
S: QRY 1
```

## Failed challenge
*NOTE: This happens as-is in [MSNP11](../versions/msnp11.md),
since it isn't using the new method.*
```msnp
S: CHL 12345678901234567890
C: QRY 2 msmsgs@msnmsgr.com 32
8ba1bb9d6dbf624fee31a2053af5fdd0
S: 540 2
```
Server disconnects client.

# Known changes
* [MSNP11](../versions/msnp11.md): Changed challenge response generation algorithm drastically.
