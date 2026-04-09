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

  Future<void> playNewMessage() async {
    await _safePlayAsset('sounds/type.wav');
  }

  /// Plays the given asset. Returns true if playback started successfully.
  Future<bool> _safePlayAsset(String assetPath) async {
    // ── Load raw bytes for all Android approaches ──
    // We need bytes early because the primary approach (DeviceFileSource)
    // requires a temp file from the asset bytes.
    final bytes = await _loadAssetBytes(assetPath);

    // ── Approach 1: Temp file + DeviceFileSource + Notification context ──
    // MediaPlayer with DeviceFileSource properly respects AudioAttributes
    // and routes audio through the notification volume stream.
    // AssetSource + MediaPlayer fails with setDataSourceFD on many devices.
    if (Platform.isAndroid && bytes != null && bytes.isNotEmpty) {
      final file = await _writeTempSoundFile(
        assetPath: assetPath,
        bytes: bytes,
      );
      if (file != null) {
        try {
          final mp = AudioPlayer();
          await mp.setAudioContext(
            AudioContext(
              android: AudioContextAndroid(
                usageType: AndroidUsageType.notification,
                contentType: AndroidContentType.sonification,
                audioFocus: AndroidAudioFocus.gainTransientMayDuck,
              ),
            ),
          );
          await mp.play(DeviceFileSource(file.path));
          _disposeAfterPlayback(mp);
          return true;
        } catch (e) {
          print(
            '[SoundService] DeviceFileSource+Notification failed for $assetPath: $e',
          );
        }
      }
    }

    // ── Approach 2: SoundPool (low-latency) + AssetSource ──
    // Handles PCM WAV reliably but may not respect the notification
    // volume slider on all devices.
    if (Platform.isAndroid) {
      try {
        final lp = AudioPlayer();
        await lp.setAudioContext(
          AudioContext(
            android: AudioContextAndroid(
              usageType: AndroidUsageType.notification,
              contentType: AndroidContentType.sonification,
              audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            ),
          ),
        );
        await lp.play(AssetSource(assetPath), mode: PlayerMode.lowLatency);
        _disposeAfterPlayback(lp);
        return true;
      } catch (e) {
        print('[SoundService] SoundPool AssetSource failed for $assetPath: $e');
      }
    }

    if (bytes == null || bytes.isEmpty) {
      print('[SoundService] Asset bytes empty for $assetPath');
      if (Platform.isWindows) {
        await SystemSound.play(SystemSoundType.click);
      }
      return false;
    }

    // ── Approach 3: BytesSource (last resort) ──
    try {
      final mp = AudioPlayer();
      await mp.play(BytesSource(bytes));
      _disposeAfterPlayback(mp);
      return true;
    } catch (e) {
      print('[SoundService] BytesSource failed for $assetPath: $e');
    }

    if (Platform.isWindows) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
    return false;
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
