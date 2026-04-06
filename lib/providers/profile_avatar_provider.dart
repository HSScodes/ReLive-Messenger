import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/msn_object_service.dart';
import 'connection_provider.dart';

class ProfileAvatarNotifier extends Notifier<String?> {
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

    unawaited(_refreshAvatar());
    return null;
  }

  Future<void> _refreshAvatar() async {
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
  }
}

final profileAvatarProvider = NotifierProvider<ProfileAvatarNotifier, String?>(
  ProfileAvatarNotifier.new,
);
