import '../utils/presence_status.dart';

class Presence {
  const Presence({
    required this.email,
    required this.displayName,
    required this.status,
    this.personalMessage,
    this.nowPlaying,
  });

  final String email;
  final String displayName;
  final PresenceStatus status;
  final String? personalMessage;
  final String? nowPlaying;
}
