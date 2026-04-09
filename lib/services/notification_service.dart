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
  static const _msgChannelId = 'wlm_messages_v2';
  static const _nudgeChannelId = 'wlm_nudges_v2';
  static const _fgChannelId = 'wlm_foreground_v2';

  // Incrementing notification ID
  int _nextId = 100;

  /// Call once during app startup.
  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@drawable/ic_stat_wlm',
    );
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onTap,
    );

    // Create the message notification channel with WLM sound.
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _msgChannelId,
          'Messages',
          description: 'Incoming WLM messages',
          importance: Importance.high,
          playSound: false,
        ),
      );

      // Delete legacy message channel that may have had sound enabled.
      await androidPlugin.deleteNotificationChannel('wlm_messages');

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _nudgeChannelId,
          'Nudges',
          description: 'Incoming WLM nudges',
          importance: Importance.high,
          playSound: false,
        ),
      );

      // Delete legacy nudge channel that had sound (causes double-play).
      await androidPlugin.deleteNotificationChannel('wlm_nudges');

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

      // Delete legacy foreground channel that may have had sound enabled.
      await androidPlugin.deleteNotificationChannel('wlm_foreground');
    }
  }

  /// Request POST_NOTIFICATIONS permission (Android 13+).
  Future<bool> requestPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
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
    // Build large icon: avatar with a clean circular crop for modern Android.
    AndroidBitmap<Object>? largeIcon;
    if (avatarPath != null && File(avatarPath).existsSync()) {
      try {
        final renderedAvatarPath = await _renderCleanAvatar(avatarPath);
        final effectivePath = renderedAvatarPath ?? avatarPath;
        largeIcon = FilePathAndroidBitmap(effectivePath);
      } catch (_) {
        // If avatar rendering fails, skip the large icon gracefully
      }
    }

    final android = AndroidNotificationDetails(
      _msgChannelId,
      'Messages',
      channelDescription: 'Incoming WLM messages and nudges',
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
      icon: 'ic_stat_wlm',
      color: const Color(0xFF4A9BD9),
      colorized: true,
      largeIcon: largeIcon,
      subText: 'reLive Messenger',
      ticker: '$senderName: $body',
      category: AndroidNotificationCategory.message,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: '<b>$senderName</b>',
        htmlFormatContentTitle: true,
        summaryText: senderEmail,
      ),
    );

    await _plugin.show(
      _nextId++,
      senderName,
      body,
      NotificationDetails(android: android),
      payload: senderEmail,
    );
  }

  /// Show a nudge notification with nudge-specific sound.
  Future<void> showNudgeNotification({
    required String senderName,
    required String senderEmail,
    String? avatarPath,
  }) async {
    AndroidBitmap<Object>? largeIcon;
    if (avatarPath != null && File(avatarPath).existsSync()) {
      try {
        final renderedAvatarPath = await _renderCleanAvatar(avatarPath);
        final effectivePath = renderedAvatarPath ?? avatarPath;
        largeIcon = FilePathAndroidBitmap(effectivePath);
      } catch (_) {}
    }

    final body = '$senderName just sent you a nudge!';
    final android = AndroidNotificationDetails(
      _nudgeChannelId,
      'Nudges',
      channelDescription: 'Incoming WLM nudges',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_wlm',
      color: const Color(0xFF4A9BD9),
      colorized: true,
      largeIcon: largeIcon,
      subText: 'reLive Messenger',
      ticker: body,
      category: AndroidNotificationCategory.message,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: '<b>$senderName</b>',
        htmlFormatContentTitle: true,
        summaryText: senderEmail,
      ),
    );

    await _plugin.show(
      _nextId++,
      senderName,
      body,
      NotificationDetails(android: android),
      payload: senderEmail,
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
      playSound: false,
      enableVibration: false,
      silent: true,
      icon: 'ic_stat_wlm',
      color: Color(0xFF2B6DAD),
      subText: 'Aero KeepAlive',
    );

    await _plugin.show(
      1, // fixed ID for the foreground notification
      'reLive Messenger',
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

  // ── Aero-framed avatar renderer for notifications ──────────────────────

  static const _assetFrame =
      'assets/images/app/ui/carved_png_9812096.png';

  /// Renders the avatar at 512×512 with the WLM aero glass frame overlay,
  /// properly inset so the photo sits inside the frame's transparent center.
  /// The frame is tinted green for online status.
  Future<String?> _renderCleanAvatar(String avatarPath) async {
    try {
      const double sz = 512;
      // 9.35% inset matches the frame's transparent center (13px on 139px frame)
      const double inset = sz * 0.0935;

      // Decode avatar
      final avatarBytes = await File(avatarPath).readAsBytes();
      final avatarCodec = await ui.instantiateImageCodec(
        avatarBytes,
        targetWidth: 512,
        targetHeight: 512,
      );
      final avatarFrame = await avatarCodec.getNextFrame();
      final avatarImg = avatarFrame.image;

      // Decode aero frame asset
      final frameData = await rootBundle.load(_assetFrame);
      final frameCodec = await ui.instantiateImageCodec(
        frameData.buffer.asUint8List(),
        targetWidth: 512,
        targetHeight: 512,
      );
      final frameFrame = await frameCodec.getNextFrame();
      final frameImg = frameFrame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, sz, sz));

      // Draw avatar inset within the frame area
      final avatarSrc = Rect.fromLTWH(
        0,
        0,
        avatarImg.width.toDouble(),
        avatarImg.height.toDouble(),
      );
      final avatarDst = Rect.fromLTWH(
        inset,
        inset,
        sz - inset * 2,
        sz - inset * 2,
      );
      canvas.drawImageRect(
        avatarImg,
        avatarSrc,
        avatarDst,
        Paint()..filterQuality = ui.FilterQuality.medium,
      );

      // Draw aero frame overlay with green tint for online status
      final frameSrc = Rect.fromLTWH(
        0,
        0,
        frameImg.width.toDouble(),
        frameImg.height.toDouble(),
      );
      final frameDst = Rect.fromLTWH(0, 0, sz, sz);
      canvas.drawImageRect(
        frameImg,
        frameSrc,
        frameDst,
        Paint()..filterQuality = ui.FilterQuality.medium,
      );

      // Apply subtle green tint on the frame using color blend
      canvas.saveLayer(frameDst, Paint());
      canvas.drawImageRect(
        frameImg,
        frameSrc,
        frameDst,
        Paint()..filterQuality = ui.FilterQuality.medium,
      );
      canvas.drawRect(
        frameDst,
        Paint()
          ..color = const Color(0x3044BB44)
          ..blendMode = ui.BlendMode.srcATop,
      );
      canvas.restore();

      final picture = recorder.endRecording();
      final composited = await picture.toImage(512, 512);
      final pngData = await composited.toByteData(
        format: ui.ImageByteFormat.png,
      );
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
