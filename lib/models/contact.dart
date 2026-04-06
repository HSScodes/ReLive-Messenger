import '../utils/presence_status.dart';

class Contact {
  const Contact({
    required this.email,
    required this.displayName,
    required this.status,
    this.personalMessage,
    this.nowPlaying,
    this.avatarMsnObject,
    this.avatarCreator,
    this.avatarSha1d,
    this.avatarLocalPath,
    this.scene,
    this.colorScheme,
    this.unreadCount = 0,
  });

  final String email;
  final String displayName;
  final PresenceStatus status;
  final String? personalMessage;
  final String? nowPlaying;
  final String? avatarMsnObject;
  final String? avatarCreator;
  final String? avatarSha1d;
  final String? avatarLocalPath;
  final String? scene;
  final String? colorScheme;
  final int unreadCount;

  Contact copyWith({
    String? email,
    String? displayName,
    PresenceStatus? status,
    String? personalMessage,
    String? nowPlaying,
    String? avatarMsnObject,
    String? avatarCreator,
    String? avatarSha1d,
    String? avatarLocalPath,
    String? scene,
    String? colorScheme,
    int? unreadCount,
  }) {
    return Contact(
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      status: status ?? this.status,
      personalMessage: personalMessage ?? this.personalMessage,
      nowPlaying: nowPlaying ?? this.nowPlaying,
      avatarMsnObject: avatarMsnObject ?? this.avatarMsnObject,
      avatarCreator: avatarCreator ?? this.avatarCreator,
      avatarSha1d: avatarSha1d ?? this.avatarSha1d,
      avatarLocalPath: avatarLocalPath ?? this.avatarLocalPath,
      scene: scene ?? this.scene,
      colorScheme: colorScheme ?? this.colorScheme,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
