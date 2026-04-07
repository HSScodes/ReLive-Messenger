import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

class ParsedMsnObject {
  const ParsedMsnObject({this.url, this.sha1d, this.location, this.creator});

  final String? url;
  final String? sha1d;
  final String? location;
  final String? creator;
}

class MsnObjectService {
  final Map<String, String> _cacheByKey = <String, String>{};

  Future<String?> fetchAndCacheAvatarFromIdentity({
    required String host,
    required String creator,
    required String sha1d,
    required String authTicket,
  }) async {
    // Delegate to the MSNP client's raw-socket HTTP fetch via the shared cache.
    final cacheKey = sha1d.trim();
    final hit = _cacheByKey[cacheKey];
    if (hit != null && File(hit).existsSync()) {
      return hit;
    }
    return null;
  }

  Future<String?> fetchAndCacheAvatar({
    required String host,
    required String authTicket,
    required String avatarMsnObject,
  }) async {
    final parsed = parseAvatarMsnObject(avatarMsnObject);
    if (parsed == null) {
      _log('MSN object parse failed.');
      return null;
    }

    final cacheKey = (parsed.sha1d ?? parsed.url ?? avatarMsnObject).trim();
    final hit = _cacheByKey[cacheKey];
    if (hit != null && File(hit).existsSync()) {
      return hit;
    }

    final candidateUris = _candidateAvatarUris(parsed: parsed, host: host);
    const maxAttempts = 48;
    final attemptUris = candidateUris.take(maxAttempts).toList(growable: false);
    final startedAt = DateTime.now();
    const overallDeadline = Duration(seconds: 14);
    _log(
      'Avatar fetch try: candidates=${candidateUris.length}, trying=${attemptUris.length}, '
      'creator=${parsed.creator ?? '-'}, sha1d=${parsed.sha1d ?? '-'}',
    );
    List<int>? bytes;
    Uri? successUri;
    var attempts = 0;
    for (final uri in attemptUris) {
      attempts += 1;
      if (DateTime.now().difference(startedAt) > overallDeadline) {
        _log('Avatar fetch deadline reached (${overallDeadline.inSeconds}s).');
        break;
      }
      final result = await _downloadBytes(uri: uri, authTicket: authTicket);
      if (attempts <= 8) {
        final status =
            result.statusCode?.toString() ??
            (result.timedOut ? 'timeout' : 'error');
        _log(
          'Avatar probe #$attempts -> ${uri.path}${uri.hasQuery ? '?${uri.query}' : ''} [$status]',
        );
      }
      bytes = result.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        successUri = uri;
        break;
      }
    }
    if (bytes == null || bytes.isEmpty) {
      _log(
        'Avatar fetch failed after ${attemptUris.length} attempts '
        'for creator=${parsed.creator ?? '-'} sha1d=${parsed.sha1d ?? '-'} '
        'elapsed=${DateTime.now().difference(startedAt).inMilliseconds}ms',
      );
      return null;
    }

    final cacheDir = await _avatarCacheDir();
    final extension = _guessExtension(bytes);
    final filename =
        '${md5.convert(utf8.encode(cacheKey)).toString()}.$extension';
    final file = File('${cacheDir.path}${Platform.pathSeparator}$filename');
    await file.writeAsBytes(bytes, flush: true);

    _cacheByKey[cacheKey] = file.path;
    _log('Avatar fetch success via ${successUri ?? '-'} -> ${file.path}');
    return file.path;
  }

  ParsedMsnObject? parseAvatarMsnObject(String rawMsnObject) {
    final trimmed = rawMsnObject.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    String? attr(String name) {
      final regex = RegExp('$name="([^"]+)"', caseSensitive: false);
      final match = regex.firstMatch(trimmed);
      if (match == null) {
        return null;
      }
      // MSNObject attributes are plain text inside XML — no URL decoding.
      return match.group(1);
    }

    final url =
        attr('Url') ?? attr('URL') ?? attr('AvatarUrl') ?? attr('ContentUrl');
    final sha1d = attr('SHA1D');
    final location = attr('Location');
    final creator = attr('Creator');

    return ParsedMsnObject(
      url: url,
      sha1d: sha1d,
      location: location,
      creator: creator,
    );
  }

  Future<_DownloadResult> _downloadBytes({
    required Uri uri,
    required String authTicket,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 900);

    try {
      final variants = <Map<String, String>>[
        <String, String>{HttpHeaders.cookieHeader: 'MSPAuth=$authTicket'},
        <String, String>{'Authorization': 'Passport1.4 t=$authTicket'},
        <String, String>{},
      ];

      for (final headers in variants) {
        final request = await client
            .getUrl(uri)
            .timeout(const Duration(milliseconds: 900));
        for (final entry in headers.entries) {
          request.headers.set(entry.key, entry.value);
        }
        request.headers.set(HttpHeaders.userAgentHeader, 'MSMSGS');

        final response = await request.close().timeout(
          const Duration(milliseconds: 900),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          if (response.statusCode == 401 ||
              response.statusCode == 403 ||
              response.statusCode == 404) {
            return _DownloadResult(statusCode: response.statusCode);
          }
          continue;
        }

        final bytes = await response.fold<List<int>>(<int>[], (buffer, chunk) {
          buffer.addAll(chunk);
          return buffer;
        });
        if (bytes.isNotEmpty) {
          return _DownloadResult(bytes: bytes, statusCode: response.statusCode);
        }
      }

      return const _DownloadResult();
    } on TimeoutException {
      return const _DownloadResult(timedOut: true);
    } on SocketException {
      return const _DownloadResult();
    } catch (_) {
      return const _DownloadResult();
    } finally {
      client.close(force: true);
    }
  }

  Uri? _coerceUri(String source, String host) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final parsed = Uri.tryParse(trimmed);
    if (parsed == null) {
      return null;
    }

    if (parsed.hasScheme) {
      return parsed;
    }

    if (trimmed.startsWith('/')) {
      return Uri(scheme: 'http', host: host, port: 80, path: trimmed);
    }

    return Uri(scheme: 'http', host: host, port: 80, path: '/$trimmed');
  }

  List<Uri> _candidateAvatarUris({
    required ParsedMsnObject parsed,
    required String host,
  }) {
    final uris = <Uri>[];
    final direct = parsed.url;
    if (direct != null && direct.isNotEmpty) {
      final parsedUri = _coerceUri(direct, host);
      if (parsedUri != null) {
        uris.add(parsedUri);
      }
    }

    final sha1d = parsed.sha1d;
    final creator = parsed.creator;
    final location = parsed.location;

    // CrossTalk canonical path: /crosstalk/{euf-guid-suffix}/{url-encoded-sha1d}
    // Discovered via Wireshark dump of real WLM 14 traffic.
    // MUST use crosstalk.im hostname (not raw IP) for correct Host header.
    // MUST use lowercase percent-encoding to match the official client exactly.
    if (sha1d != null && sha1d.isNotEmpty) {
      const eufSuffix = 'F126696BDBF6';
      final encodedSha = Uri.encodeComponent(sha1d)
          .replaceAll('%2F', '%2f')
          .replaceAll('%3D', '%3d')
          .replaceAll('%2B', '%2b');
      uris.add(
        Uri.parse('http://crosstalk.im/crosstalk/$eufSuffix/$encodedSha'),
      );
    }

    void addPath(String path) {
      uris.add(Uri(scheme: 'http', host: host, port: 80, path: path));
      if (host != 'crosstalk.im') {
        uris.add(Uri(scheme: 'https', host: 'crosstalk.im', path: path));
        uris.add(
          Uri(scheme: 'http', host: 'crosstalk.im', port: 80, path: path),
        );
      } else {
        uris.add(Uri(scheme: 'https', host: host, path: path));
      }
    }

    void addQueryPath(String path, Map<String, String> query) {
      uris.add(
        Uri(
          scheme: 'http',
          host: host,
          port: 80,
          path: path,
          queryParameters: query,
        ),
      );
      if (host != 'crosstalk.im') {
        uris.add(
          Uri(
            scheme: 'https',
            host: 'crosstalk.im',
            path: path,
            queryParameters: query,
          ),
        );
        uris.add(
          Uri(
            scheme: 'http',
            host: 'crosstalk.im',
            port: 80,
            path: path,
            queryParameters: query,
          ),
        );
      } else {
        uris.add(
          Uri(scheme: 'https', host: host, path: path, queryParameters: query),
        );
      }
    }

    final shaVariants = _shaVariants(sha1d);
    if (shaVariants.isNotEmpty) {
      for (final token in shaVariants) {
        final enc = Uri.encodeComponent(token);
        addPath('/storage/avatar/$enc');
        addPath('/avatar/$enc');
        addPath('/avatars/$enc');
        addPath('/displaypic/$enc');
        addPath('/displaypicture/$enc');
      }
      addQueryPath('/storage/avatar', <String, String>{'sha1d': sha1d!});
      addQueryPath('/storage/avatar', <String, String>{'sha1': sha1d});
      addQueryPath('/storage/avatar', <String, String>{'hash': sha1d});
    }

    if (creator != null && creator.isNotEmpty) {
      final creatorEnc = Uri.encodeComponent(creator.toLowerCase());
      addPath('/storage/avatar/$creatorEnc');
      addPath('/avatar/$creatorEnc');
      addPath('/displaypic/$creatorEnc');

      for (final token in shaVariants) {
        final enc = Uri.encodeComponent(token);
        addPath('/storage/avatar/$creatorEnc/$enc');
        addPath('/avatar/$creatorEnc/$enc');
        addPath('/displaypic/$creatorEnc/$enc');
      }

      if (sha1d != null && sha1d.isNotEmpty) {
        addQueryPath('/storage/avatar', <String, String>{
          'creator': creator,
          'sha1d': sha1d,
        });
        addQueryPath('/avatar', <String, String>{
          'creator': creator,
          'sha1d': sha1d,
        });
        addQueryPath('/displaypic', <String, String>{
          'creator': creator,
          'sha1d': sha1d,
        });
      }

      if (location != null && location.isNotEmpty) {
        final locationEnc = Uri.encodeComponent(location);
        addPath('/storage/avatar/$creatorEnc/$locationEnc');
        addPath('/displaypic/$creatorEnc/$locationEnc');
      }
    }

    // Deduplicate preserving order.
    final seen = <String>{};
    final deduped = <Uri>[];
    for (final uri in uris) {
      final key = uri.toString();
      if (seen.contains(key)) {
        continue;
      }
      seen.add(key);
      deduped.add(uri);
    }
    return deduped;
  }

  List<String> _shaVariants(String? sha1d) {
    if (sha1d == null || sha1d.trim().isEmpty) {
      return const <String>[];
    }
    final raw = sha1d.trim();
    final variants = <String>{raw};
    try {
      final normalized = _normalizeBase64(raw);
      final bytes = base64.decode(normalized);
      final hexLower = bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      variants.add(hexLower);
      variants.add(hexLower.toUpperCase());
      final b64Url = base64Url.encode(bytes).replaceAll('=', '');
      variants.add(b64Url);
    } catch (_) {
      // Keep raw only when SHA1D is not strict base64.
    }
    return variants.toList(growable: false);
  }

  String _normalizeBase64(String input) {
    var value = input.replaceAll('-', '+').replaceAll('_', '/');
    final rem = value.length % 4;
    if (rem != 0) {
      value += '=' * (4 - rem);
    }
    return value;
  }

  Future<Directory> _avatarCacheDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}${Platform.pathSeparator}wlm_avatars');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _guessExtension(List<int> bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }

    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'jpg';
    }

    if (bytes.length >= 6) {
      final head = ascii.decode(bytes.take(6).toList(), allowInvalid: true);
      if (head == 'GIF87a' || head == 'GIF89a') {
        return 'gif';
      }
    }

    return 'bin';
  }

  void _log(String message) {
    // ignore: avoid_print
    print('[AVATAR] $message');
  }

  /// Generates an MSNObject XML string for a local avatar file.
  /// Returns null if the file doesn't exist or can't be read.
  ///
  /// The MSNObject format for display pictures (Type=3):
  /// <msnobj Creator="user@example.com" Type="3" SHA1D="base64hash"
  ///   Size="filesize" Location="0" Friendly="base64name"/>
  Future<String?> generateMsnObjectXml({
    required String creatorEmail,
    required String avatarFilePath,
    String? friendlyName,
  }) async {
    try {
      final file = File(avatarFilePath);
      if (!file.existsSync()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;

      // SHA1D: SHA-1 hash of the file bytes, base64-encoded
      final sha1Hash = sha1.convert(bytes);
      final sha1d = base64.encode(sha1Hash.bytes);

      // Friendly: display name in UTF-16LE, then base64-encoded
      final friendly = friendlyName ?? creatorEmail;
      final utf16leBytes = <int>[];
      for (final codeUnit in friendly.codeUnits) {
        utf16leBytes.add(codeUnit & 0xFF);
        utf16leBytes.add((codeUnit >> 8) & 0xFF);
      }
      // Null terminator
      utf16leBytes.addAll([0, 0]);
      final friendlyB64 = base64.encode(utf16leBytes);

      // Build MSNObject matching the attribute order real WLM 2009 uses:
      //   Creator, Size, Type, Location, Friendly, SHA1D, SHA1C [, contenttype]
      // For animated GIFs (Dynamic Display Pictures), WLM 2009 includes
      // contenttype="D" so peers know to render the image as animated.
      final isGif =
          bytes.length >= 6 &&
          bytes[0] == 0x47 && // G
          bytes[1] == 0x49 && // I
          bytes[2] == 0x46; // F

      // Build XML without SHA1C first, then compute SHA1C from it.
      // Attribute order matches real WLM 2009: Creator, Type, SHA1D, Size,
      // Location, Friendly (then optional SHA1C, contenttype).
      final xmlNoC =
          '<msnobj Creator="${_xmlEsc(creatorEmail)}" '
          'Type="3" '
          'SHA1D="$sha1d" '
          'Size="${bytes.length}" '
          'Location="0" '
          'Friendly="$friendlyB64"'
          '${isGif ? ' contenttype="D"' : ''}/>';

      // SHA1C: SHA-1 hash of the XML string (without SHA1C), base64-encoded
      final sha1c = base64.encode(sha1.convert(utf8.encode(xmlNoC)).bytes);

      final xml =
          '<msnobj Creator="${_xmlEsc(creatorEmail)}" '
          'Type="3" '
          'SHA1D="$sha1d" '
          'Size="${bytes.length}" '
          'Location="0" '
          'Friendly="$friendlyB64" '
          'SHA1C="$sha1c"'
          '${isGif ? ' contenttype="D"' : ''}/>';
      _log(
        'Generated MSNObject: sha1d=$sha1d sha1c=$sha1c size=${bytes.length}'
        '${isGif ? ' contenttype=D' : ''}',
      );
      return xml;
    } catch (e) {
      _log('Failed to generate MSNObject: $e');
      return null;
    }
  }

  /// Computes just the SHA1D for a local avatar file.
  Future<String?> computeAvatarSha1d(String avatarFilePath) async {
    try {
      final file = File(avatarFilePath);
      if (!file.existsSync()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      return base64.encode(sha1.convert(bytes).bytes);
    } catch (_) {
      return null;
    }
  }

  static String _xmlEsc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

class _DownloadResult {
  const _DownloadResult({this.bytes, this.statusCode, this.timedOut = false});

  final List<int>? bytes;
  final int? statusCode;
  final bool timedOut;
}
