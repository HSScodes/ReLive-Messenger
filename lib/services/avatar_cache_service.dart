import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent cache for contact display pictures.
///
/// Storage layout (SharedPreferences):
///   avatar_path_{email}   – absolute path to the local file
///   avatar_sha1d_{email}  – SHA1D from the MSN object at fetch time
///   avatar_ts_{email}     – epoch millis of last successful fetch
///
/// Files are stored in app documents (survives app restarts; not temp-cleared).
class AvatarCacheService {
  static const Duration _maxAge = Duration(days: 7);

  // Prefix constants
  static const _kPath = 'avatar_path_';
  static const _kSha1d = 'avatar_sha1d_';
  static const _kTs = 'avatar_ts_';

  // In-memory runtime maps populated on init()
  final Map<String, String> _ram = {};
  final Map<String, String> _sha1dRam = {};

  // ── init ────────────────────────────────────────────────────────────────

  /// Loads all persisted entries whose files still exist into the runtime maps.
  /// Call once during app startup (e.g. in ContactsNotifier.build).
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_kPath)) continue;
      final email = key.substring(_kPath.length);
      final path = prefs.getString(key);
      if (path != null && File(path).existsSync()) {
        _ram[email] = path;
        final sha1d = prefs.getString('$_kSha1d$email');
        if (sha1d != null && sha1d.isNotEmpty) {
          _sha1dRam[email] = sha1d;
        }
      } else if (path != null) {
        // Stale entry – prune keys
        await prefs.remove('$_kPath$email');
        await prefs.remove('$_kSha1d$email');
        await prefs.remove('$_kTs$email');
      }
    }
  }

  // ── read ────────────────────────────────────────────────────────────────

  /// All in-memory entries (email → local path) after [init] completes.
  Map<String, String> get entries => Map.unmodifiable(_ram);

  /// Sync sha1d stored for [email] in the runtime map (available after init).
  String? getStoredSha1d(String email) => _sha1dRam[email.toLowerCase()];

  /// Synchronous runtime-cache lookup (available after init()).
  String? getSync(String email) => _ram[email.toLowerCase()];

  /// Full async lookup.
  ///
  /// Returns a local path when the cached entry is still valid:
  ///  - The file exists on disk, AND
  ///  - Either [currentSha1d] matches the stored sha1d (if provided), OR
  ///    the entry is younger than [_maxAge] (fallback when sha1d is absent).
  Future<String?> get(String email, {String? currentSha1d}) async {
    final key = email.toLowerCase();
    final path = _ram[key];
    if (path == null || !File(path).existsSync()) {
      _ram.remove(key);
      return null;
    }

    if (currentSha1d != null && currentSha1d.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('$_kSha1d$key');
      if (stored == currentSha1d) return path;
      // SHA1D changed – stale
      return null;
    }

    // No sha1d provided – fall back to age check
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt('$_kTs$key');
    if (ts != null) {
      final age = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(ts));
      if (age < _maxAge) return path;
    }
    return null;
  }

  // ── write ───────────────────────────────────────────────────────────────

  Future<void> save(String email, String localPath, {String? sha1d}) async {
    final key = email.toLowerCase();
    _ram[key] = localPath;
    if (sha1d != null && sha1d.isNotEmpty) {
      _sha1dRam[key] = sha1d;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kPath$key', localPath);
    if (sha1d != null && sha1d.isNotEmpty) {
      await prefs.setString('$_kSha1d$key', sha1d);
    }
    await prefs.setInt('$_kTs$key',
        DateTime.now().millisecondsSinceEpoch);
  }

  // ── Crosstalk directory fetch ────────────────────────────────────────────

  /// Tries to download the display picture from the CrossTalk directory.
  ///
  /// CrossTalk stores the last avatar chosen in the desktop client under
  /// the standard MSN usertile path. We try several candidate URLs.
  Future<String?> fetchFromCrosstalkDirectory(String email) async {
    final emailEnc = Uri.encodeComponent(email.toLowerCase());
    final candidates = <Uri>[
      // Standard MSN MSNP usertile path – most likely to work
      Uri.parse(
          'https://www.crosstalk.im/storage/usertile/$emailEnc/DisplayPicture'),
      Uri.parse(
          'http://crosstalk.im/storage/usertile/$emailEnc/DisplayPicture'),
      Uri.parse(
          'https://www.crosstalk.im/usertile/$emailEnc/DisplayPicture'),
      // Alternative paths observed in CrossTalk traffic
      Uri.parse('https://www.crosstalk.im/avatar/$emailEnc'),
      Uri.parse('https://www.crosstalk.im/displaypic/$emailEnc'),
      Uri.parse('https://www.crosstalk.im/directory/$emailEnc/avatar'),
    ];

    for (final uri in candidates) {
      final bytes = await _get(uri);
      if (bytes != null) {
        return _saveBytesToDocuments(email, bytes);
      }
    }
    return null;
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  Future<List<int>?> _get(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 8));
      request.headers
        ..set(HttpHeaders.userAgentHeader, 'MSMSGS')
        ..set('Accept', 'image/*');
      final response =
          await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final bytes = await response
          .fold<List<int>>(<int>[], (buf, chunk) {
        buf.addAll(chunk);
        return buf;
      });
      // Minimum sanity: at least a 50-byte file, and starts with
      // a known image magic number.
      if (bytes.length > 50 && _isImage(bytes)) return bytes;
      return null;
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _saveBytesToDocuments(
      String email, List<int> bytes) async {
    final dir = await _cacheDir();
    final ext = _ext(bytes);
    final safe = email.replaceAll(RegExp(r'[^a-zA-Z0-9._@-]'), '_');
    final file = File(
        '${dir.path}${Platform.pathSeparator}dir_$safe.$ext');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<Directory> _cacheDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir =
        Directory('${root.path}${Platform.pathSeparator}wlm_avatars');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  bool _isImage(List<int> b) {
    if (b.length < 4) return false;
    // PNG
    if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
      return true;
    }
    // JPEG
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return true;
    // GIF
    if (b.length >= 6) {
      final h = String.fromCharCodes(b.take(6));
      if (h == 'GIF87a' || h == 'GIF89a') return true;
    }
    // BMP
    if (b[0] == 0x42 && b[1] == 0x4D) return true;
    return false;
  }

  String _ext(List<int> b) {
    if (b.length >= 4 &&
        b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
      return 'png';
    }
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
      return 'jpg';
    }
    return 'bin';
  }
}
