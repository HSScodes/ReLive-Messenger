import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final Map<String, String> _ddpPathByEmail = <String, String>{};
  final Set<String> _avatarFetchFailedByEmail = <String>{};
  final Map<String, int> _unreadCountByEmail = <String, int>{};
  final SoundService _soundService = const SoundService();
  final AvatarCacheService _avatarCache = AvatarCacheService();
  final Map<String, String> _sha1dByEmail = <String, String>{};
  final Set<String> _directoryFetchInFlight = <String>{};

  // Favorites (persisted via SharedPreferences)
  final Set<String> _favoriteEmails = <String>{};
  static const _kFavorites = 'wlm_favorites';

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

  /// Loads persisted avatar paths, sha1d values, and favorites into runtime maps.
  Future<void> _initCache() async {
    await _avatarCache.init();

    // Load favorites
    final prefs = await SharedPreferences.getInstance();
    final favList = prefs.getStringList(_kFavorites) ?? [];
    _favoriteEmails.addAll(favList);

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
        // Mark the fetch as failed but do NOT remove the cached avatar path.
        // The contact should keep showing their last-known avatar rather than
        // snapping to the default user tile on every P2P timeout.
        _avatarFetchFailedByEmail.add(failedEmail);
      }
      return;
    }

    if (event.type == MsnpEventType.system && event.command == 'AVOK') {
      final email = (event.from ?? '').trim().toLowerCase();
      final bodyParts = (event.body ?? '').split('\n');
      final filePath = bodyParts.first.trim();
      final fetchedSha1d = bodyParts.length > 1 ? bodyParts[1].trim() : '';
      if (email.isNotEmpty && filePath.isNotEmpty) {
        // Determine if this AVOK is for a DDP or static avatar by matching
        // the fetched sha1d against the contact's ddpSha1d.
        final snap = _client!.contactSnapshot
            .where((c) => c.email.toLowerCase() == email)
            .firstOrNull;
        final isDdp = fetchedSha1d.isNotEmpty &&
            snap?.ddpSha1d != null &&
            snap!.ddpSha1d == fetchedSha1d;

        if (isDdp) {
          _ddpPathByEmail[email] = filePath;
        } else {
          _avatarPathByEmail[email] = filePath;
        }
        _avatarFetchFailedByEmail.remove(email);
        // Persist to disk so the avatar survives app restart.
        final sha1d = snap?.avatarSha1d;
        unawaited(_avatarCache.save(email, filePath, sha1d: sha1d));
        if (sha1d != null && sha1d.isNotEmpty) {
          _sha1dByEmail[email] = sha1d;
        }
        state = _snapshotToContacts(_client!.contactSnapshot);
      }
      return;
    }

    // Only rebuild the contact list for events that actually change contact
    // data. Message, typing and nudge events do NOT affect contacts and
    // rebuilding on them causes excessive UI flicker / avatar twitching.
    final shouldRefresh =
        event.type == MsnpEventType.presence ||
        event.type == MsnpEventType.contact ||
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
                ? incomingEmail
                : event.body!.trim(),
            status: event.presence ?? PresenceStatus.online,
            avatarLocalPath: _avatarPathByEmail[incomingEmail],
            avatarSha1d: _sha1dByEmail[incomingEmail],
          ),
        ];
      } else {
        final current = next[index];
        // Only update displayName and status from presence events.
        // Avatar fields must only change through _checkSha1dChanges / AVOK
        // to avoid clearing cached avatars when NLN arrives without MSNObject.
        final updated = current.copyWith(
          displayName: (event.body == null || event.body!.trim().isEmpty)
              ? current.displayName
              : event.body!.trim(),
          status: event.presence ?? current.status,
          avatarLocalPath: current.avatarLocalPath ?? _avatarPathByEmail[current.email.toLowerCase()],
          avatarSha1d: current.avatarSha1d ?? _sha1dByEmail[current.email.toLowerCase()],
        );
        final mutable = [...next];
        mutable[index] = updated;
        next = mutable;
      }
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

    // Track sha1d values from the snapshot so we know who has updated their
    // display picture, but do NOT auto-fetch avatars here.  Avatars are only
    // refreshed when the user opens a chat window (see refreshAvatarFor).
    _recordSha1dChanges(next);
  }

  /// Records sha1d values from the latest contact list.  If a contact already
  /// has a cached avatar path we keep showing it (even if the sha1d changed)
  /// until an explicit refresh or a P2P AVOK replaces it.
  void _recordSha1dChanges(List<Contact> contacts) {
    for (final contact in contacts) {
      final sha1d = contact.avatarSha1d;
      if (sha1d == null || sha1d.isEmpty) continue;
      final email = contact.email.toLowerCase();
      _sha1dByEmail[email] = sha1d;

      // If we have no cached path at all for this contact yet, try the
      // persistent cache synchronously (zero-cost — already loaded in RAM).
      if (!_avatarPathByEmail.containsKey(email)) {
        final cached = _avatarCache.getSync(email);
        if (cached != null) {
          _avatarPathByEmail[email] = cached;
        }
      }
    }
  }

  /// Public API: refresh the avatar for [email].  Call this when the user
  /// opens a chat window so we get the freshest display picture.
  Future<void> refreshAvatarFor(String email) async {
    final key = email.trim().toLowerCase();
    if (key.isEmpty) return;
    final sha1d = _sha1dByEmail[key];
    if (sha1d == null || sha1d.isEmpty) return;
    if (_directoryFetchInFlight.contains(key)) return;
    await _resolveAvatar(key, sha1d);
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
      final path = await _avatarCache.fetchFromCrosstalkDirectory(email,
          sha1d: sha1d);
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

  // ── Favorites ─────────────────────────────────────────────────────────

  bool isFavorite(String email) =>
      _favoriteEmails.contains(email.trim().toLowerCase());

  Set<String> get favoriteEmails => Set.unmodifiable(_favoriteEmails);

  Future<void> toggleFavorite(String email) async {
    final key = email.trim().toLowerCase();
    if (_favoriteEmails.contains(key)) {
      _favoriteEmails.remove(key);
    } else {
      _favoriteEmails.add(key);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kFavorites, _favoriteEmails.toList());
    if (_client != null) {
      state = _snapshotToContacts(_client!.contactSnapshot);
    }
  }

  List<Contact> _snapshotToContacts(List<MsnpContactSnapshot> snapshot) {
    return snapshot
        .map(
          (c) {
            final email = c.email.toLowerCase();
            return Contact(
              email: c.email,
              displayName: c.displayName,
              status: c.status,
              personalMessage: c.personalMessage,
              nowPlaying: c.nowPlaying,
              avatarMsnObject: c.avatarMsnObject,
              avatarCreator: c.avatarCreator,
              avatarSha1d: c.avatarSha1d,
              avatarLocalPath: _ddpPathByEmail[email] ?? _avatarPathByEmail[email],
              ddpMsnObject: c.ddpMsnObject,
              ddpSha1d: c.ddpSha1d,
              ddpLocalPath: _ddpPathByEmail[email],
              scene: c.scene,
              colorScheme: c.colorScheme,
              unreadCount: _unreadCountByEmail[email] ?? 0,
            );
          },
        )
        .toList(growable: false);
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
