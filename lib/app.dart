import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wlm_project/l10n/app_localizations.dart';

import 'providers/chat_provider.dart';
import 'providers/connection_provider.dart';
import 'screens/login/login_screen.dart';
import 'services/notification_service.dart';

/// Notifier that holds the current app lifecycle state.
class AppLifecycleNotifier extends Notifier<AppLifecycleState> {
  @override
  AppLifecycleState build() => AppLifecycleState.resumed;

  void update(AppLifecycleState value) {
    state = value;
  }
}

final appLifecycleProvider =
    NotifierProvider<AppLifecycleNotifier, AppLifecycleState>(
      AppLifecycleNotifier.new,
    );

// ── Foreground task handler (runs in the service isolate) ──────────────
@pragma('vm:entry-point')
class WlmTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Nothing to initialise — the main isolate keeps the MSNP socket.
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Send a keepalive tick to the main isolate so the Dart VM stays awake.
    FlutterForegroundTask.sendDataToMain('keepalive');
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

class WlmApp extends ConsumerStatefulWidget {
  const WlmApp({super.key});

  @override
  ConsumerState<WlmApp> createState() => _WlmAppState();
}

class _WlmAppState extends ConsumerState<WlmApp>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  bool _foregroundServiceRunning = false;
  Function(Object)? _taskDataCallback;

  // Global nudge shake animation
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;
  int _lastNudgeCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.linear),
    );
    _initServices();
  }

  Future<void> _initServices() async {
    await NotificationService.instance.init();
    await NotificationService.instance.requestPermission();
    _initForegroundTask();
    // Request battery optimization exemption so Android doesn't kill the service.
    FlutterForegroundTask.requestIgnoreBatteryOptimization();
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'wlm_foreground_service',
        channelName: 'WLM Background Service',
        channelDescription: 'Keeps reLive Messenger connected',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        showWhen: false,
        showBadge: false,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(20000), // 20s tick
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<void> _startForegroundService() async {
    if (_foregroundServiceRunning) return;
    final running = await FlutterForegroundTask.isRunningService;
    if (running) {
      _foregroundServiceRunning = true;
      _registerTaskDataCallback();
      return;
    }
    final result = await FlutterForegroundTask.startService(
      notificationTitle: 'reLive Messenger',
      notificationText: 'Connected in background',
      notificationIcon: const NotificationIcon(
        metaDataName: 'com.example.wlm_foreground_icon',
        backgroundColor: Color(0xFF2B6DAD),
      ),
      callback: _startTaskCallback,
    );
    _foregroundServiceRunning = result is ServiceRequestSuccess;
    if (_foregroundServiceRunning) {
      _registerTaskDataCallback();
    }
  }

  void _registerTaskDataCallback() {
    _taskDataCallback ??= (Object data) {
      if (data == 'keepalive') {
        ref.read(msnpClientProvider).sendPing();
      }
    };
    FlutterForegroundTask.addTaskDataCallback(_taskDataCallback!);
  }

  Future<void> _stopForegroundService() async {
    if (!_foregroundServiceRunning) return;
    if (_taskDataCallback != null) {
      FlutterForegroundTask.removeTaskDataCallback(_taskDataCallback!);
      _taskDataCallback = null;
    }
    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {}
    _foregroundServiceRunning = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shakeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(appLifecycleProvider.notifier).update(state);
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // App went to background — start true foreground service to keep alive.
      _startForegroundService();
    } else if (state == AppLifecycleState.resumed) {
      // App came back — stop the foreground service.
      _stopForegroundService();
      // Verify the MSNP connection is still alive; send a ping to detect
      // silent disconnects that happened while backgrounded.
      ref.read(msnpClientProvider).sendPing();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the global nudge counter — trigger shake when it increments.
    final nudgeCount = ref.watch(nudgeEventCounterProvider);
    if (nudgeCount > _lastNudgeCount) {
      _lastNudgeCount = nudgeCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _shakeController.forward(from: 0);
      });
    }

    const textTheme = TextTheme(
      bodyMedium: TextStyle(fontFamily: 'SegoeUI'),
      bodyLarge: TextStyle(fontFamily: 'SegoeUI'),
      titleLarge: TextStyle(fontFamily: 'SegoeUI', fontWeight: FontWeight.w600),
    );

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final dx = _shakeController.isAnimating
            ? sin(_shakeAnimation.value * pi * 6) * 8.0
            : 0.0;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: child,
        );
      },
      child: MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF33A7E8)),
        fontFamily: 'SegoeUI',
        textTheme: textTheme,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    ),
    );
  }
}

// Top-level callback for flutter_foreground_task (must be top-level or static).
@pragma('vm:entry-point')
void _startTaskCallback() {
  FlutterForegroundTask.setTaskHandler(WlmTaskHandler());
}
