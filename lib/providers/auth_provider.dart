import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/msnp_client.dart';
import 'connection_provider.dart';

class AuthState {
  const AuthState({
    this.email,
    this.isLoading = false,
    this.error,
    this.reconnecting = false,
  });

  final String? email;
  final bool isLoading;
  final String? error;
  final bool reconnecting;

  bool get isAuthenticated => email != null && error == null;

  AuthState copyWith({
    String? email,
    bool? isLoading,
    String? error,
    bool? reconnecting,
  }) {
    return AuthState(
      email: email ?? this.email,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      reconnecting: reconnecting ?? this.reconnecting,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final MsnpClient _client;

  // Cached credentials for auto-reconnect
  String? _lastEmail;
  String? _lastPassword;
  String? _lastTicket;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  StreamSubscription<ConnectionStatus>? _statusSub;

  static const _maxReconnectAttempts = 15;
  static const _backoffDelays = [2, 4, 8, 16, 30, 45, 60, 60, 60, 60, 60, 60, 60, 60, 60]; // seconds

  @override
  AuthState build() {
    _client = ref.watch(msnpClientProvider);
    _statusSub?.cancel();
    _statusSub = _client.status.listen(_onConnectionStatus);
    ref.onDispose(() {
      _statusSub?.cancel();
      _reconnectTimer?.cancel();
    });
    return const AuthState();
  }

  void _onConnectionStatus(ConnectionStatus status) {
    if (status == ConnectionStatus.disconnected ||
        status == ConnectionStatus.error) {
      // Only auto-reconnect if we were previously authenticated
      if (state.isAuthenticated && _lastEmail != null && _lastPassword != null) {
        _scheduleReconnect();
      }
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempt >= _maxReconnectAttempts) {
      state = state.copyWith(
        error: 'Connection lost. Max reconnection attempts reached.',
        reconnecting: false,
      );
      return;
    }
    _reconnectTimer?.cancel();
    final delay = _backoffDelays[_reconnectAttempt.clamp(0, _backoffDelays.length - 1)];
    state = state.copyWith(reconnecting: true, error: null);
    _reconnectTimer = Timer(Duration(seconds: delay), () => _doReconnect());
  }

  Future<void> _doReconnect() async {
    if (_lastEmail == null || _lastPassword == null) return;
    _reconnectAttempt++;
    try {
      await _client.connect(
        email: _lastEmail!,
        password: _lastPassword!,
        passportTicket: _lastTicket ?? _lastPassword!,
      );
      // Success — reset counter
      _reconnectAttempt = 0;
      state = state.copyWith(
        email: _lastEmail,
        isLoading: false,
        error: null,
        reconnecting: false,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
    required String ticket,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    _lastEmail = email;
    _lastPassword = password;
    _lastTicket = ticket;
    _reconnectAttempt = 0;
    try {
      await _client.connect(
        email: email,
        password: password,
        passportTicket: ticket,
      );
      state = state.copyWith(email: email, isLoading: false, error: null);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Unable to connect to CrossTalk. Verify host/port and credentials.',
      );
    }
  }

  Future<void> signOut() async {
    _reconnectTimer?.cancel();
    _reconnectAttempt = 0;
    _lastEmail = null;
    _lastPassword = null;
    _lastTicket = null;
    await _client.disconnect();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
