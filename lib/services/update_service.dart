import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

class UpdateCheckResult {
  final bool updateAvailable;
  final String? latestVersion;
  final String? currentVersion;

  const UpdateCheckResult({
    required this.updateAvailable,
    this.latestVersion,
    this.currentVersion,
  });
}

/// Checks the GitHub releases page for a newer version of reLive.
///
/// ── Versioning convention ──────────────────────────────────────────────
/// • pubspec.yaml version : MAJOR.MINOR.PATCH+BUILD  (e.g. 0.1.0+1)
/// • GitHub release tag   : vMAJOR.MINOR.PATCH       (e.g. v0.1.0)
/// • Progression          : v0.1.0 → v0.1.1 → v0.1.2 … v0.2.0 … v1.0.0
///
/// The checker reads the running app version via [PackageInfo] and
/// compares it numerically (major, minor, patch) against the GitHub tag.
/// Pre-release suffixes like "-alpha" are stripped before comparison.
class UpdateService {
  static const _owner = 'HSScodes';
  static const _repo = 'ReLive-Messenger';
  static const releasesUrl = 'https://github.com/$_owner/$_repo/releases';

  /// Fetch the running app version from [PackageInfo].
  static Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version; // e.g. "0.1.1"
  }

  /// Compare the installed version against the latest GitHub release.
  /// Checks all releases (including pre-releases like v0.1-alpha).
  static Future<UpdateCheckResult> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version; // e.g. "0.1.1"
      print('[UPDATE] Current version: $current');

      final client = HttpClient();
      // Use /releases (not /releases/latest) so pre-releases are included.
      final request = await client.getUrl(
        Uri.parse(
          'https://api.github.com/repos/$_owner/$_repo/releases?per_page=10',
        ),
      );
      request.headers.set('Accept', 'application/vnd.github.v3+json');
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );

      print('[UPDATE] GitHub API status: ${response.statusCode}');

      if (response.statusCode != 200) {
        await response.drain<void>();
        client.close();
        print('[UPDATE] GitHub API non-200, skipping update check');
        return UpdateCheckResult(
          updateAvailable: false,
          currentVersion: current,
        );
      }

      final body = await response.transform(utf8.decoder).join();
      client.close();

      final releases = jsonDecode(body) as List<dynamic>;
      if (releases.isEmpty) {
        print('[UPDATE] No releases found');
        return UpdateCheckResult(
          updateAvailable: false,
          currentVersion: current,
        );
      }

      // Find the newest release by comparing version numbers.
      String bestTag = '';
      List<int> bestVer = [0, 0, 0];
      for (final rel in releases) {
        final tag = ((rel as Map<String, dynamic>)['tag_name'] as String?) ?? '';
        final clean = tag.startsWith('v') ? tag.substring(1) : tag;
        final ver = _parseVersion(clean);
        if (ver.isEmpty) continue;
        if (bestTag.isEmpty || _isNewer2(ver, bestVer)) {
          bestTag = tag;
          bestVer = ver;
        }
      }

      if (bestTag.isEmpty) {
        print('[UPDATE] No valid version tags found');
        return UpdateCheckResult(
          updateAvailable: false,
          currentVersion: current,
        );
      }

      final latestClean = bestTag.startsWith('v')
          ? bestTag.substring(1)
          : bestTag;

      final isOutdated = _isNewer(latestClean, current);
      print('[UPDATE] Latest tag: $bestTag, current: $current, outdated: $isOutdated');

      return UpdateCheckResult(
        updateAvailable: isOutdated,
        latestVersion: bestTag,
        currentVersion: current,
      );
    } catch (e) {
      // Network error, timeout, parse error — stay silent.
      print('[UPDATE] Exception: $e');
      return const UpdateCheckResult(updateAvailable: false);
    }
  }

  /// Returns `true` when [a] is strictly newer than [b] (both parsed).
  static bool _isNewer2(List<int> a, List<int> b) {
    for (var i = 0; i < 3; i++) {
      if (a[i] > b[i]) return true;
      if (a[i] < b[i]) return false;
    }
    return false;
  }

  /// Returns `true` when [remote] is strictly newer than [local].
  ///
  /// Accepts "0.11", "0.11.0", or "0.1-alpha" style strings.
  /// Pre-release suffixes (anything after '-') are stripped per segment.
  static bool _isNewer(String remote, String local) {
    final r = _parseVersion(remote);
    final l = _parseVersion(local);
    if (r.isEmpty || l.isEmpty) return false;
    for (var i = 0; i < 3; i++) {
      if (r[i] > l[i]) return true;
      if (r[i] < l[i]) return false;
    }
    return false; // equal
  }

  /// Parse a version string like "0.11", "0.11.0", or "0.1-alpha" into
  /// a three-element [major, minor, patch] list. Strips pre-release
  /// suffixes (e.g. "1-alpha" → 1) from each segment.
  static List<int> _parseVersion(String v) {
    // Strip everything after '+' (build metadata) first.
    final base = v.split('+').first;
    final parts = base.split('.');
    if (parts.isEmpty) return [];
    // Strip pre-release suffix from each segment: "1-alpha" → "1"
    int seg(int i) {
      if (i >= parts.length) return 0;
      final clean = parts[i].split('-').first;
      return int.tryParse(clean) ?? 0;
    }

    return [seg(0), seg(1), seg(2)];
  }
}
