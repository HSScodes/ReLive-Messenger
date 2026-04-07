import 'package:audioplayers/audioplayers.dart';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class SoundService {
  const SoundService();

  static final Map<String, Uint8List> _assetBytesCache = <String, Uint8List>{};

  Future<void> playTyping() async {
    await _safePlayAsset('sounds/type.wav');
  }

  Future<void> playNudge() async {
    await _safePlayAsset('sounds/nudge.wav');
  }

  Future<void> playNewEmail() async {
    await _safePlayAsset('sounds/newemail.wav');
  }

  Future<void> playOnline() async {
    await _safePlayAsset('sounds/online.wav');
  }

  Future<void> playNewMessage() async {
    // WLM 2009 uses newalert.wma for incoming messages; fall back to type.mp3.
    if (!await _safePlayAsset('sounds/newalert.wma')) {
      await _safePlayAsset('sounds/type.mp3');
    }
  }

  /// Plays the given asset. Returns true if playback started successfully.
  Future<bool> _safePlayAsset(String assetPath) async {
    // Create a fresh player per playback to avoid shared-state conflicts on
    // Android 14+ where a single AudioPlayer can stall after repeated use.
    final player = AudioPlayer();
    try {
      // Prefer AssetSource on Android — avoids temp-file / scoped-storage issues.
      if (Platform.isAndroid) {
        try {
          await player.play(AssetSource(assetPath));
          _disposeAfterPlayback(player);
          return true;
        } catch (e) {
          print('[SoundService] AssetSource failed for $assetPath: $e');
          // Fall through to temp-file approach below.
        }
      }

      // Temp-file approach (works on Windows, fallback on Android).
      final bytes = await _loadAssetBytes(assetPath);
      if (bytes == null || bytes.isEmpty) {
        print('[SoundService] Asset bytes empty for $assetPath');
        await player.dispose();
        if (Platform.isWindows) {
          await SystemSound.play(SystemSoundType.click);
        }
        return false;
      }
      final file = await _writeTempSoundFile(assetPath: assetPath, bytes: bytes);
      if (file != null) {
        await player.play(DeviceFileSource(file.path));
        _disposeAfterPlayback(player);
        return true;
      }

      await player.play(BytesSource(bytes));
      _disposeAfterPlayback(player);
      return true;
    } catch (e) {
      print('[SoundService] Playback error for $assetPath: $e');
      await player.dispose();
      if (Platform.isWindows) {
        try {
          await SystemSound.play(SystemSoundType.alert);
        } catch (e2) {
          print('[SoundService] SystemSound fallback error: $e2');
        }
      }
      return false;
    }
  }

  /// Disposes the player after it finishes playing.
  void _disposeAfterPlayback(AudioPlayer player) {
    player.onPlayerComplete.listen((_) async {
      await player.dispose();
    });
    // Safety: dispose after 10 seconds if playback never completes.
    Future.delayed(const Duration(seconds: 10), () async {
      try {
        await player.dispose();
      } catch (_) {}
    });
  }

  Future<Uint8List?> _loadAssetBytes(String assetPath) async {
    final cached = _assetBytesCache[assetPath];
    if (cached != null) {
      return cached;
    }

    try {
      final data = await rootBundle.load('assets/$assetPath');
      final bytes = data.buffer.asUint8List();
      _assetBytesCache[assetPath] = bytes;
      return bytes;
    } catch (e) {
      print('[SoundService] Failed to load asset bytes for $assetPath: $e');
      return null;
    }
  }

  Future<File?> _writeTempSoundFile({
    required String assetPath,
    required Uint8List bytes,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final safeName = assetPath.replaceAll('/', '_');
      final file = File('${dir.path}${Platform.pathSeparator}wlm_$safeName');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (e) {
      print('[SoundService] Failed to write temp file for $assetPath: $e');
      return null;
    }
  }
}
