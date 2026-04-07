import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../models/contact.dart';
import '../models/message.dart';
import '../network/msnp_parser.dart';
import '../services/chat_history_service.dart';
import '../services/file_transfer_service.dart';
import '../services/notification_service.dart';
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

/// Global counter incremented on every incoming nudge. Widgets (e.g. the root
/// app shell) watch this to trigger a screen-wide shake animation.
class NudgeEventCounterNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

final nudgeEventCounterProvider =
    NotifierProvider<NudgeEventCounterNotifier, int>(
  NudgeEventCounterNotifier.new,
);

class ChatNotifier extends Notifier<List<Message>> {
  StreamSubscription<MsnpEvent>? _subscription;
  StreamSubscription<FileTransferSession>? _ftCompletedSub;
  StreamSubscription<FileTransferSession>? _ftProgressSub;
  StreamSubscription<FileTransferSession>? _ftFailedSub;
  final SoundService _soundService = const SoundService();
  final ChatHistoryService _historyService = ChatHistoryService();

  @override
  List<Message> build() {
    final client = ref.watch(msnpClientProvider);
    _subscription = client.events.listen(_onEvent);
    _ftCompletedSub = client.fileTransferService.completedStream.listen(
      _onFileTransferCompleted,
    );
    _ftProgressSub = client.fileTransferService.progressStream.listen(
      _onFileTransferProgress,
    );
    _ftFailedSub = client.fileTransferService.failedStream.listen(
      _onFileTransferFailed,
    );
    ref.onDispose(() {
      _subscription?.cancel();
      _ftCompletedSub?.cancel();
      _ftProgressSub?.cancel();
      _ftFailedSub?.cancel();
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
      // Only play in-app sound when foreground; the notification channel
      // handles sound when backgrounded (avoids double audio).
      final lifecycle = ref.read(appLifecycleProvider);
      if (lifecycle == AppLifecycleState.resumed) {
        await _soundService.playNudge();
      }
      // Increment global nudge counter so the root shell shakes the entire UI.
      ref.read(nudgeEventCounterProvider.notifier).increment();
      _appendMessage(
        Message(
          from: event.from!,
          to: event.to ?? '',
          body: 'Nudge',
          isNudge: true,
          timestamp: DateTime.now(),
        ),
      );
      _notifyIfBackgrounded(event.from!, 'Nudge', isNudge: true);
      return;
    }

    // ── Incoming wink (placeholder — no Flash support) ──────────────────
    if (event.type == MsnpEventType.system && event.command == 'WINK') {
      _appendMessage(
        Message(
          from: event.from!,
          to: event.to ?? '',
          body: '\u{1F3AC} ${event.from!} sent you a wink!',
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    // ── Incoming file transfer offer ────────────────────────────────────
    if (event.type == MsnpEventType.system && event.command == 'FTINVITE') {
      final from = (event.from ?? '').trim();
      final sessionId = int.tryParse(event.body ?? '');
      if (from.isNotEmpty && sessionId != null) {
        final client = ref.read(msnpClientProvider);
        final session = client.fileTransferService.getSession(sessionId);
        if (session != null) {
          _appendMessage(Message(
            from: from,
            to: client.selfEmail,
            body: 'wants to send you ${session.fileName} (${_formatBytes(session.fileSize)})',
            timestamp: DateTime.now(),
            isFileTransfer: true,
            fileTransferId: '$sessionId',
            fileName: session.fileName,
            fileSize: session.fileSize,
            fileTransferState: FileTransferState.offered,
          ));
        }
      }
      return;
    }

    // ── Outbound file transfer accepted by remote ───────────────────────
    if (event.type == MsnpEventType.system && event.command == 'FTACCEPTED') {
      final from = (event.from ?? '').trim();
      final sessionId = int.tryParse(event.body ?? '');
      if (from.isNotEmpty && sessionId != null) {
        _updateFileTransferState(
            '$sessionId', FileTransferState.transferring);

        // Read the file from disk and start sending data chunks.
        final client = ref.read(msnpClientProvider);
        final session = client.fileTransferService.getSession(sessionId);
        if (session != null && session.localPath != null) {
          try {
            final fileBytes = File(session.localPath!).readAsBytesSync();
            unawaited(client.sendFileData(
              sessionId: sessionId,
              fileBytes: Uint8List.fromList(fileBytes),
              to: from,
            ));
          } catch (e) {
            print('[FT] Error reading file for transfer: $e');
            _updateFileTransferState('$sessionId', FileTransferState.failed);
          }
        }
      }
      return;
    }

    // ── Outbound file transfer sent all data + BYE ──────────────────────
    if (event.type == MsnpEventType.system && event.command == 'FTCOMPLETE') {
      final sessionId = int.tryParse(event.body ?? '');
      if (sessionId != null) {
        _updateFileTransferState('$sessionId', FileTransferState.completed);
      }
      return;
    }

    // ── Outbound file transfer failed (SB died or timeout) ──────────────
    if (event.type == MsnpEventType.system && event.command == 'FTFAILED') {
      final sessionId = int.tryParse(event.body ?? '');
      if (sessionId != null) {
        _updateFileTransferState('$sessionId', FileTransferState.failed);
      }
      return;
    }

    if (event.type == MsnpEventType.message) {
      final incoming = event.from!.toLowerCase();
      final isContactMessage = incoming.contains('@');
      if (isContactMessage) {
        // Only play in-app sound when foreground; the notification channel
        // handles sound when backgrounded (avoids double audio).
        final lifecycle = ref.read(appLifecycleProvider);
        if (lifecycle == AppLifecycleState.resumed) {
          await _soundService.playNewMessage();
        }
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
      if (isContactMessage) {
        _notifyIfBackgrounded(event.from!, event.body!);
      }
    }
  }

  void _notifyIfBackgrounded(String senderEmail, String body,
      {bool isNudge = false}) {
    final lifecycle = ref.read(appLifecycleProvider);
    if (lifecycle != AppLifecycleState.paused &&
        lifecycle != AppLifecycleState.inactive) {
      return;
    }
    final contacts = ref.read(contactsProvider);
    final normalised = senderEmail.toLowerCase();
    Contact? contact;
    for (final c in contacts) {
      if (c.email.toLowerCase() == normalised) {
        contact = c;
        break;
      }
    }
    final name = contact?.displayName ?? senderEmail;
    final avatar = contact?.ddpLocalPath ?? contact?.avatarLocalPath;
    if (isNudge) {
      NotificationService.instance.showNudgeNotification(
        senderName: name,
        senderEmail: senderEmail,
        avatarPath: avatar,
      );
    } else {
      NotificationService.instance.showMessageNotification(
        senderName: name,
        body: body,
        senderEmail: senderEmail,
        avatarPath: avatar,
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

  // ── File transfer methods ──────────────────────────────────────────────

  /// Initiate sending a file to a contact.
  Future<void> sendFile({
    required String to,
    required String filePath,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) return;
    final fileName = filePath.split(Platform.pathSeparator).last;
    final fileSize = file.lengthSync();
    final client = ref.read(msnpClientProvider);
    final from = client.selfEmail.isEmpty ? 'me' : client.selfEmail;

    final sessionId = client.sendFileTransferInvite(
      to: to,
      fileName: fileName,
      fileSize: fileSize,
    );

    // Store the local file path on the session so we can read it when accepted.
    final session = client.fileTransferService.getSession(sessionId);
    if (session != null) {
      session.localPath = filePath;
    }

    _appendMessage(Message(
      from: from,
      to: to,
      body: 'Sending $fileName (${_formatBytes(fileSize)})',
      timestamp: DateTime.now(),
      isFileTransfer: true,
      fileTransferId: '$sessionId',
      fileName: fileName,
      fileSize: fileSize,
      filePath: filePath,
      fileTransferState: FileTransferState.offered,
    ));
  }

  /// Accept an incoming file transfer.
  void acceptFileTransfer(String fileTransferId) {
    final sessionId = int.tryParse(fileTransferId);
    if (sessionId == null) return;

    final client = ref.read(msnpClientProvider);
    final session = client.fileTransferService.getSession(sessionId);
    if (session == null) return;

    client.acceptFileTransfer(
        sessionId: sessionId, from: session.peerEmail);
    _updateFileTransferState(fileTransferId, FileTransferState.accepted);
  }

  /// Decline an incoming file transfer.
  void declineFileTransfer(String fileTransferId) {
    final sessionId = int.tryParse(fileTransferId);
    if (sessionId == null) return;

    final client = ref.read(msnpClientProvider);
    final session = client.fileTransferService.getSession(sessionId);
    if (session == null) return;

    client.declineFileTransfer(
        sessionId: sessionId, from: session.peerEmail);
    _updateFileTransferState(fileTransferId, FileTransferState.declined);
  }

  /// Called when a file transfer completes (either direction).
  void _onFileTransferCompleted(FileTransferSession session) {
    _updateFileTransferState(
      '${session.sessionId}',
      FileTransferState.completed,
      filePath: session.localPath,
    );
  }

  /// Called when a file transfer reports progress (data chunks arriving).
  void _onFileTransferProgress(FileTransferSession session) {
    _updateFileTransferState(
      '${session.sessionId}',
      FileTransferState.transferring,
    );
  }

  /// Called when a file transfer stalls (no data for 30 s).
  void _onFileTransferFailed(FileTransferSession session) {
    _updateFileTransferState(
      '${session.sessionId}',
      FileTransferState.failed,
    );
  }

  void _updateFileTransferState(
    String fileTransferId,
    FileTransferState newState, {
    String? filePath,
  }) {
    final idx = state.lastIndexWhere(
        (m) => m.isFileTransfer && m.fileTransferId == fileTransferId);
    if (idx == -1) return;
    final updated = state[idx].copyWith(
      fileTransferState: newState,
      filePath: filePath,
    );
    final next = [...state];
    next[idx] = updated;
    state = next;
    unawaited(_historyService.saveMessages(state));
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

final chatProvider = NotifierProvider<ChatNotifier, List<Message>>(ChatNotifier.new);
