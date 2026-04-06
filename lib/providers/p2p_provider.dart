import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/p2p_session_manager.dart';
import 'connection_provider.dart';

/// Emits the latest snapshot of all active P2P transfer statuses whenever
/// any peer's status changes.  Map key = lower-cased peer email.
final p2pStatusProvider = StreamProvider<Map<String, P2pStatus>>((ref) {
  return ref.watch(msnpClientProvider).p2pSessionManager.statusStream;
});
