import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/msn_object_service.dart';
import 'connection_provider.dart';

class ProfileAvatarNotifier extends Notifier<String?> {
  static const _kSelfAvatarPathPrefix = 'wlm_self_avatar_path_';

  StreamSubscription? _subscription;
  final MsnObjectService _msnObjectService = MsnObjectService();

  @override
  String? build() {
    final client = ref.watch(msnpClientProvider);
    _subscription = client.events.listen((_) {
      unawaited(_refreshAvatar());
    });

    ref.onDispose(() {
      _subscription?.cancel();
    });

    unawaited(_loadPersistedAvatarPath());
    unawaited(_refreshAvatar());
    return null;
  }

  Future<void> _loadPersistedAvatarPath() async {
    final client = ref.read(msnpClientProvider);
    final email = client.selfEmail.trim().toLowerCase();
    if (email.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('$_kSelfAvatarPathPrefix$email');
    if (path == null || path.isEmpty) {
      return;
    }

    final file = File(path);
    if (!file.existsSync()) {
      await prefs.remove('$_kSelfAvatarPathPrefix$email');
      return;
    }

    if (state != path) {
      state = path;
      // Regenerate MSNObject from persisted avatar so it's broadcast on connect.
      final client = ref.read(msnpClientProvider);
      unawaited(client.updateSelfAvatarMsnObject(path));
    }
  }

  Future<void> _persistAvatarPath(String path) async {
    final client = ref.read(msnpClientProvider);
    final email = client.selfEmail.trim().toLowerCase();
    if (email.isEmpty || path.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kSelfAvatarPathPrefix$email', path);
  }

  Future<void> _refreshAvatar() async {
    // If we already have a valid local avatar file, skip the HTTP fetch.
    // The self-avatar is always set locally (via setPath or persisted path)
    // and does not exist on remote avatar CDNs.
    final current = state;
    if (current != null && current.isNotEmpty && File(current).existsSync()) {
      return;
    }

    final client = ref.read(msnpClientProvider);
    final msnObject = client.selfAvatarMsnObject;
    if (msnObject == null || msnObject.isEmpty) {
      return;
    }

    final path = await _msnObjectService.fetchAndCacheAvatar(
      host: client.sessionHost,
      authTicket: client.avatarAuthToken,
      avatarMsnObject: msnObject,
    );
    if (path == null || path.isEmpty) {
      return;
    }

    if (state == path) {
      return;
    }

    final file = File(path);
    if (!file.existsSync()) {
      return;
    }

    state = path;
    unawaited(_persistAvatarPath(path));
  }

  Future<void> setPath(String path) async {
    if (path.isEmpty) {
      return;
    }
    // Evict cached image so Flutter re-reads the updated file on disk.
    imageCache.evict(FileImage(File(path)));
    // Force Riverpod to notify even when the path string hasn't changed.
    if (state == path) {
      state = null;
    }
    state = path;
    // Persist BEFORE broadcasting so the avatar file is findable when
    // the contact requests it via P2P after seeing the new MSNObject.
    await _persistAvatarPath(path);
    // Generate and broadcast MSNObject so contacts can see our avatar.
    final client = ref.read(msnpClientProvider);
    unawaited(client.updateSelfAvatarMsnObject(path));
  }
}

final profileAvatarProvider = NotifierProvider<ProfileAvatarNotifier, String?>(
  ProfileAvatarNotifier.new,
);
