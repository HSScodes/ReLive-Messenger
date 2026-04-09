import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Computes an MSNP11-style challenge response (used for both NS CHL and
/// OIM lockkey computation).
///
/// [challenge] – the nonce from the server (CHL nonce or LockKeyChallenge).
/// [productId] – the product identifier (e.g. `PROD0119GSJUC$18`).
/// [productKey] – the secret product key paired with [productId].
///
/// Returns a 32-character lowercase hex digest.
String computeMsnp11Challenge({
  required String challenge,
  required String productId,
  required String productKey,
}) {
  final digest = md5.convert(utf8.encode('$challenge$productKey')).bytes;

  int readLe32(List<int> bytes, int offset) {
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  final md5Ints = <int>[
    readLe32(digest, 0) & 0x7fffffff,
    readLe32(digest, 4) & 0x7fffffff,
    readLe32(digest, 8) & 0x7fffffff,
    readLe32(digest, 12) & 0x7fffffff,
  ];

  final challengeBytes = utf8.encode('$challenge$productId');
  final paddedLength = ((challengeBytes.length + 7) ~/ 8) * 8;
  final padded = List<int>.filled(paddedLength, 0x30);
  for (var i = 0; i < challengeBytes.length; i += 1) {
    padded[i] = challengeBytes[i];
  }

  final chlInts = <int>[];
  for (var i = 0; i < padded.length; i += 4) {
    chlInts.add(readLe32(padded, i));
  }

  var high = 0;
  var low = 0;
  const modulo = 0x7fffffff;

  for (var i = 0; i < chlInts.length - 1; i += 2) {
    final temp = (md5Ints[0] * chlInts[i] + md5Ints[1]) % modulo;
    high = (md5Ints[2] * temp + md5Ints[3]) % modulo;
    low = (low + high + temp) % modulo;
  }

  high = (high + md5Ints[1]) % modulo;
  low = (low + md5Ints[3]) % modulo;

  final keyInts = <int>[
    (readLe32(digest, 0) ^ high) & 0xffffffff,
    (readLe32(digest, 4) ^ low) & 0xffffffff,
    (readLe32(digest, 8) ^ high) & 0xffffffff,
    (readLe32(digest, 12) ^ low) & 0xffffffff,
  ];

  final out = <int>[];
  for (final value in keyInts) {
    out.add(value & 0xff);
    out.add((value >> 8) & 0xff);
    out.add((value >> 16) & 0xff);
    out.add((value >> 24) & 0xff);
  }

  final buffer = StringBuffer();
  for (final byte in out) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
