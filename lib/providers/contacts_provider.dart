import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/contact.dart';
import '../network/msnp_client.dart';
import '../network/msnp_parser.dart';
import '../services/sound_service.dart';
import '../utils/presence_status.dart';
import 'connection_provider.dart';

class ContactsNotifier extends Notifier<List<Contact>> {
  StreamSubscription<MsnpEvent>? _subscription;
  MsnpClient? _client;
  final Map<String, String> _avatarPathByEmail = <String, String>{};
  final Set<String> _avatarFetchFailedByEmail = <String>{};
  final Map<String, int> _unreadCountByEmail = <String, int>{};
  final SoundService _soundService = const SoundService();

  @override
  List<Contact> build() {
    final client = ref.watch(msnpClientProvider);
    _client = client;
    _subscription = client.events.listen(_onEvent);
    ref.onDispose(() {
      _subscription?.cancel();
    });

    return _snapshotToContacts(client.contactSnapshot);
  }

  Future<void> _onEvent(MsnpEvent event) async {
    if (_client == null) {
      return;
    }

    if (
        event.type == MsnpEventType.presence &&
        event.command == 'FLN' &&
        event.from != null &&
        event.from!.trim().isNotEmpty
    ) {
      setOffline(event.from!);
      return;
    }

    if (event.type == MsnpEventType.system && event.command == 'AVFAIL') {
      final failedEmail = (event.from ?? '').trim().toLowerCase();
      if (failedEmail.isNotEmpty) {
        _avatarPathByEmail.remove(failedEmail);
        _avatarFetchFailedByEmail.add(failedEmail);
        state = _snapshotToContacts(_client!.contactSnapshot);
      }
      return;
    }

    if (event.type == MsnpEventType.system && event.command == 'AVOK') {
      final email = (event.from ?? '').trim().toLowerCase();
      final filePath = (event.body ?? '').trim();
      if (email.isNotEmpty && filePath.isNotEmpty) {
        _avatarPathByEmail[email] = filePath;
        _avatarFetchFailedByEmail.remove(email);
        state = _snapshotToContacts(_client!.contactSnapshot);
      }
      return;
    }

    final shouldRefresh =
        event.type == MsnpEventType.presence ||
        event.type == MsnpEventType.contact ||
      event.type == MsnpEventType.message ||
      event.type == MsnpEventType.typing ||
      event.type == MsnpEventType.nudge ||
        (event.type == MsnpEventType.system &&
        (event.command == 'ABCH' ||
          event.command == 'UBX' ||
          event.command == 'CHG' ||
          event.command == 'SBPRES'));
    if (!shouldRefresh) {
      return;
    }

    final currentByEmail = <String, PresenceStatus>{
      for (final contact in state) contact.email.toLowerCase(): contact.status,
    };

    var next = _snapshotToContacts(_client!.contactSnapshot);

    // Ensure reverse-list / unknown contacts from live presence are represented immediately.
    if (event.type == MsnpEventType.presence && event.from != null && event.from!.isNotEmpty) {
      final incomingEmail = event.from!.toLowerCase();
      final index = next.indexWhere((c) => c.email.toLowerCase() == incomingEmail);
      if (index == -1) {
        next = [
          ...next,
          Contact(
            email: incomingEmail,
            displayName: (event.body == null || event.body!.trim().isEmpty)
                ? incomingEmail.split('@').first
                : event.body!.trim(),
            status: event.presence ?? PresenceStatus.online,
          ),
        ];
      } else {
        final current = next[index];
        final updated = current.copyWith(
          displayName: (event.body == null || event.body!.trim().isEmpty)
              ? current.displayName
              : event.body!.trim(),
          status: event.presence ?? current.status,
        );
        final mutable = [...next];
        mutable[index] = updated;
        next = mutable;
      }
      next.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    }

    if (next.isEmpty && state.isEmpty) {
      return;
    }

    if (event.type == MsnpEventType.presence && event.from != null) {
      final normalized = event.from!.trim().toLowerCase();
      final previousStatus = currentByEmail[normalized];
      Contact? current;
      for (final contact in next) {
        if (contact.email.toLowerCase() == normalized) {
          current = contact;
          break;
        }
      }
      if (current != null) {
        final isNowOnline = current.status != PresenceStatus.appearOffline;
        final wasOffline = previousStatus == null || previousStatus == PresenceStatus.appearOffline;
        if (isNowOnline && wasOffline) {
          await _soundService.playOnline();
        }
      }
    }

    state = next;
  }

  List<Contact> _snapshotToContacts(List<MsnpContactSnapshot> snapshot) {
    return snapshot
        .map(
          (c) => Contact(
            email: c.email,
            displayName: c.displayName,
            status: c.status,
            personalMessage: c.personalMessage,
            nowPlaying: c.nowPlaying,
            avatarMsnObject: c.avatarMsnObject,
            avatarCreator: c.avatarCreator,
            avatarSha1d: c.avatarSha1d,
            avatarLocalPath: _avatarPathByEmail[c.email.toLowerCase()],
            scene: c.scene,
            colorScheme: c.colorScheme,
            unreadCount: _unreadCountByEmail[c.email.toLowerCase()] ?? 0,
          ),
        )
        .toList(growable: false)
      ..sort(
        (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
  }

  void incrementUnreadForEmail(String email) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    final current = _unreadCountByEmail[normalized] ?? 0;
    _unreadCountByEmail[normalized] = current + 1;
    if (_client != null) {
      state = _snapshotToContacts(_client!.contactSnapshot);
    }
  }

  void resetUnreadForEmail(String email) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    _unreadCountByEmail[normalized] = 0;
    if (_client != null) {
      state = _snapshotToContacts(_client!.contactSnapshot);
    }
  }

  void setOffline(String email) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }

    final index = state.indexWhere((c) => c.email.toLowerCase() == normalized);
    if (index == -1) {
      // Contact not in current state list yet — rebuild from the authoritative
      // snapshot (which msnp_client already marked as appearOffline via
      // _rememberFromEvent before dispatching the FLN event).
      if (_client != null) {
        state = _snapshotToContacts(_client!.contactSnapshot);
      }
      return;
    }

    final mutable = state.toList(growable: true);
    mutable[index] = mutable[index].copyWith(status: PresenceStatus.appearOffline);
    state = mutable; // triggers Riverpod rebuild (equivalent to notifyListeners)
  }
}

final contactsProvider = NotifierProvider<ContactsNotifier, List<Contact>>(
  ContactsNotifier.new,
);
