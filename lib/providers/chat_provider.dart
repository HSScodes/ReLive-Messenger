import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/message.dart';
import '../network/msnp_parser.dart';
import '../services/chat_history_service.dart';
import '../services/sound_service.dart';
import 'connection_provider.dart';
import 'contacts_provider.dart';

class InboundChatEmailNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setInbound(String? email) {
    state = email;
  }

  void clear() {
    state = null;
  }
}

final inboundChatEmailProvider = NotifierProvider<InboundChatEmailNotifier, String?>(
  InboundChatEmailNotifier.new,
);

class TypingContactsNotifier extends Notifier<Set<String>> {
  final Map<String, Timer> _timers = <String, Timer>{};

  @override
  Set<String> build() {
    ref.onDispose(() {
      for (final timer in _timers.values) {
        timer.cancel();
      }
      _timers.clear();
    });
    return <String>{};
  }

  void markTyping(String email) {
    final normalized = email.toLowerCase();
    state = <String>{...state, normalized};

    _timers[normalized]?.cancel();
    _timers[normalized] = Timer(const Duration(seconds: 6), () {
      clearTyping(normalized);
    });
  }

  void clearTyping(String email) {
    final normalized = email.toLowerCase();
    final next = <String>{...state}..remove(normalized);
    state = next;
    _timers.remove(normalized)?.cancel();
  }

  bool isTyping(String email) {
    return state.contains(email.toLowerCase());
  }
}

final typingContactsProvider = NotifierProvider<TypingContactsNotifier, Set<String>>(
  TypingContactsNotifier.new,
);

class ActiveChatEmailNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setActive(String? email) {
    state = email?.trim().toLowerCase();
  }

  void clearActive(String email) {
    if (state == email.trim().toLowerCase()) {
      state = null;
    }
  }
}

final activeChatEmailProvider = NotifierProvider<ActiveChatEmailNotifier, String?>(
  ActiveChatEmailNotifier.new,
);

class ChatNotifier extends Notifier<List<Message>> {
  StreamSubscription<MsnpEvent>? _subscription;
  final SoundService _soundService = const SoundService();
  final ChatHistoryService _historyService = ChatHistoryService();

  @override
  List<Message> build() {
    _subscription = ref.watch(msnpClientProvider).events.listen(_onEvent);
    ref.onDispose(() {
      _subscription?.cancel();
    });
    unawaited(_loadHistory());
    return const [];
  }

  Future<void> _loadHistory() async {
    final history = await _historyService.loadMessages();
    if (history.isEmpty) {
      return;
    }

    state = history;
  }

  void _appendMessage(Message message) {
    state = [...state, message];
    unawaited(_historyService.saveMessages(state));
  }

  Future<void> _onEvent(MsnpEvent event) async {
    if (event.from == null || event.body == null) {
      return;
    }

    if (event.type == MsnpEventType.typing) {
      await _soundService.playTyping();
      ref.read(typingContactsProvider.notifier).markTyping(event.from!);
      return;
    }

    if (event.type == MsnpEventType.nudge) {
      await _soundService.playNudge();
      _appendMessage(
        Message(
          from: event.from!,
          to: event.to ?? '',
          body: 'Nudge',
          isNudge: true,
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    if (event.type == MsnpEventType.message) {
      final incoming = event.from!.toLowerCase();
      final isContactMessage = incoming.contains('@');
      if (isContactMessage) {
        await _soundService.playTyping();
      }
      final activeEmail = ref.read(activeChatEmailProvider);
      if (isContactMessage && (activeEmail == null || activeEmail != incoming)) {
        ref.read(contactsProvider.notifier).incrementUnreadForEmail(incoming);
      }
      ref.read(typingContactsProvider.notifier).clearTyping(event.from!);
      _appendMessage(
        Message(
          from: event.from!,
          to: event.to ?? '',
          body: event.body!,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  List<Message> threadForContact(String contactEmail) {
    final normalized = contactEmail.toLowerCase();
    return state
        .where(
          (message) =>
              message.from.toLowerCase() == normalized ||
              message.to.toLowerCase() == normalized,
        )
        .toList(growable: false);
  }

  Future<void> sendMessage({
    required String to,
    required String body,
  }) async {
    final client = ref.read(msnpClientProvider);
    final cleanBody = body.trim();
    if (cleanBody.isEmpty) {
      return;
    }

    await client.sendInstantMessage(to: to, body: cleanBody);
    ref.read(typingContactsProvider.notifier).clearTyping(to);
    final from = client.selfEmail.isEmpty ? 'me' : client.selfEmail;
    _appendMessage(
      Message(
        from: from,
        to: to,
        body: cleanBody,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> sendTyping(String to) async {
    final client = ref.read(msnpClientProvider);
    await client.sendTypingNotification(to: to);
  }

  Future<void> sendNudge(String to) async {
    final client = ref.read(msnpClientProvider);
    await client.sendNudge(to: to);

    final from = client.selfEmail.isEmpty ? 'me' : client.selfEmail;
    _appendMessage(
      Message(
        from: from,
        to: to,
        body: 'Nudge',
        timestamp: DateTime.now(),
        isNudge: true,
      ),
    );
  }
}

final chatProvider = NotifierProvider<ChatNotifier, List<Message>>(ChatNotifier.new);
