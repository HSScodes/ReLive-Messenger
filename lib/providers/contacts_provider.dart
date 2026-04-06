import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/contact.dart';
import '../network/msnp_client.dart';
import '../network/msnp_parser.dart';
import '../services/avatar_cache_service.dart';
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
  final AvatarCacheService _avatarCache = AvatarCacheService();
  // Tracks the last sha1d we acted on per-email to avoid redundant fetches.
  final Map<String, String> _sha1dByEmail = <String, String>{};
  // Prevents concurrent in-flight directory fetches for the same email.
  final Set<String> _directoryFetchInFlight = <String>{};

  @override
  List<Contact> build() {
    final client = ref.watch(msnpClientProvider);
    _client = client;
    _subscription = client.events.listen(_onEvent);
    ref.onDispose(() {
      _subscription?.cancel();
    });

    // Load persisted avatar cache asynchronously so contacts show stored
    // avatars immediately on next state rebuild without waiting for P2P.
    _initCache();

    return _snapshotToContacts(client.contactSnapshot);
  }

  /// Loads persisted avatar paths and sha1d values into the runtime maps.
  Future<void> _initCache() async {
    await _avatarCache.init();
    var changed = false;
    for (final entry in _avatarCache.entries.entries) {
      if (!_avatarPathByEmail.containsKey(entry.key)) {
        _avatarPathByEmail[entry.key] = entry.value;
        changed = true;
      }
      final sha1d = _avatarCache.getStoredSha1d(entry.key);
      if (sha1d != null && sha1d.isNotEmpty) {
        _sha1dByEmail[entry.key] = sha1d;
      }
    }
    if (changed && _client != null) {
      state = _snapshotToContacts(_client!.contactSnapshot);
    }
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
        // Persist to disk so the avatar survives app restart.
        final sha1d = _client!.contactSnapshot
            .where((c) => c.email.toLowerCase() == email)
            .firstOrNull
            ?.avatarSha1d;
        unawaited(_avatarCache.save(email, filePath, sha1d: sha1d));
        if (sha1d != null && sha1d.isNotEmpty) {
          _sha1dByEmail[email] = sha1d;
        }
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

    // For each contact that now has a sha1d we haven't seen before (or that
    // has changed), attempt to resolve the avatar from persistent cache first,
    // then from the CrossTalk directory, before the slower P2P transfer arrives.
    _checkSha1dChanges(next);
  }

  void _checkSha1dChanges(List<Contact> contacts) {
    for (final contact in contacts) {
      final sha1d = contact.avatarSha1d;
      if (sha1d == null || sha1d.isEmpty) continue;
      final email = contact.email.toLowerCase();
      if (_sha1dByEmail[email] == sha1d) continue; // already handled this sha1d
      _sha1dByEmail[email] = sha1d;
      if (!_directoryFetchInFlight.contains(email)) {
        unawaited(_resolveAvatar(email, sha1d));
      }
    }
  }

  /// Tries to resolve a display picture for [email] with [sha1d]:
  ///   1. Persistent cache (instant, zero network)
  ///   2. CrossTalk directory (fast HTTP GET)
  /// If resolved, updates state immediately. The background P2P fetch may
  /// still complete later and will overwrite with the same (or fresher) value.
  Future<void> _resolveAvatar(String email, String sha1d) async {
    _directoryFetchInFlight.add(email);
    try {
      // 1. Check persistent cache with sha1d match.
      final cached = await _avatarCache.get(email, currentSha1d: sha1d);
      if (cached != null) {
        _avatarPathByEmail[email] = cached;
        _avatarFetchFailedByEmail.remove(email);
        if (_client != null) {
          state = _snapshotToContacts(_client!.contactSnapshot);
        }
        return;
      }

      // 2. Try CrossTalk directory as a fast-path before P2P completes.
      if (_avatarFetchFailedByEmail.contains(email)) return;
      final path = await _avatarCache.fetchFromCrosstalkDirectory(email);
      if (path != null) {
        await _avatarCache.save(email, path, sha1d: sha1d);
        _avatarPathByEmail[email] = path;
        _avatarFetchFailedByEmail.remove(email);
        if (_client != null) {
          state = _snapshotToContacts(_client!.contactSnapshot);
        }
      }
    } finally {
      _directoryFetchInFlight.remove(email);
    }
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
