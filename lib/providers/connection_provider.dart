import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/msnp_client.dart';

final msnpClientProvider = Provider<MsnpClient>((ref) {
  final client = MsnpClient();
  ref.onDispose(client.dispose);
  return client;
});

final connectionProvider = StreamProvider<ConnectionStatus>((ref) {
  return ref.watch(msnpClientProvider).status;
});
