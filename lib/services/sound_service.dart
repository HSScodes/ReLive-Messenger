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
    await _safePlayAsset('sounds/type.wav');
  }

  /// Plays the given asset. Returns true if playback started successfully.
  Future<bool> _safePlayAsset(String assetPath) async {
    // ── Approach 1: SoundPool (low-latency) + AssetSource ──
    // SoundPool is purpose-built for short notification/UI sounds on Android
    // and handles PCM WAV reliably where MediaPlayer sometimes refuses.
    if (Platform.isAndroid) {
      try {
        final lp = AudioPlayer();
        await lp.play(AssetSource(assetPath), mode: PlayerMode.lowLatency);
        _disposeAfterPlayback(lp);
        return true;
      } catch (e) {
        print('[SoundService] SoundPool AssetSource failed for $assetPath: $e');
      }
    }

    // ── Approach 2: MediaPlayer + AssetSource ──
    if (Platform.isAndroid) {
      try {
        final mp = AudioPlayer();
        await mp.play(AssetSource(assetPath));
        _disposeAfterPlayback(mp);
        return true;
      } catch (e) {
        print(
          '[SoundService] MediaPlayer AssetSource failed for $assetPath: $e',
        );
      }
    }

    // ── Load raw bytes for the remaining fallbacks ──
    final bytes = await _loadAssetBytes(assetPath);
    if (bytes == null || bytes.isEmpty) {
      print('[SoundService] Asset bytes empty for $assetPath');
      if (Platform.isWindows) {
        await SystemSound.play(SystemSoundType.click);
      }
      return false;
    }

    // ── Approach 3: Temp file + DeviceFileSource ──
    final file = await _writeTempSoundFile(assetPath: assetPath, bytes: bytes);
    if (file != null) {
      try {
        final mp = AudioPlayer();
        await mp.play(DeviceFileSource(file.path));
        _disposeAfterPlayback(mp);
        return true;
      } catch (e) {
        print('[SoundService] DeviceFileSource failed for $assetPath: $e');
      }
    }

    // ── Approach 4: BytesSource (last resort) ──
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
