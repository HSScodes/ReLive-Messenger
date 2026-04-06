import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/msnp_client.dart';
import 'connection_provider.dart';

class AuthState {
  const AuthState({
    this.email,
    this.isLoading = false,
    this.error,
  });

  final String? email;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => email != null && error == null;

  AuthState copyWith({
    String? email,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      email: email ?? this.email,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final MsnpClient _client;

  @override
  AuthState build() {
    _client = ref.watch(msnpClientProvider);
    return const AuthState();
  }

  Future<void> signIn({
    required String email,
    required String password,
    required String ticket,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
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
    await _client.disconnect();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
