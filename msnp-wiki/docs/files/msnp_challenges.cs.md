# File Information
This is a file that contains implementations of the
[MSNP6](../versions/msnp6.md) and [MSNP11](../versions/msnp11.md) challenges,
and the [SSO](../commands/usr.md#using-sso) authentication method's response.

Filename: `msnp_challenges.cs`.

# File contents
```cs
//  Copyright 2025-2025 yellows111
//
//  Permission is hereby granted, free of charge, to any person obtaining a 
//  copy of this software and associated documentation files (the "Software"), 
//  to deal in the Software without restriction, including without limitation 
//  the rights to use, copy, modify, merge, publish, distribute, sublicense, 
//  and/or sell copies of the Software, and to permit persons to whom the 
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in 
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS 
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
//  DEALINGS IN THE SOFTWARE.

using System;
using System.Security.Cryptography;
using System.Text;
using yellowsoneoneone;

namespace yellowsoneoneone {
	public class MSNPChallenges {
		// used for challenge + privateKey concat hash
		private static MD5 md5 = MD5.Create();
		// swap bytes of a unsigned int stored as a long.
		private static long SwapEndianness32(long num) {
			byte[] intBytes = BitConverter.GetBytes(num);
			byte[] newBytes = new byte[8] {
				intBytes[3], intBytes[2], intBytes[1], intBytes[0],
				0, 0, 0, 0
			};
			return BitConverter.ToInt64(newBytes, 0);
		}
		// swap all bytes of a long.
		private static long SwapEndianness64(long num) {
			byte[] intBytes = BitConverter.GetBytes(num);
			byte[] newBytes = new byte[8] {
				intBytes[7], intBytes[6], intBytes[5], intBytes[4],
				intBytes[3], intBytes[2], intBytes[1], intBytes[0]
			};
			return BitConverter.ToInt64(newBytes, 0);
		}
		// solve the MSNP6 to MSNP10 QRY response.
		public static string SolveMSNP6Challenge(string privateKey, string challenge) {
			return BitConverter.ToString(
				md5.ComputeHash(
					Encoding.ASCII.GetBytes(challenge + privateKey)
				)
			).Replace("-", "").ToLower();
		}
		// solve the MSNP11 to MSNP21 QRY response.
		public static string SolveMSNP11Challenge(string publicKey, string privateKey, string challenge) {
			// part 1 -- private seed
			byte[] initialConstant = md5.ComputeHash(Encoding.ASCII.GetBytes(challenge + privateKey));
			int[] privateSeed = new int[4];
			for(int i = 0; i < 4; i++) {
				privateSeed[i] = BitConverter.ToInt32(initialConstant, i * 4) & 0x7FFFFFFF;
			}

			//part 2 -- public seed
			string publicString = challenge + publicKey;
			publicString = publicString.PadRight(publicString.Length + (8 - publicString.Length % 8), '0');
			byte[] publicBytes = Encoding.ASCII.GetBytes(publicString);
			int[] publicSeed = new int[publicString.Length / 4];
			for(int i = 0; i < publicSeed.Length; i++) {
				publicSeed[i] = BitConverter.ToInt32(publicBytes, i * 4) & 0x7FFFFFFF;
			}

			// part 3 -- key generation, the modulos instead of bitwise AND is intentional here
			long temp = 0, high = 0, low = 0;
			for (int i = 0; i < publicSeed.Length; i += 2) {
				temp = publicSeed[i];
				temp = ((temp * 0x0E79A9C1) % 0x7FFFFFFF) + high;
				temp = ((temp * privateSeed[0]) + privateSeed[1]) % 0x7FFFFFFF;

				high = (publicSeed[i + 1] + temp) % 0x7FFFFFFF;
				high = ((high * privateSeed[2]) + privateSeed[3]) % 0x7FFFFFFF;

				low += high + temp;
			}
			// by the way, requiring endian swaps isn't documentated on MSNPiki.
			// This sucked to figure out.
			high = SwapEndianness32((high + privateSeed[1]) % 0x7FFFFFFF);
			low = SwapEndianness32((low + privateSeed[3]) % 0x7FFFFFFF);
			long key = SwapEndianness64((high << 32) + low);

			// part 4 -- Bitwise XOR the original MD5 with our new key
			long resultHigh = BitConverter.ToInt64(initialConstant, 0) ^ key;
			long resultLow = BitConverter.ToInt64(initialConstant, 8) ^ key;
			return (
				BitConverter.ToString(BitConverter.GetBytes(resultHigh)) +
				BitConverter.ToString(BitConverter.GetBytes(resultLow))
			).Replace("-", "").ToLower();
		}
	}
	public class AuthChallenges {
		private static byte[] hashConstant = Encoding.ASCII.GetBytes(
			"WS-SecureConversationSESSION KEY HASH"
		);
		private static byte[] encryptionConstant = Encoding.ASCII.GetBytes(
			"WS-SecureConversationSESSION KEY ENCRYPTION"
		);
		// solve the MBI_KEY_OLD challenge used in MSNP15 to MSNP21.
		public static string SolveSSOChallenge(string binarySecretString, string nonceString, string ivString) {
			// sanity check
			if(binarySecretString.Length != 32) {
				throw new Exception("binarySecret is the wrong size! It should be 32 characters.");
			};
			if(nonceString.Length != 64) {
				throw new Exception("nonce is the wrong size! It should be 64 characters.");
			};
			if(ivString.Length != 12) {
				throw new Exception("iv is the wrong size! It should be 12 characters.");
			};

			// place initial values into buffers
			byte[] nonce = new byte[64];
			Buffer.BlockCopy(Encoding.ASCII.GetBytes(nonceString), 0, nonce, 0, 64);
			byte[] binarySecret = Convert.FromBase64String(binarySecretString);
			if(binarySecret.Length != 24) {
				throw new Exception("binarySecret isn't 24 bytes! Is it truncated?");
			}
			byte[] iv = Convert.FromBase64String(ivString);
			if(iv.Length != 8) {
				throw new Exception("iv isn't 8 bytes! Is it truncated?");
			}

			// key1 -- Session Key Hash
			// byte[] key1 = binarySecret;
			HMACSHA1 hmKey1 = new HMACSHA1(binarySecret);
			byte[] hash1 = hmKey1.ComputeHash(hashConstant);
			byte[] hash1constant = new byte[57];
			Buffer.BlockCopy(hash1, 0, hash1constant, 0, 20);
			Buffer.BlockCopy(hashConstant, 0, hash1constant, 20, 37);
			byte[] hash2 = hmKey1.ComputeHash(hash1constant);
			byte[] hash3 = hmKey1.ComputeHash(hash1);
			byte[] hash3constant = new byte[57];
			Buffer.BlockCopy(hash3, 0, hash3constant, 0, 20);
			Buffer.BlockCopy(hashConstant, 0, hash3constant, 20, 37);
			byte[] hash4 = hmKey1.ComputeHash(hash3constant);

			// key2 -- Session Key Encryption
			byte[] key2 = new byte[24];
			Buffer.BlockCopy(hash2, 0, key2, 0, 20);
			Buffer.BlockCopy(hash4, 0, key2, 20, 4);
			byte[] hash5 = hmKey1.ComputeHash(encryptionConstant);
			byte[] hash5constant = new byte[63];
			Buffer.BlockCopy(hash5, 0, hash5constant, 0, 20);
			Buffer.BlockCopy(encryptionConstant, 0, hash5constant, 20, 43);
			byte[] hash6 = hmKey1.ComputeHash(hash5constant);
			byte[] hash7 = hmKey1.ComputeHash(hash5);
			byte[] hash7constant = new byte[63];
			Buffer.BlockCopy(hash7, 0, hash7constant, 0, 20);
			Buffer.BlockCopy(encryptionConstant, 0, hash7constant, 20, 43);
			byte[] hash8 = hmKey1.ComputeHash(hash7constant);

			// key3 -- We're done with SHA1-HMAC.
			byte[] key3 = new byte[24];
			Buffer.BlockCopy(hash6, 0, key3, 0, 20);
			Buffer.BlockCopy(hash8, 0, key3, 20, 4);
			byte[] hash9 = (new HMACSHA1(key2)).ComputeHash(nonce);

			// setup buffer for 3DES
			byte[] inputBuffer = new byte[72];
			for (int i = 64; i < 72; i++) {
				inputBuffer[i] = 8;
			}
			Buffer.BlockCopy(nonce, 0, inputBuffer, 0, 64);

			// generate 3DES-CBC ciphertext
			TripleDES threedescbc = TripleDES.Create();
			threedescbc.Mode = CipherMode.CBC;
			ICryptoTransform threedesenc = threedescbc.CreateEncryptor(key3, iv);
			byte[] ciph = threedesenc.TransformFinalBlock(inputBuffer, 0, 64);

			// define encryption header
			byte[] header = new byte[28] {
				28,      0,       0,    0, // 28 bytes for this header
				1,       0,       0,    0, // using CBC
				0x03,    0x66,    0,    0, // 3DES
				0x04,    0x80,    0,    0, // SHA1
				8,       0,       0,    0, // IV length
				20,      0,       0,    0, // hash length
				72,      0,       0,    0, // cipher data length
			};

			// pack everything together
			byte[] result = new byte[128];
			Buffer.BlockCopy(header, 0, result, 0, 28);
			Buffer.BlockCopy(iv, 0, result, 28, 8);
			Buffer.BlockCopy(hash9, 0, result, 36, 20);
			Buffer.BlockCopy(ciph, 0, result, 56, 72);

			// and we're done
			return Convert.ToBase64String(result);
		}
		// get the IV of a SSO challenge response for use in SolveSSOChallenge
		// where you don't know what the other party generates.
		public static string GetSSOIV(string ssoResponseString) {
			if(ssoResponseString.Length != 172) {
				throw new Exception("Input is the wrong size! Are you sure this is a SSO response?");
			}
			byte[] ssoResponse = Convert.FromBase64String(ssoResponseString);
			if(ssoResponse.Length != 128) {
				throw new Exception("The input isn't 128 bytes long... Are you sure this is a SSO response?");
			}
			byte[] result = new byte[8];
			Buffer.BlockCopy(ssoResponse, 28, result, 0, 8);
			return Convert.ToBase64String(result);
		}
	}
	// this class may be removed for any reason, it's only here so this has a reference implementation
	internal class Executable {
		public static void Main(string[] args) {
			if(args.Length == 0) {
				Console.WriteLine(
					"You need to specify the type of challenge...\n" +
					"Avaliable: MSNP6, MSNP11, MBI_KEY_OLD\n" +
					"Other features: GetSSOIV"
				);
				return;
			}
			switch(args[0]) {
				case "msnp6":
				case "MSNP6": {
					if(args.Length != 3) {
						Console.WriteLine(
							"Not enough arguments...\n" +
							"Expected private_key (Product key),\n" +
							"challenge (usually a number)"
						);
						return;
					}
					Console.WriteLine(MSNPChallenges.SolveMSNP6Challenge(args[1], args[2]));
					break;
				}
				case "msnp11":
				case "MSNP11": {
					if(args.Length != 4) {
						Console.WriteLine(
							"Not enough arguments...\n" +
							"Expected public_key (Client ID, usually begins with PROD...),\n" +
							"private_key (Product key),\n" +
							"challenge (usually a number)"
						);
						return;
					}
					Console.WriteLine(MSNPChallenges.SolveMSNP11Challenge(args[1], args[2], args[3]));
					break;
				}
				case "sso":
				case "SSO":
				case "MBI_KEY_OLD": {
					if(args.Length != 4) {
						Console.WriteLine(
							"Not enough arguments...\n" +
							"Expected binarySecret (as base64, 32 characters (24 bytes)),\n" +
							"nonce (as base64, 64 characters (48 bytes)),\n" +
							"iv (as base64, 12 characters (8 bytes))"
						);
						return;
					}
					Console.WriteLine(AuthChallenges.SolveSSOChallenge(args[1], args[2], args[3]));
					break;
				}
				case "GetSSOIV":
				case "getIV": {
					if(args.Length != 2) {
						Console.WriteLine(
							"Not enough arguments...\n" +
							"Expected SSOResponse (as base64, 172 characters (128 bytes))."
						);
						return;
					}
					Console.WriteLine(AuthChallenges.GetSSOIV(args[1]));
					break;
				}
				default: {
					Console.WriteLine(
						"Unknown mode: {0}.\n" +
						"Avaliable: MSNP6, MSNP11, MBI_KEY_OLD\n" +
						"Other features: GetSSOIV", args[0]
					);
					break;
				}
			}
			return;
		}
	}
}
```
