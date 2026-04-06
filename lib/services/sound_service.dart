import 'package:audioplayers/audioplayers.dart';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class SoundService {
  const SoundService();

  static final AudioPlayer _player = AudioPlayer();
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

  Future<void> _safePlayAsset(String assetPath) async {
    try {
      if (Platform.isWindows) {
        final bytes = await _loadAssetBytes(assetPath);
        if (bytes == null || bytes.isEmpty) {
          await SystemSound.play(SystemSoundType.click);
          return;
        }
        final file = await _writeTempSoundFile(assetPath: assetPath, bytes: bytes);
        if (file != null) {
          await _player.play(DeviceFileSource(file.path));
          return;
        }

        await _player.play(BytesSource(bytes));
        return;
      }

      await _player.play(AssetSource(assetPath));
    } catch (_) {
      if (Platform.isWindows) {
        try {
          await SystemSound.play(SystemSoundType.alert);
        } catch (_) {
          // Ignore fallback errors too.
        }
      }
      // Do not propagate audio plugin errors to UI/network flows.
    }
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
    } catch (_) {
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
    } catch (_) {
      return null;
    }
  }
}
