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
    this.ddpMsnObject,
    this.ddpSha1d,
    this.ddpLocalPath,
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
  final String? ddpMsnObject;
  final String? ddpSha1d;
  final String? ddpLocalPath;
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
    String? ddpMsnObject,
    String? ddpSha1d,
    String? ddpLocalPath,
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
      ddpMsnObject: ddpMsnObject ?? this.ddpMsnObject,
      ddpSha1d: ddpSha1d ?? this.ddpSha1d,
      ddpLocalPath: ddpLocalPath ?? this.ddpLocalPath,
      scene: scene ?? this.scene,
      colorScheme: colorScheme ?? this.colorScheme,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
