import 'dart:io';

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
    final pathKeys = prefs
        .getKeys()
        .where((k) => k.startsWith(_kPath))
        .toList();
    for (final key in pathKeys) {
      final email = key.substring(_kPath.length);
      final path = prefs.getString(key);
      if (path == null) continue;
      final exists = await File(path).exists();
      if (exists) {
        _ram[email] = path;
        final sha1d = prefs.getString('$_kSha1d$email');
        if (sha1d != null && sha1d.isNotEmpty) {
          _sha1dRam[email] = sha1d;
        }
      } else {
        // File is gone — prune the path and timestamp, but KEEP the SHA1D
        // so the system knows which avatar to re-fetch on next presence.
        await prefs.remove('$_kPath$email');
        await prefs.remove('$_kTs$email');
        final sha1d = prefs.getString('$_kSha1d$email');
        if (sha1d != null && sha1d.isNotEmpty) {
          _sha1dRam[email] = sha1d;
        }
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
    if (path == null || !(await File(path).exists())) {
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
        DateTime.fromMillisecondsSinceEpoch(ts),
      );
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
    await prefs.setInt('$_kTs$key', DateTime.now().millisecondsSinceEpoch);
  }
}
