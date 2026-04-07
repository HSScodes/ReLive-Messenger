import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';

/// Singleton service for Android notifications (message, nudge, foreground).
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _isForegroundNotificationShown = false;

  /// Callback invoked when user taps a notification.
  /// Set by the host (e.g. app.dart) to navigate to the right chat.
  void Function(String? email)? onTapNotification;

  // Notification channel IDs
  static const _msgChannelId = 'wlm_messages';
  static const _fgChannelId = 'wlm_foreground';

  // Incrementing notification ID
  int _nextId = 100;

  /// Call once during app startup.
  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@drawable/ic_stat_wlm');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onTap,
    );

    // Create the message notification channel with WLM sound.
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _msgChannelId,
          'Messages',
          description: 'Incoming WLM messages and nudges',
          importance: Importance.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('type'),
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _fgChannelId,
          'WLM Service',
          description: 'Keeps WLM connected in the background',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          enableLights: false,
        ),
      );
    }
  }

  /// Request POST_NOTIFICATIONS permission (Android 13+).
  Future<bool> requestPermission() async {
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return false;
    return await androidPlugin.requestNotificationsPermission() ?? false;
  }

  /// Show a message notification with optional avatar.
  Future<void> showMessageNotification({
    required String senderName,
    required String body,
    required String senderEmail,
    String? avatarPath,
  }) async {
    // Build large icon: avatar composited inside the Aero glass frame.
    AndroidBitmap<Object>? largeIcon;
    if (avatarPath != null && File(avatarPath).existsSync()) {
      final aeroPath = await _renderAeroAvatar(avatarPath);
      if (aeroPath != null) {
        largeIcon = FilePathAndroidBitmap(aeroPath);
      } else {
        largeIcon = FilePathAndroidBitmap(avatarPath);
      }
    }

    final android = AndroidNotificationDetails(
      _msgChannelId,
      'Messages',
      channelDescription: 'Incoming WLM messages and nudges',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_wlm',
      color: const Color(0xFF2B6DAD),
      largeIcon: largeIcon,
      styleInformation: BigTextStyleInformation(body, contentTitle: senderName),
    );

    await _plugin.show(
      _nextId++,
      senderName,
      body,
      NotificationDetails(android: android),
      payload: senderEmail,
    );
  }

  /// Show a nudge notification.
  Future<void> showNudgeNotification({
    required String senderName,
    required String senderEmail,
    String? avatarPath,
  }) async {
    await showMessageNotification(
      senderName: senderName,
      body: '$senderName just sent you a nudge!',
      senderEmail: senderEmail,
      avatarPath: avatarPath,
    );
  }

  /// Persistent foreground notification to keep the TCP socket alive.
  Future<void> showForegroundNotification() async {
    if (_isForegroundNotificationShown) {
      return;
    }

    const android = AndroidNotificationDetails(
      _fgChannelId,
      'WLM Service',
      channelDescription: 'Keeps WLM connected in the background',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      icon: 'ic_stat_wlm',
      color: Color(0xFF2B6DAD),
      subText: 'Aero KeepAlive',
    );

    await _plugin.show(
      1, // fixed ID for the foreground notification
      'Windows Live Messenger',
      'Connected in background',
      const NotificationDetails(android: android),
    );
    _isForegroundNotificationShown = true;
  }

  /// Remove the foreground notification.
  Future<void> cancelForegroundNotification() async {
    await _plugin.cancel(1);
    _isForegroundNotificationShown = false;
  }

  void _onTap(NotificationResponse response) {
    final email = response.payload;
    if (email != null && email.isNotEmpty) {
      onTapNotification?.call(email);
    }
  }

  // ── Aero-frame avatar renderer ─────────────────────────────────────────

  static const _assetFrame =
      'assets/images/extracted/msgsres/carved_png_9812096.png';

  /// Composites [avatarPath] inside the WLM Aero glass frame and saves a
  /// 96×96 PNG to the temp directory. Returns the temp file path, or null
  /// on error.
  Future<String?> _renderAeroAvatar(String avatarPath) async {
    try {
      // Decode avatar
      final avatarBytes = await File(avatarPath).readAsBytes();
      final avatarCodec = await ui.instantiateImageCodec(
        avatarBytes,
        targetWidth: 96,
        targetHeight: 96,
      );
      final avatarFrame = await avatarCodec.getNextFrame();
      final avatarImg = avatarFrame.image;

      // Decode aero frame asset
      final frameData = await rootBundle.load(_assetFrame);
      final frameCodec = await ui.instantiateImageCodec(
        frameData.buffer.asUint8List(),
        targetWidth: 96,
        targetHeight: 96,
      );
      final frameFrameResult = await frameCodec.getNextFrame();
      final frameImg = frameFrameResult.image;

      const double sz = 96;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, sz, sz));

      // Draw avatar inset 15.5 % (mirrors AvatarWidget layout)
      final inset = sz * 0.155;
      final avatarDst = Rect.fromLTRB(inset, inset, sz - inset, sz - inset);
      final avatarSrc = Rect.fromLTWH(
        0, 0,
        avatarImg.width.toDouble(),
        avatarImg.height.toDouble(),
      );
      canvas.drawImageRect(avatarImg, avatarSrc, avatarDst, Paint());

      // Draw frame with green (online) tint using saveLayer for srcATop
      final fullRect = Rect.fromLTWH(0, 0, sz, sz);
      final frameSrc = Rect.fromLTWH(
        0, 0,
        frameImg.width.toDouble(),
        frameImg.height.toDouble(),
      );
      canvas.saveLayer(fullRect, Paint());
      canvas.drawImageRect(frameImg, frameSrc, fullRect, Paint());
      canvas.drawRect(
        fullRect,
        Paint()
          ..color = const Color(0xD939FF14) // GFP green at ~85 % alpha
          ..blendMode = BlendMode.srcATop,
      );
      canvas.restore();

      final picture = recorder.endRecording();
      final composited = await picture.toImage(96, 96);
      final pngData =
          await composited.toByteData(format: ui.ImageByteFormat.png);
      if (pngData == null) return null;

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/wlm_notif_avatar.png');
      await tempFile.writeAsBytes(pngData.buffer.asUint8List(), flush: true);
      return tempFile.path;
    } catch (_) {
      return null;
    }
  }
}
